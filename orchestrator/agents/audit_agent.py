from typing import Dict, Any
from datetime import datetime
import json


class AuditAgent:
    def build_audit_log(
        self,
        input_json: Dict[str, Any],
        retrieved_context: Dict[str, Any],
        db_context_queries,
        db_context_results,
        generated_sql: str,
        validation_result: Dict[str, Any]
    ) -> Dict[str, Any]:
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "input_json": input_json,
            "db_context_queries": db_context_queries,
            "db_context_results": db_context_results,
            "generated_sql": generated_sql,
            "validation_result": validation_result,
            "context_excerpt": retrieved_context.get("prompt_context", "")[:2000]
        }

    def save(self, audit_log: Dict[str, Any], path: str = "audit_log.json"):
        with open(path, "w", encoding="utf-8") as f:
            json.dump(audit_log, f, indent=2, default=str)
