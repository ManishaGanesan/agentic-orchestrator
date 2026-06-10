from typing import Dict
from orchestrator.rag.rag_engine import RagEngine


class RetrieverAgent:
    def __init__(self, knowledge_path: str = "Knowledge"):
        self.rag = RagEngine(knowledge_path)

    def get_context(self, task: Dict) -> Dict:
        user_request = task["user_request"]
        canonical_json = task["canonical_json"]

        prompt_context = self.rag.build_prompt_context(user_request, canonical_json)

        return {
            "user_request": user_request,
            "canonical_json": canonical_json,
            "prompt_context": prompt_context
        }
