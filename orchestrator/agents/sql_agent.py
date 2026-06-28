import json
from typing import Dict, List
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM


class SqlAgent:
    def __init__(self, model_path: str = "path/to/your/fine-tuned-slm"):
        """
        Initializes the local fine-tuned Small Language Model (SLM) for offline inference.
        """
        self.tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
        self.model = AutoModelForCausalLM.from_pretrained(
            model_path, 
            torch_dtype=torch.float16, 
            device_map="auto",
            trust_remote_code=True
        )

    def build_db_context_queries(self, canonical_json: Dict) -> List[str]:
        """
        PRESERVED EXACTLY FROM ORIGINAL:
        Executes Steps 1 through 4 of your logic guide to resolve IDs and find existing rows.
        """
        queries = []

        # Step 1 from your logic guide:
        # resolve pricer type / LUTPTID
        pricer_descr = canonical_json.get("pricer_type_description")
        if pricer_descr:
            safe_pricer = str(pricer_descr).replace("'", "''")
            queries.append(
                f"SELECT * FROM LUT_PricerType WHERE pricertypedescr = '{safe_pricer}';"
            )
        else:
            queries.append(
                "SELECT * FROM LUT_PricerType WHERE pricertypedescr LIKE '%Pro%';"
            )

        # Step 2 / Step 3: state_procedures
        for sp in canonical_json.get("state_procedures", []):
            state_acronym = sp.get("state_acronym")
            eff_date = sp.get("effective_date")

            if state_acronym and eff_date:
                safe_state = str(state_acronym).replace("'", "''")
                safe_date = str(eff_date).replace("'", "''")

                queries.append(
                    "SELECT * FROM LUT_PricerTypeAPRPro_State "
                    f"WHERE state_id = '{safe_state}' "
                    f"AND DATE(effdate) = DATE('{safe_date}');"
                )

            for proc in sp.get("procedures", []):
                pcode = proc.get("pcode")
                if pcode:
                    safe_pcode = str(pcode).replace("'", "''")
                    queries.append(
                        "SELECT * FROM LUT_PricerTypeAPRPro_Procedure "
                        f"WHERE PCode = '{safe_pcode}';"
                    )

        # Step 4: procedure_variables
        for pv in canonical_json.get("procedure_variables", []):
            pcode_info = pv.get("pcode", {})
            if isinstance(pcode_info, dict):
                pcode_val = pcode_info.get("value")
            else:
                pcode_val = pcode_info

            if pcode_val:
                safe_pcode = str(pcode_val).replace("'", "''")
                queries.append(
                    "SELECT * FROM LUT_PricerTypeAPRPro_Procedure "
                    f"WHERE PCode = '{safe_pcode}';"
                )

            for var in pv.get("variables", []):
                variable_name = var.get("variable_name")
                if variable_name:
                    safe_var = str(variable_name).replace("'", "''")
                    queries.append(
                        "SELECT * FROM LUT_PricerTypeVariable "
                        f"WHERE VariableName = '{safe_var}';"
                    )

        return queries

    def generate_sql(self, retrieved_context: Dict, db_context_results: Dict) -> str:
        """
        PRESERVED EXACTLY FROM ORIGINAL:
        Enforces all 8 strict procedural and formatting rules using the local fine-tuned model.
        """
        system_prompt = """
You are a SQL Server regulatory SQL generation agent.

Strict rules:
1. Canonical JSON is the primary source of truth.
2. Logic guides define how to validate ADD vs UPDATE and how to plan steps.
3. Script guides and templates define SQL style and ordering.
4. DB context results resolve IDs and determine whether records already exist.
5. Generate only SQL Server SQL.
6. Return only executable SQL script.
7. If an existing state is updated and procedure order must be replaced, delete old StateProcedure rows before inserting new ordered rows.
8. If required context is missing, generate the safest valid SQL possible based on available context and keep script readable.
"""

        user_prompt = f"""
PROMPT CONTEXT:
{retrieved_context["prompt_context"]}

DB CONTEXT RESULTS:
{json.dumps(db_context_results, indent=2)}

TASK:
Generate the final SQL script.
"""

        # Structuring the inputs into the exact chat template your local model expects
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
        
        # Apply the model-specific token formatting safely
        input_ids = self.tokenizer.apply_chat_template(
            messages, 
            add_generation_prompt=True, 
            return_tensors="pt"
        ).to(self.model.device)

        # Deterministic generation for rigorous testing
        with torch.no_grad():
            output_ids = self.model.generate(
                input_ids,
                max_new_tokens=2048,  # Increased room for comprehensive multi-step scripts
                temperature=0.1,      # Low temperature ensures the model adheres strictly to the rules
                do_sample=False
            )
            
        # Decode and isolate only the freshly generated tokens
        generated_text = self.tokenizer.decode(
            output_ids[0][input_ids.shape[1]:], 
            skip_special_tokens=True
        )
        
        return generated_text