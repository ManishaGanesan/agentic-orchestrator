"""
orchestrator/rag/rag_engine.py
"""
import json
from pathlib import Path
from typing import Dict
from orchestrator.rag.vectore_store import AdvancedKnowledgeStore
from orchestrator.rag.retriever import AblationRetriever

class RagEngine:
    def __init__(self, knowledge_path: str = None):
        resolved_path = self._resolve_knowledge_path(knowledge_path)
        self.store = AdvancedKnowledgeStore(base_path=resolved_path)
        self.store.load_and_index_all()
        self.retriever = AblationRetriever(self.store)

    @staticmethod
    def _resolve_knowledge_path(knowledge_path: str = None) -> str:
        if knowledge_path:
            candidate = Path(knowledge_path)
            if candidate.exists():
                return str(candidate)

        repo_root = Path(__file__).resolve().parents[2]
        fallback = repo_root / "orchestrator" / "knowledge"
        if fallback.exists():
            return str(fallback)

        return str(repo_root / "Knowledge")

    def build_context(self, user_request: str, canonical_json: Dict, strategy: str = "hybrid") -> Dict:
        # Route query through your ablation matrix
        # Hard restriction: lower top_n from 2 to 1 inside your retrieval process
        retrieved = self.retriever.retrieve(user_request, strategy=strategy, top_n=1)

        # ---------------------------------------------------------------------
        # CRITICAL HARD CEILING: Aggressive character truncation per block
        # ---------------------------------------------------------------------
        return {
            "canonical_json": canonical_json,
            # Slice character limits cleanly so total text string cannot cause attention footprint blowouts
            "logic_guides": [x["content"][:400] for x in retrieved.get("logic_guides", [])],
            "script_guides": [x["content"][:400] for x in retrieved.get("script_guides", [])],
            "templates": [x["content"][:600] for x in retrieved.get("templates", [])],
            "kt_docs": [x["content"][:400] for x in retrieved.get("kt_docs", [])],
        }

    def build_prompt_context(self, user_request: str, canonical_json: Dict, strategy: str = "hybrid") -> str:
        context = self.build_context(user_request, canonical_json, strategy=strategy)

        # Build a highly compact context template matching your local SLM context parameters
        return f"""USER REQUEST: {user_request}
CANONICAL JSON:
{json.dumps(context["canonical_json"])[:4000]}
LOGIC GUIDE EXCERPT:
{"".join(context["logic_guides"])}
SCRIPT GUIDE EXCERPT:
{"".join(context["script_guides"])}
TEMPLATE BASE EXCERPT:
{"".join(context["templates"])}
KT DOCS EXCERPT:
{"".join(context["kt_docs"])}"""