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
    def __init__(self, model_path: str = "./models/Phi-3-mini-4k-instruct-q4.gguf"):
        n_threads = os.cpu_count() or 4
        # Configure advanced memory flags for unquantized models on limited RAM hardware
        self.llm = Llama(
            model_path=model_path,
            n_ctx=16384,           # ◄--- BUMP THIS TO 12288 TO SAFELY FIT YOUR 9520 TOKENS
            n_batch=512,           # ◄--- LOWER BATCH SIZE TO KEEPS INGESTION RAM SPIKES LOW
            n_threads=n_threads,
            verbose=True,
            chat_format="phi-3",
            n_gpu_layers=-1 ,# Metal Acceleration ON
            # Keep these tight 8-bit cache flags active to safeguard your RAM
            type_k=1,              
            type_v=1,              
            f16_kv=False           
        )

    def build_db_context_queries(self, canonical_json: Dict) -> List[str]:
        # FIX: If canonical_json is a string payload or wrapped inside a list, extract/parse it cleanly
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

        # Safely treat it as a dictionary now
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
        # 1. Safely resolve canonical_json down to a dictionary no matter what format RAG returns
        canonical_json = retrieved_context.get("canonical_json", {})
        
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

        # 2. Safely capture the state procedures list
        raw_state_procedures = []
        if isinstance(canonical_json, dict):
            raw_state_procedures = canonical_json.get("state_procedures", [])
            # If the whole list was serialized as a string field, parse it
            if isinstance(raw_state_procedures, str):
                try:
                    raw_state_procedures = json.loads(raw_state_procedures)
                except json.JSONDecodeError:
                    raw_state_procedures = []

        # 3. Clean and isolate lean fields defensively
        lean_state_procedures = []
        if isinstance(raw_state_procedures, list):
            for state in raw_state_procedures:
                # If an element in the list is a string, unpack it dynamically
                if isinstance(state, str):
                    try:
                        state = json.loads(state)
                    except json.JSONDecodeError:
                        continue
                
                if not isinstance(state, dict):
                    continue

                # Safely extract target procedures array
                raw_procedures = state.get("procedures", [])
                if isinstance(raw_procedures, str):
                    try:
                        raw_procedures = json.loads(raw_procedures)
                    except json.JSONDecodeError:
                        raw_procedures = []

                clean_procedures = []
                if isinstance(raw_procedures, list):
                    for p in raw_procedures:
                        if isinstance(p, str):
                            try:
                                p = json.loads(p)
                            except json.JSONDecodeError:
                                continue
                        
                        if isinstance(p, dict) and "pcode" in p:
                            clean_procedures.append({
                                "display_order": p.get("display_order"),
                                "pcode": p.get("pcode")
                            })

                lean_state_procedures.append({
                    "state_id": state.get("state_id"),
                    "effective_date": state.get("effective_date"),
                    "action": state.get("action"),
                    "procedures": clean_procedures
                })

        # --- REST OF THE CODE REMAINS EXACTLY UNTOUCHED ---
        system_prompt = (
            "You are an automated medical reimbursement database migration script engine.\n"
            "You convert functional payload specifications into structurally sound, executable T-SQL queries.\n"
            "Output only raw executable statements. Never wrap blocks in markdown fences, text introductions, or analytical conclusions."
        )

        user_prompt = f"""=== REGULATORY BUSINESS LOGIC & HISTORICAL MATCHES (RAG Context) ===
        {retrieved_context.get('prompt_context', '')}

        === TARGET STRUCTURAL LAYOUT RULES ===
        {script_guide_text}

        === LIVE SCHEMA LOOKUP REFERENCE MATRICES ===
        {json.dumps(db_context_results, indent=2)}

        === ACTIVE INPUT TRANSFORMATION DATA OBJECT ===
        {json.dumps(lean_state_procedures, indent=2)}

        CONVERSION MISSION:
        1. Parse the action property inside the active input data object. If it demands an 'UPDATE', output a DELETE query targeting the matching table tracking variables pulled from the Live Schema Matrix.
        2. For every sequence unit inside the procedures structure, output a corresponding row INSERT sequence following the exact layout instructions and variable configurations defined in the target structural layout rules.

        Produce your structured migration script immediately below:"""

        full_prompt = f"<|system|>\n{system_prompt}<|end|>\n<|user|>\n{user_prompt}<|end|>\n<|assistant|>\n"

        tokens_iterator = self.llm.create_completion(
            prompt=full_prompt,
            max_tokens=2548,
            temperature=0.0,
            repeat_penalty=1.15,
            stop=["<|end|>", "<|user|>"],
            stream=True 
        )

        gathered_chunks = []
        for chunk in tokens_iterator:
            token_text = chunk["choices"][0]["text"]
            gathered_chunks.append(token_text)
            sys.stdout.write(token_text)
            sys.stdout.flush()
            
        print("\n=========================================================================\n")

        raw_output = ""
        if isinstance(gathered_chunks, list) and gathered_chunks:
            raw_output = "".join(gathered_chunks).strip()
        else:
            print("[WARNING] Unexpected response format from LLM.")
            
        print("\n=========================================================================\n")

        return self._sanitize_generated_sql(raw_output, fallback_text=base_template_text)
    

