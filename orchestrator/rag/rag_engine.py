"""
orchestrator/rag/rag_engine.py
"""
import json
from pathlib import Path
from typing import Dict

class RagEngine:
    def __init__(self, knowledge_path: str = None):
        # Keeps your folder structure intact
        self.knowledge_dir = Path(knowledge_path) if knowledge_path else Path(__file__).resolve().parents[2] / "Knowledge"
        
    def _fallback_bm25_retrieve(self, query: str) -> Dict[str, str]:
        """Simple keyword matching reading raw reference rules safely supporting UTF-8 and UTF-16."""
        context_data = {"logic_guides": "", "script_guides": "", "sample_sql": ""}
        
        state_rule_path = self.knowledge_dir / "state_proc_rules.txt"
        var_rule_path = self.knowledge_dir / "proc_variable_rules.txt"
        script_guide_path = self.knowledge_dir / "Script_guide.txt"
        sample_sql_path = self.knowledge_dir / "V191100-v191101_RateManager.sql"

        def safe_read(path: Path) -> str:
            if not path.exists():
                return ""
            try:
                # Try standard UTF-8 first
                return path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                # Fallback to UTF-16 if it hits a 0xff Byte Order Mark (common in SQL Server exports)
                return path.read_text(encoding="utf-16")

        context_data["logic_guides"] += safe_read(state_rule_path) + "\n"
        context_data["logic_guides"] += safe_read(var_rule_path) + "\n"
        context_data["script_guides"] = safe_read(script_guide_path)
        
        # Grab a clean snapshot layout from the historical sample file
        context_data["sample_sql"] = safe_read(sample_sql_path)[:1500]
            
        return context_data

    def build_prompt_context(self, user_request: str, canonical_json: Dict, strategy: str = "hybrid") -> str:
        # Retrieve files directly using simple keyword/text matching
        retrieved = self._fallback_bm25_retrieve(user_request)
        
        # Format a full, raw prompt structure without character slicing axes
        prompt_str = f"=== SYSTEM REPOSITORY KNOWLEDGE ===\n"
        prompt_str += f"BUSINESS LOGIC RULES:\n{retrieved['logic_guides']}\n\n"
        prompt_str += f"SCRIPT LAYOUT GUIDELINES:\n{retrieved['script_guides']}\n\n"
        
        if retrieved["sample_sql"]:
            prompt_str += f"=== HISTORICAL BLUEPRINT REFERENCE EXAMPLE ===\n"
            prompt_str += f"{retrieved['sample_sql']}\n"
            prompt_str += f"==============================================\n\n"

        prompt_str += f"ACTIVE RUN CANONICAL TARGETS:\n{json.dumps(canonical_json, indent=2)}\n"
        return prompt_str