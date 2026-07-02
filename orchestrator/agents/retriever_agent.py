from typing import Dict
from orchestrator.rag.rag_engine import RagEngine


class RetrieverAgent:
    def __init__(self, knowledge_path: str = None):
        self.rag = RagEngine(knowledge_path)

    def get_context(self, task: Dict, strategy: str = "hybrid") -> Dict:
        user_request = task["user_request"]
        canonical_json = task["canonical_json"]
        metadata = task.get("metadata", {}) 

        # 2. Enrich the search query sent to the RAG engine
        # By combining the text intent with explicit state and table metrics,
        # BM25/Dense retrievers don't have to guess the target scope.
        state_id = metadata.get("live_state_id", "")
        pricer_name = metadata.get("pricer_descr", "")
        search_query = f"{user_request} Target State: {state_id} Table: {pricer_name}".strip()

        # 3. Route down to the RAG Engine with the enriched search query
        prompt_context = self.rag.build_prompt_context(
            query=search_query, 
            active_run_json=canonical_json, 
            strategy=strategy
        )

        # 4. Return everything back to runner.py, maintaining pipeline consistency
        return {
            "user_request": user_request,
            "canonical_json": canonical_json,
            "metadata": metadata,
            "prompt_context": prompt_context
        }