from typing import Dict
from orchestrator.rag.rag_engine import RagEngine


class RetrieverAgent:
    def __init__(self, knowledge_path: str = None):
        self.rag = RagEngine(knowledge_path)
# NEW METHOD: Allows re-indexing with the live SLM to build real RAPTOR tree layers
    def process_raptor_nodes(self, slm_agent):
        self.rag.store.load_and_index_all(slm_agent=slm_agent)

    def get_context(self, task: Dict, strategy: str = "hybrid") -> Dict:
        user_request = task["user_request"]
        canonical_json = task["canonical_json"]

        # Ensure strategy parameter routes down to the rag engine safely
        prompt_context = self.rag.build_prompt_context(user_request, canonical_json, strategy=strategy)

        return {
            "user_request": user_request,
            "canonical_json": canonical_json,
            "prompt_context": prompt_context
        }