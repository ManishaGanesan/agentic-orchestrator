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
            n_ctx=12288,           # ◄--- BUMP THIS TO 12288 TO SAFELY FIT YOUR 9520 TOKENS
            n_batch=256,           # ◄--- LOWER BATCH SIZE TO KEEPS INGESTION RAM SPIKES LOW
            n_threads=n_threads,
            n_gpu_layers=-1,       
            verbose=True,
            chat_format="phi-3",
            # Keep these tight 8-bit cache flags active to safeguard your RAM
            type_k=1,              
            type_v=1,              
            f16_kv=False           
        )

    def build_db_context_queries(self, canonical_json: Dict) -> List[str]:
        state_procs = canonical_json.get("state_procedures", [])
        if state_procs:
            state_name = state_procs[0].get("state_name", "MedicaidAPGPro")
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
        raw_state_procedures = canonical_json.get("state_procedures", [])
        
        # Pull only what is absolutely necessary for the model to do its job
        lean_state_procedures = []
        for state in raw_state_procedures:
            lean_state_procedures.append({
                "state_id": state.get("state_id"),
                "effective_date": state.get("effective_date"),
                "action": state.get("action"),
                # Extract only the essential code and sequence order arrays
                "procedures": [
                    {"display_order": p.get("display_order"), "pcode": p.get("pcode")}
                    for p in state.get("procedures", []) if "pcode" in p
                ]
            })

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
        print("\n================ [LOG D: Full prompt] ================")
        print(full_prompt)

        print("\n================ [LOG E: SLM REAL-TIME GENERATION STREAM] ================")
        sys.stdout.write("Streaming tokens: ")
        sys.stdout.flush()

        # 3. Stream token loop iteration
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

        raw_output = "".join(gathered_chunks).strip()
        return self._sanitize_generated_sql(raw_output, fallback_text=base_template_text)


