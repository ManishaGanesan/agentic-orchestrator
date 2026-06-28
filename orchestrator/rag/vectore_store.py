import os
import json
import numpy as np
from typing import Dict, List, Any
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer
from sklearn.cluster import KMeans

class AdvancedKnowledgeStore:
    def __init__(self, base_path: str = "Knowledge", model_name: str = "all-MiniLM-L6-v2"):
        self.base_path = base_path
        self.encoder = SentenceTransformer(model_name)
        self.raw_documents: Dict[str, List[Dict[str, Any]]] = {}
        
        # In-memory structures for retrieval metrics
        self.bm25_indices: Dict[str, BM25Okapi] = {}
        self.dense_embeddings: Dict[str, np.ndarray] = {}
        
        # RAPTOR Tree structure: dict mapping section -> list of aggregated cluster summary dicts
        self.raptor_trees: Dict[str, List[Dict[str, Any]]] = {}

    def load_and_index_all(self):
        sections = ["logic_guides", "script_guides", "templates", "kt_docs"]
        folder_mapping = {
            "logic_guides": "Logic_guide",
            "script_guides": "Script_guide",
            "templates": "Template",
            "kt_docs": "KT"
        }

        for section in sections:
            folder_path = os.path.join(self.base_path, folder_mapping[section])
            docs = []
            if os.path.exists(folder_path):
                for file_name in os.listdir(folder_path):
                    full_path = os.path.join(folder_path, file_name)
                    if os.path.isfile(full_path):
                        with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                            content = f.read()
                            docs.append({
                                "file_name": file_name,
                                "content": content,
                                "section": section
                            })
            self.raw_documents[section] = docs
            
            if docs:
                # 1. Build Sparse BM25
                tokenized_corpus = [doc["content"].lower().split(" ") for doc in docs]
                self.bm25_indices[section] = BM25Okapi(tokenized_corpus)
                
                # 2. Build Dense Embeddings
                corpus_texts = [doc["content"] for doc in docs]
                self.dense_embeddings[section] = self.encoder.encode(corpus_texts, convert_to_numpy=True)
                
                # 3. Build RAPTOR Tree Layer (Recursive Summarization Layer for Knowledge Transfer Docs)
                if section == "kt_docs" and len(docs) > 2:
                    self._build_raptor_layer(section, docs)

    def _build_raptor_layer(self, section: str, docs: List[Dict]):
        """
        Implements a structural layout of the RAPTOR algorithm:
        Clusters leaf texts, prepares them for summary generation.
        """
        embeddings = self.dense_embeddings[section]
        num_clusters = min(3, len(docs))
        kmeans = KMeans(n_clusters=num_clusters, random_state=42, n_init=10)
        cluster_labels = kmeans.fit_predict(embeddings)
        
        summaries = []
        for i in range(num_clusters):
            cluster_docs = [docs[idx]["content"] for idx, label in enumerate(cluster_labels) if label == i]
            # In your pipeline, pipe cluster_docs to local SLM to get a cohesive summary.
            # Mocking summarization here for structure framework.
            synthetic_summary = f"[RAPTOR Cluster {i} Summary of common policy structures]: " + " ".join([txt[:150] for txt in cluster_docs])
            summaries.append({
                "file_name": f"raptor_cluster_{i}.txt",
                "content": synthetic_summary,
                "section": section,
                "is_raptor_node": True
            })
        
        self.raptor_trees[section] = summaries