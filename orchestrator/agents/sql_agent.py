import json
from typing import Dict, List
from orchestrator.shared.uais_client import call_llm


class SqlAgent:
    def build_db_context_queries(self, canonical_json: Dict) -> List[str]:
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
                    f"AND CONVERT(date, effdate) = CONVERT(date, '{safe_date}');"
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

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]

        return call_llm(messages, temperature=0, max_tokens=3000)