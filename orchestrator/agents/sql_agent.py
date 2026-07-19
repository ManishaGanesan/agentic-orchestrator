"""
orchestrator/agents/sql_agent.py
"""
import json
import os
import re
import sys
from typing import Dict, List
from llama_cpp import Llama

class SqlAgent:
    def __init__(self, model_path: str = ""):
        """
        Pulls the official, pristine vanilla Microsoft GGUF repository directly 
        into your local machine's native huggingface cache.
        """        
        print("\n⏳ [BOOT] Loading Microsoft Phi-3 model layers with clean native KV arrays...")
        self.llm = Llama.from_pretrained(
            repo_id="microsoft/Phi-3-mini-4k-instruct-gguf",
            filename="Phi-3-mini-4k-instruct-q4.gguf",
            n_ctx=4096,            
            n_batch=512,           
            verbose=False,         
            chat_format="chatml",   # ◄--- CHANGED FROM "phi-3" TO "chatml" TO MATCH VALID FORMATS
            n_gpu_layers=-1        
        )
        print("✅ [BOOT SUCCESS] Model running optimally on local hardware architecture.")

    def build_db_context_queries(self, canonical_json: Dict) -> List[str]:
        if isinstance(canonical_json, str):
            try:
                canonical_json = json.loads(canonical_json)
            except json.JSONDecodeError:
                canonical_json = {}
        elif isinstance(canonical_json, list) and len(canonical_json) > 0:
            item = canonical_json[0]
            if isinstance(item, dict) and "content" in item:
                try:
                    canonical_json = json.loads(item["content"])
                except:
                    canonical_json = {}
            elif isinstance(item, dict):
                canonical_json = item

        state_procs = canonical_json.get("state_procedures", []) if isinstance(canonical_json, dict) else []
        
        if state_procs and isinstance(state_procs, list):
            first_proc = state_procs[0]
            if isinstance(first_proc, dict):
                state_name = first_proc.get("state_name", "MedicaidAPGPro")
                return [f"SELECT * FROM LUT_PricerType WHERE pricertypedescr = '{state_name}';"]
                
        return ["SELECT * FROM LUT_PricerType WHERE pricertypedescr LIKE '%Pro%';"]

    def _sanitize_generated_sql(self, raw_text: str, fallback_text: str = "") -> str:
        if not raw_text:
            return fallback_text
        cleaned = raw_text.replace("\x00", "")
        cleaned = cleaned.replace("```sql", "").replace("```", "")
        cleaned = re.sub(r"<think[^>]*>.*?</think>", "", cleaned, flags=re.S | re.I)
        return cleaned.strip()

    def generate_sql(self, retrieved_context: Dict, db_context_results: Dict, script_guide_text: str, base_template_text: str, use_cot: bool = False) -> str:
        canonical_json = retrieved_context.get("canonical_json", {})
        if isinstance(canonical_json, str):
            try: canonical_json = json.loads(canonical_json)
            except json.JSONDecodeError: canonical_json = {}

        state_procedures = canonical_json.get("state_procedures", []) if isinstance(canonical_json, dict) else []

        # Re-map target components cleanly
        lean_state_procedures = []
        if isinstance(state_procedures, list):
            for state in state_procedures:
                if isinstance(state, dict):
                    raw_procedures = state.get("procedures", [])
                    # Ensure pcodes are integers matching the SQLite schema mapping
                    clean_procedures = []
                    for p in raw_procedures:
                        if isinstance(p, dict) and "pcode" in p:
                            try:
                                clean_procedures.append(int(p.get("pcode")))
                            except (ValueError, TypeError):
                                continue
                    
                    if clean_procedures:
                        lean_state_procedures.append({
                            "state_id": state.get("state_id"),
                            "effective_date": state.get("effective_date", "2025-07-01 00:00:00"),
                            "pcodes": clean_procedures
                        })

        system_prompt = (
            "You are a deterministic T-SQL compiler engine. Output ONLY raw executable T-SQL statements. "
            "Never append any human dialogue, explanations, markdown formatting, or text blocks after the SQL commands."
        )

        user_prompt = f"""Task: Compile exact T-SQL script rows matching the following metadata matrix.

[LIVE DATABASE DETAILS]
Target Columns for States: (state_id, effective_date)
Target Columns for StateProcedures: (state_id, pcode)

[INPUT SPECIFICATION MATRIX]
{json.dumps(lean_state_procedures, indent=1)}

[EXACT FORMAT EXAMPLE]
INSERT INTO [dbo].[LUT_PricerTypeAPRPro_State] ([state_id], [effective_date]) VALUES ('VA', '2025-07-01 00:00:00');
INSERT INTO [dbo].[LUT_PricerTypeAPRPro_StateProcedure] ([state_id], [pcode]) VALUES ('VA', 1);

[STRICT ENFORCEMENT]
Generate one separate INSERT statement per procedure code line. 
Do not write markdown block ticks. Stop immediately after the final SQL statement.

SQL Outputs:"""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]

        response = self.llm.create_chat_completion(
            messages=messages,
            max_tokens=2000,
            temperature=0.0,
            stream=False,
            stop=["<|", "```", "User:", "\n\n\n"] # Force the engine to instantly stop if it hits markdown endings or special system tokens
        )

        raw_output = ""
        if isinstance(response, dict) and "choices" in response and len(response["choices"]) > 0:
            choice = response["choices"][0]
            if "message" in choice and "content" in choice["message"]:
                raw_output = choice["message"]["content"]
                
        return self._sanitize_generated_sql(raw_output, fallback_text=base_template_text)
    


