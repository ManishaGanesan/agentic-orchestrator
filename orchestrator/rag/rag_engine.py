import json
from typing import Dict
from orchestrator.rag.retriever import Retriever


class RagEngine:
    def __init__(self, knowledge_path: str = "Knowledge"):
        self.retriever = Retriever(knowledge_path)

    def build_context(self, user_request: str, canonical_json: Dict) -> Dict:
        retrieved = self.retriever.retrieve(user_request, canonical_json)

        return {
            "canonical_json": canonical_json,
            "logic_guides": [x["content"] for x in retrieved["logic_guides"]],
            "script_guides": [x["content"] for x in retrieved["script_guides"]],
            "templates": [x["content"] for x in retrieved["templates"]],
            "kt_docs": [x["content"] for x in retrieved["kt_docs"]],
        }

    def build_prompt_context(self, user_request: str, canonical_json: Dict) -> str:
        context = self.build_context(user_request, canonical_json)

        return f"""
USER REQUEST:
{user_request}

CANONICAL JSON:
{json.dumps(context["canonical_json"], indent=2)}

LOGIC GUIDES:
{'-' * 60}
{chr(10).join(context["logic_guides"])}

SCRIPT GUIDES:
{'-' * 60}
{chr(10).join(context["script_guides"])}

SQL TEMPLATES:
{'-' * 60}
{chr(10).join(context["templates"])}

KT DOCS:
{'-' * 60}
{chr(10).join(context["kt_docs"])}
"""