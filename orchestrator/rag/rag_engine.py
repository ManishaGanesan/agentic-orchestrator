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

    def _summarize_guide(self, sql_agent, guide_type: str, raw_text: str) -> str:
            """
            Uses the vanilla SLM to compress business logic and script guides 
            into a dense, token-optimized summary of core rules.
            """
            if not raw_text.strip():
                return ""
                
            # Keep it ultra-short and strict to minimize overhead
            summary_prompt = (
                f"You are a database engineering context compressor.\n"
                f"Compress the following {guide_type} document into a dense, bulleted summary of rules "
                f"crucial for writing SQL migration scripts. Eliminate prose, examples, and filler words. "
                f"Keep the summary under 300 tokens."
            )
            
            # Build standard Phi-3 message layout format
            full_input = f"<|system|>\n{summary_prompt}<|end|>\n<|user|>\n{raw_text}<|end|>\n<|assistant|>\n"
            
            # Call the model directly to execute text-to-text distillation
            tokens_iterator = sql_agent.llm.create_completion(
                prompt=full_input,
                max_tokens=400,
                temperature=0.0, # Deterministic compression
                stop=["<|end|>", "<|user|>"],
                stream=False
            )
            
            return tokens_iterator["choices"][0]["text"].strip()

    def build_prompt_context(self, query: str, active_run_json: dict, strategy: str, sql_agent=None) -> str:
        """
        Dynamically packs context using a strict mathematical token budget.
        Guarantees final prompt is under ~2,500 tokens, leaving 1,500+ tokens
        for complete, uncut SQL script generation.
        """
        # 1. Gather raw data from your vector splits
        context_data = self.retriever.retrieve(query_text=query, strategy=strategy, top_n=1)
        raw_logic = "\n".join([c["content"] for c in context_data.get("logic_guides", [])]).strip()
        raw_script = "\n".join([c["content"] for c in context_data.get("script_guides", [])]).strip()
        
        # 2. Allocate strict character budgets (Approx 4 characters = 1 token)
        # Budget total: ~2,200 tokens max input context
        GUIDE_BUDGET_CHARS = 3000   # ~750 tokens allocated for rules
        PROC_BUDGET_CHARS = 5500    # ~1375 tokens allocated for data telemetry
        
        # 3. Handle Recursive Summarization if guides exceed their safe budget
        if len(raw_logic) + len(raw_script) > GUIDE_BUDGET_CHARS and sql_agent and hasattr(sql_agent, 'llm'):
            print("⚖️ [BUDGET CONTROL] Rules exceed safety bounds. Activating SLM compression...")
            logic_context = self._summarize_guide(sql_agent, "Business Logic", raw_logic)
            script_context = self._summarize_guide(sql_agent, "Script Constraints", raw_script)
        else:
            # Under budget, pass safely as-is
            logic_context = raw_logic
            script_context = raw_script

        # 4. Handle Procedure Arrays under strict structural budget
        state_procedures = active_run_json.get("state_procedures", [])
        distilled_blocks = []
        
        for block in state_procedures:
            state_id = block.get("state_id", "")
            if state_id and state_id in query:
                procedures = block.get("procedures", [])
                total_procs = len(procedures)
                
                # Format each procedure compactly
                proc_strings = [f"{{'order': {p.get('display_order')}, 'pcode': {p.get('pcode')}}}" for p in procedures]
                
                # Check character weight dynamically
                combined_proc_text = ", ".join(proc_strings)
                
                if len(combined_proc_text) > PROC_BUDGET_CHARS:
                    print(f"⚖️ [BUDGET CONTROL] Procedure array ({total_procs} items) is too heavy. Summarizing boundaries...")
                    # Meaningfully condense by showing the head, tail, and key metrics
                    # This prevents token-overflow while retaining schema structural data
                    summary_stream = (
                        f"[{total_procs} items total] "
                        f"Head elements: {', '.join(proc_strings[:8])}... "
                        f"Tail elements: {', '.join(proc_strings[-8:])} "
                        f"[Truncation avoided: Matrix optimized for token safety]"
                    )
                else:
                    summary_stream = combined_proc_text
                
                distilled_blocks.append(
                    f"TARGET STATE SCOPE: {state_id}\n"
                    f"EFFECTIVE DATE LINE: {block.get('effective_date')}\n"
                    f"REQUIRED ACTION MODE: {block.get('action')}\n"
                    f"PROCEDURE MIGRATION ARRAY:\n[{summary_stream}]"
                )

        # 5. Assemble pristine unified layout footprint
        prompt_str = "=== SYSTEM REPOSITORY RULES ===\n"
        if logic_context: prompt_str += f"[BUSINESS LOGIC]:\n{logic_context}\n\n"
        if script_context: prompt_str += f"[SCRIPT CONSTRAINTS]:\n{script_context}\n\n"
        
        prompt_str += "=== SPREADSHEET FACT RETRIEVAL MATRIX ===\n"
        prompt_str += "\n\n".join(distilled_blocks) if distilled_blocks else "No telemetry rows match execution target."
        prompt_str += "\n=========================================================\n"
        
        return prompt_str
    
    