"""
orchestrator/rag/rag_engine.py
"""
import json
from pathlib import Path
from typing import Dict

# Import your advanced vector store and strategy-based retriever modules
from orchestrator.rag.vectore_store import AdvancedKnowledgeStore
from orchestrator.rag.retriever import AblationRetriever

class RagEngine:
    def __init__(self, knowledge_path: str = None):
        self.knowledge_dir = Path(knowledge_path) if knowledge_path else Path(__file__).resolve().parents[2] / "Knowledge"
        
        project_root = Path(__file__).resolve().parents[2]
        self.registry_dir = project_root / "output_jsons"

        # 1. Initialize your true vector database store
        self.store = AdvancedKnowledgeStore(base_path=str(self.knowledge_dir))
        # 2. Trigger your file-reading, chunking, embedding, and RAPTOR tree generation processes
        # This scans the Knowledge folder, tokenizes documents, and loads the model
        self.store.load_and_index_all()
        # 4. Inject and vectorize your canonical_json history files into the dense matrix
        self._index_external_canonical_json()
        # 3. Instantiate the ablation-driven strategy retriever
        self.retriever = AblationRetriever(store=self.store)
        
    def _index_external_canonical_json(self):
        """
        Safely targets, chunks, and forces vector embedding generation 
        for your historical JSON registry.
        """
        import json
        from rank_bm25 import BM25Okapi # Ensure this matches your project's BM25 import
        
        section = "canonical_json"
        
        if self.registry_dir.exists() and self.registry_dir.is_dir():
            print(f"--- Indexing External Registry Root from: {self.registry_dir} ---")
            self.store.raw_documents[section] = []
            self.store.chunks[section] = []

            for file_path in self.registry_dir.glob("*.json"):
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    
                    self.store.raw_documents[section].append({
                        "file_name": file_path.name,
                        "content": json.dumps(data)
                    })
                    
                    if isinstance(data, list):
                        for idx, record in enumerate(data):
                            self.store.chunks[section].append({
                                "file_name": file_path.name,
                                "chunk_id": f"{file_path.name}_rec_{idx}",
                                "content": json.dumps(record)
                            })
                    else:
                        self.store.chunks[section].append({
                            "file_name": file_path.name,
                            "chunk_id": f"{file_path.name}_root",
                            "content": json.dumps(data)
                        })
                except Exception as e:
                    print(f"Failed processing historical snapshot {file_path.name}: {e}")

            # Force inject vectors directly into the store instance properties
            if self.store.chunks[section]:
                chunk_contents = [c["content"] for c in self.store.chunks[section]]
                
                print(f"Generating dense vector embeddings for external '{section}'...")
                self.store.dense_embeddings[section] = self.store.encoder.encode(chunk_contents, convert_to_numpy=True)
                
                print(f"Building BM25 sparse index for external '{section}'...")
                tokenized_corpus = [text.lower().split(" ") for text in chunk_contents]
                self.store.bm25_indices[section] = BM25Okapi(tokenized_corpus)
        else:
            print(f"Warning: Historical repository path not found at: {self.registry_dir.resolve()}")


    def build_prompt_context(self, query: str, active_run_json: Dict, strategy: str = "hybrid") -> str:
        """
        Queries the vector store cleanly while keeping the prompt slim and targeted.
        """
        # 1. Strip the massive loop payload from the active target for prompt visualization
        minimized_active_run = {
            "previous_version": active_run_json.get("previous_version"),
            "new_version": active_run_json.get("new_version"),
            "story_id": active_run_json.get("story_id"),
            "request": active_run_json.get("request"),
            "target_modifications": []
        }
        
        state_procedures = active_run_json.get("state_procedures", [])
        primary_pricer = "UNKNOWN"
        primary_action = "UNKNOWN"
        
        for block in state_procedures:
            primary_pricer = block.get("state_name", "UNKNOWN")
            primary_action = block.get("action", "UNKNOWN")
            minimized_active_run["target_modifications"].append({
                "state_name": primary_pricer,
                "state_id": block.get("state_id"),
                "effective_date": block.get("effective_date"),
                "action": primary_action,
                "procedure_count": len(block.get("procedures", [])),
                "procedure_sample_range": [p.get("pcode") for p in block.get("procedures", [])[:2]] # Just show a sample of 2 items
            })

        # 2. Execute Strategy Search (Ensure query strings match index terminology cleanly)
        clean_search_query = f"{primary_pricer} {primary_action}"
        retrieved_chunks = self.retriever.retrieve(query_text=clean_search_query, strategy=strategy, top_n=3)
        
        logic_context = "\n".join([chunk["content"] for chunk in retrieved_chunks.get("logic_guides", [])])
        script_context = "\n".join([chunk["content"] for chunk in retrieved_chunks.get("script_guides", [])])

        # 3. Pull historical record securely
        history_chunks = retrieved_chunks.get("canonical_json", [])
        formatted_historical_blueprint = "No matching historical blueprints discovered."

        if history_chunks:
            best_match_content = history_chunks[0]["content"]
            try:
                historical_data = json.loads(best_match_content) if isinstance(best_match_content, str) else best_match_content
                
                # Dig inside state_procedures array since the root keys don't exist flat
                procedures_list = historical_data.get("state_procedures", [])
                first_proc = procedures_list[0] if procedures_list else {}
                
                # Safe extraction from the nested list block
                state_name = first_proc.get("state_name") or historical_data.get("state_name", "UNKNOWN")
                state_id = first_proc.get("state_id") or historical_data.get("state_id", "UNKNOWN")
                eff_date = first_proc.get("effective_date") or historical_data.get("effective_date", "UNKNOWN")
                action = first_proc.get("action") or historical_data.get("action", "UNKNOWN")
                
                sql_meta = historical_data.get("sql_script", {})
                script_file = sql_meta.get("file_name") or first_proc.get("source_file", "Migration.sql")
                script_content = sql_meta.get("content") or historical_data.get("generated_sql") or "-- SQL script content unavailable"

                formatted_historical_blueprint = (
                    f'{{\n'
                    f'  "state_name": "{state_name}",\n'
                    f'  "state_id": "{state_id}",\n'
                    f'  "effective_date": "{eff_date}",\n'
                    f'  "action": "{action}",\n'
                    f'  "sql_script": {{\n'
                    f'    "file_name": "{script_file}",\n'
                    f'    "content": "{script_content[:300]}... [Truncated for Cleanliness]"\n'
                    f'  }}\n'
                    f'}}'
                )
            except Exception as e:
                formatted_historical_blueprint = f"Parsing fallback: {str(best_match_content)[:400]}"


        # 4. Construct high-density context envelope
        prompt_str = f"=== SYSTEM REPOSITORY KNOWLEDGE (Strategy: {strategy.upper()}) ===\n"
        if logic_context:
            prompt_str += f"[BUSINESS RULES]\n{logic_context}\n\n"
        if script_context:
            prompt_str += f"[SCRIPT CONSTRAINTS]\n{script_context}\n\n"
            
        prompt_str += "=== MOST SIMILAR HISTORICAL MATCH (VALIDATED REFERENCE) ===\n"
        prompt_str += f"{formatted_historical_blueprint}\n"
        prompt_str += "===========================================================\n\n"

        prompt_str += "=== ACTIVE TARGET SCOPE FOR CURRENT MIGRATION RUN ===\n"
        prompt_str += f"{json.dumps(minimized_active_run, indent=2)}\n"
        
        return prompt_str
    
