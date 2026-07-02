from typing import Dict, List

class ContextAgent:
    def build_task(self, input_json: Dict) -> Dict:
        """
        Parses complex application lifecycle telemetry JSON and distills 
        it down into a high-density, structured prompt summary.
        """
        # 1. Handle nested input data gracefully if runner.py wraps it
        if "canonical_json" in input_json and not input_json.get("state_procedures"):
            input_json = input_json["canonical_json"]

        # 2. Capture foundational structural metadata
        prev_ver = input_json.get("previous_version", "Unknown")
        new_ver = input_json.get("new_version", "Unknown")
        story_id = input_json.get("story_id") or "None"
        base_request = input_json.get("request", "Generate SQL script updates")

        # FIX 1: Initialize global metadata fallbacks OUTSIDE the loop
        live_state_id = "UNKNOWN"
        live_eff_date = "1900-01-01"
        pricer_descr = "UNKNOWN"
        global_procedures_list = []

        state_procedures = input_json.get("state_procedures", [])
        summary_blocks = []
        
        for idx, block in enumerate(state_procedures, start=1):
            state_name = block.get("state_name", "Unknown Table Scope")
            state_id = block.get("state_id", "N/A")
            effective_date = block.get("effective_date", "N/A")
            action = block.get("action", "UNKNOWN")
            
            # Fetch this block's specific procedures clean
            current_procedures = block.get("procedures", [])
            proc_count = len(current_procedures)
            
            # FIX 2: Capture the first primary target's data for your pipeline's metadata channel
            if idx == 1:
                live_state_id = state_id
                live_eff_date = effective_date
                pricer_descr = state_name
                global_procedures_list = current_procedures

            # Identify the numerical range of pcodes to capture processing bounds
            pcodes = []
            for p in current_procedures:  # Use the correct un-wiped variable
                pcode_val = p.get("pcode")
                if pcode_val is not None:
                    try:
                        pcodes.append(int(pcode_val))
                    except (ValueError, TypeError):
                        pcodes.append(pcode_val)
            
            pcode_range = "N/A"
            if pcodes:
                if all(isinstance(x, int) for x in pcodes):
                    pcode_range = f"{min(pcodes)} to {max(pcodes)}"
                else:
                    pcode_range = f"'{pcodes[0]}' to '{pcodes[-1]}'"

            # Build a clean, high-density bullet point for this data block
            summary_block = (
                f"Modification Block {idx}:\n"
                f"  - Action Target: {action} records\n"
                f"  - Table Context: [dbo].[{state_name}]\n"
                f"  - Regional Identifier (State): {state_id}\n"
                f"  - Effective Date Timeline: {effective_date}\n"
                f"  - Volume Metrics: {proc_count} distinct procedure items mapped (Range: pcode {pcode_range})"
            )
            summary_blocks.append(summary_block)
            
        compiled_modifications = "\n\n".join(summary_blocks) if summary_blocks else "No target modification arrays discovered."

        # 3. Construct the clean task overview prompt
        distilled_prompt = (
            f"[TASK INTENT SUMMARY]\n"
            f"You are an automated schema migration agent managing delta version track: {prev_ver} -> {new_ver}.\n"
            f"Target System Intent: {base_request} (Tracking User Story: {story_id}).\n\n"
            f"[DATA MODIFICATION INSTRUCTIONS]\n"
            f"{compiled_modifications}\n\n"
            f"Cross-reference this extracted scope with the operational rules and historical syntax blueprints provided by the retriever. "
            f"Synthesize standard compliance T-SQL update statements encapsulated within an isolated database transaction block."
        )

        # FIX 3: Return the preserved global variables safely
        return {
            "user_request": distilled_prompt,
            "canonical_json": input_json,
            "metadata": {
                "live_state_id": live_state_id,
                "live_eff_date": live_eff_date,
                "pricer_descr": pricer_descr,
                "procedures": global_procedures_list
            }
        }

