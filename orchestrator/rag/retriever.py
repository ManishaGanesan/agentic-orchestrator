from typing import Dict, List
from orchestrator.rag.vectore_store import SimpleKnowledgeStore


class Retriever:
    def __init__(self, knowledge_path: str = "Knowledge"):
        self.store = SimpleKnowledgeStore(knowledge_path)
        self.cache = self.store.load_all()

    def _keyword_match_score(self, text: str, keywords: List[str]) -> int:
        text_l = text.lower()
        score = 0
        for keyword in keywords:
            keyword = str(keyword).strip().lower()
            if keyword and keyword in text_l:
                score += 1
        return score

    def retrieve(self, user_request: str, canonical_json: Dict) -> Dict:
        keywords = []

        operation = canonical_json.get("operation", "")
        if operation:
            keywords.append(operation)

        table = canonical_json.get("table")
        if table:
            keywords.append(table)

        tables = canonical_json.get("tables", [])
        if isinstance(tables, str):
            tables = [tables]
        keywords.extend(tables)

        fields = canonical_json.get("fields", {})
        if isinstance(fields, dict):
            keywords.extend(list(fields.keys()))
            keywords.extend([str(v) for v in fields.values() if v is not None])

        # Handle nested state_procedures / procedure_variables
        for sp in canonical_json.get("state_procedures", []):
            if sp.get("action"):
                keywords.append(sp["action"])
            if sp.get("state_acronym"):
                keywords.append(sp["state_acronym"])
            if sp.get("state_name"):
                keywords.append(sp["state_name"])
            for proc in sp.get("procedures", []):
                if proc.get("pcode"):
                    keywords.append(proc["pcode"])

        for pv in canonical_json.get("procedure_variables", []):
            if pv.get("action"):
                keywords.append(pv["action"])
            pcode_info = pv.get("pcode", {})
            if isinstance(pcode_info, dict) and pcode_info.get("value"):
                keywords.append(pcode_info["value"])
            for var in pv.get("variables", []):
                if var.get("variable_name"):
                    keywords.append(var["variable_name"])

        keywords.extend(user_request.split())

        results = {
            "logic_guides": [],
            "script_guides": [],
            "templates": [],
            "kt_docs": []
        }

        for section in results.keys():
            scored = []
            for item in self.cache.get(section, []):
                score = self._keyword_match_score(item["content"], keywords)
                if score > 0:
                    scored.append((score, item))
            scored.sort(key=lambda x: x[0], reverse=True)
            results[section] = [item for _, item in scored[:3]]

        return results
