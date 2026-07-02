import os
import json
from pathlib import Path
import numpy as np
from typing import Dict, List, Any
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer
from sklearn.cluster import KMeans

class AdvancedKnowledgeStore:
    def __init__(self, base_path: str = "Knowledge", model_name: str = "all-MiniLM-L6-v2",
                 chunk_size_tokens: int = 500, chunk_overlap_tokens: int = 75):
        self.base_path = base_path
        self.encoder = SentenceTransformer(model_name)
        self.raw_documents: Dict[str, List[Dict[str, Any]]] = {}

        # Chunked corpus actually used for indexing/retrieval (A1 ablation target)
        self.chunks: Dict[str, List[Dict[str, Any]]] = {}
        self.chunk_size_tokens = chunk_size_tokens
        self.chunk_overlap_tokens = chunk_overlap_tokens

        # In-memory structures for retrieval metrics (now built over chunks, not whole files)
        self.bm25_indices: Dict[str, BM25Okapi] = {}
        self.dense_embeddings: Dict[str, np.ndarray] = {}

        # RAPTOR Tree structure: dict mapping section -> list of aggregated cluster summary dicts
        self.raptor_trees: Dict[str, List[Dict[str, Any]]] = {}

    def _chunk_text(self, text: str, file_name: str, section: str) -> List[Dict[str, Any]]:
        """
        Splits a document into overlapping word-based chunks approximating
        chunk_size_tokens (whitespace tokens used as a cheap proxy for model
        tokens; good enough for chunk-boundary purposes since we still apply
        a hard tokenizer-based budget downstream in sql_agent.py).
        """
        words = text.split()
        if not words:
            return []

        step = max(1, self.chunk_size_tokens - self.chunk_overlap_tokens)
        chunks = []
        chunk_id = 0
        for start in range(0, len(words), step):
            window = words[start:start + self.chunk_size_tokens]
            if not window:
                continue
            chunk_text = " ".join(window)
            chunks.append({
                "file_name": file_name,
                "chunk_id": chunk_id,
                "content": chunk_text,
                "section": section,
                "source_file": file_name,        # explicit lineage back to parent doc
                "char_start": None,               # reserved for future precise offsets
            })
            chunk_id += 1
            if start + self.chunk_size_tokens >= len(words):
                break

        return chunks

    # UPDATE: Pass an optional slm_agent reference to generate real summaries
    def _collect_documents(self, section: str, base_path: Path) -> List[Dict[str, Any]]:
        docs: List[Dict[str, Any]] = []
        candidates = []

        if section == "logic_guides":
            candidates = [base_path / "Logic_guide", base_path / "logic_guides", base_path / "state_proc_rules.txt", base_path / "proc_variable_rules.txt"]
        elif section == "script_guides":
            candidates = [base_path / "Script_guide.txt", base_path / "Script_guide", base_path / "script_guides"]
        elif section == "templates":
            candidates = [base_path / "V191100-v191101_RateManager.sql", base_path / "Template", base_path / "templates"]
        elif section == "canonical_json" or section == "canonical_docs":
            # ◄--- FIX: Step back out to workspace root, then look inside output_jsons/
            root_dir = base_path.resolve().parent
            candidates = [
                root_dir / "output_jsons" / "canonical_output.json",
                root_dir / "output_jsons"
            ]

        for candidate in candidates:
            if not candidate.exists():
                continue
            if candidate.is_file():
                # Read the file as raw binary bytes first to scan for structural signatures
                with open(candidate, "rb") as raw_handle:
                    file_bytes = raw_handle.read()
                
                # Dynamic BOM & Encoding Signature Check
                if file_bytes.startswith(b'\xff\xfe') or file_bytes.startswith(b'\xfe\xff'):
                    encoding = "utf-16"
                else:
                    encoding = "utf-8"
                
                # Decode safely with standard fallback overrides
                try:
                    content = file_bytes.decode(encoding, errors="replace")
                except Exception:
                    content = file_bytes.decode("utf-8", errors="ignore")
                        
                docs.append({
                    "file_name": candidate.name,
                    "content": content,
                    "section": section,
                })
            elif candidate.is_dir():
                for file_path in sorted(candidate.iterdir()):
                    if file_path.is_file():
                        # Read the file as raw binary bytes first to scan for structural signatures
                        with open(file_path, "rb") as raw_handle:
                            file_bytes = raw_handle.read()
                        
                        # Dynamic BOM & Encoding Signature Check
                        if file_bytes.startswith(b'\xff\xfe') or file_bytes.startswith(b'\xfe\xff'):
                            encoding = "utf-16"
                        else:
                            encoding = "utf-8"
                        
                        # Decode safely with standard fallback overrides
                        try:
                            content = file_bytes.decode(encoding, errors="replace")
                        except Exception:
                            content = file_bytes.decode("utf-8", errors="ignore")
                        
                        docs.append({
                            "file_name": file_path.name,
                            "content": content,
                            "section": section,
                        })
        return docs

    def load_and_index_all(self, slm_agent=None):
        sections = ["logic_guides", "script_guides", "templates", "canonical_json"]
        base_path = Path(self.base_path)

        for section in sections:
            docs = self._collect_documents(section, base_path)
            self.raw_documents[section] = docs

            # Build the chunked corpus that retrieval actually runs over
            section_chunks: List[Dict[str, Any]] = []
            for doc in docs:
                section_chunks.extend(self._chunk_text(doc["content"], doc["file_name"], section))
            self.chunks[section] = section_chunks

            if section_chunks:
                tokenized_corpus = [c["content"].lower().split(" ") for c in section_chunks]
                self.bm25_indices[section] = BM25Okapi(tokenized_corpus)

                corpus_texts = [c["content"] for c in section_chunks]
                self.dense_embeddings[section] = self.encoder.encode(corpus_texts, convert_to_numpy=True)

                # RAPTOR still clusters at the chunk level (gives KMeans more,
                # more meaningful points than one vector per whole file)
                if section == "kt_docs" and len(section_chunks) > 2:
                    self._build_raptor_layer(section, section_chunks, slm_agent)

    def _build_raptor_layer(self, section: str, docs: List[Dict], slm_agent=None):
        """
        Implements true structural tree aggregation using the local SLM 
        to synthesize cluster documentation.
        """
        embeddings = self.dense_embeddings[section]
        num_clusters = min(3, len(docs))
        kmeans = KMeans(n_clusters=num_clusters, random_state=42, n_init=10)
        cluster_labels = kmeans.fit_predict(embeddings)
        
        summaries = []
        for i in range(num_clusters):
            cluster_docs = [docs[idx]["content"] for idx, label in enumerate(cluster_labels) if label == i]
            combined_nodes_text = "\n---\n".join(cluster_docs)
            
            if slm_agent and hasattr(slm_agent, 'generate_summary'):
                # Call the real local model pipeline for synthetic node summary
                synthetic_summary = slm_agent.generate_summary(combined_nodes_text)
            else:
                # Fallback safety
                synthetic_summary = f"[RAPTOR Fallback Cluster {i} Summary]: " + " ".join([txt[:100] for txt in cluster_docs])
                
            summaries.append({
                "file_name": f"raptor_cluster_{i}.txt",
                "content": synthetic_summary,
                "section": section,
                "is_raptor_node": True
            })
        
        self.raptor_trees[section] = summaries