import json
from typing import Dict
from orchestrator.rag.vectore_store import AdvancedKnowledgeStore
from orchestrator.rag.retriever import AblationRetriever

class RagEngine:
    def __init__(self, knowledge_path: str = "Knowledge"):
        # Initialize your advanced dissertation RAG components
        self.store = AdvancedKnowledgeStore(base_path=knowledge_path)
        self.store.load_and_index_all()
        self.retriever = AblationRetriever(self.store)

    def build_context(self, user_request: str, canonical_json: Dict, strategy: str = "hybrid") -> Dict:
        # Route query through your ablation matrix
        retrieved = self.retriever.retrieve(user_request, strategy=strategy)

        return {
            "canonical_json": canonical_json,
            "logic_guides": [x["content"] for x in retrieved["logic_guides"]],
            "script_guides": [x["content"] for x in retrieved["script_guides"]],
            "templates": [x["content"] for x in retrieved["templates"]],
            "kt_docs": [x["content"] for x in retrieved["kt_docs"]],
        }

    def build_prompt_context(self, user_request: str, canonical_json: Dict, strategy: str = "hybrid") -> str:
        context = self.build_context(user_request, canonical_json, strategy=strategy)

        return f"""USER REQUEST:
{user_request}

CANONICAL JSON:
{json.dumps(context["canonical_json"], indent=2)}

LOGIC GUIDES:
{'-' * 60}
{"".join(context["logic_guides"])}

SCRIPT GUIDES:
{'-' * 60}
{"".join(context["script_guides"])}

SQL TEMPLATES:
{'-' * 60}
{"".join(context["templates"])}

KT DOCS (RAPTOR/Aggregated Context):
{'-' * 60}
{"".join(context["kt_docs"])}"""