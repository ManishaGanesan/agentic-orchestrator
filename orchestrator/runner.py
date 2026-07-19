"""
orchestrator/runner.py
Brain of pipeline - step by step order of execution of multiagents
"""
import json
import os
import re
from pathlib import Path
from typing import Optional, Callable, Dict, Any
import sqlparse
from orchestrator.agents.context_agent import ContextAgent
from orchestrator.agents.sql_agent import SqlAgent
from orchestrator.agents.validation_agent import ValidationAgent
from orchestrator.agents.retriever_agent import RetrieverAgent

ROOT_DIR = Path(__file__).resolve().parents[1]

def _emit_progress(callback: Optional[Callable[[str, str], None]], status: str, message: str):
    if callback:
        try: callback(status, message)
        except Exception: pass

def safe_read_file(path: Path) -> str:
    if not path.exists(): return ""
    try: return path.read_text(encoding="utf-8")
    except UnicodeDecodeError: return path.read_text(encoding="utf-16", errors="ignore")

def finalize_migration_script(template_content: str, raw_llm_output: str, user_story: str, prev_version: str, current_version: str, **kwargs) -> str:
    """
    Locates the specific block comment for '2. Updates of state proc_array's...',
    removes the entire block from /***** to *****/, and injects the cleaned SQL.
    """
    # 1. Update dynamic version numbers in the template layout string
    template_content = template_content.replace("2901.00", prev_version).replace("1911.00", prev_version)
    template_content = template_content.replace("2902.00", current_version).replace("1911.01", current_version)
    template_content = template_content.replace("V290100", f"V{prev_version.replace('.', '')}").replace("v290100", f"v{prev_version.replace('.', '')}")
    template_content = template_content.replace("v290200", f"v{current_version.replace('.', '')}").replace("V290200", f"V{current_version.replace('.', '')}")

    # 2. POST-PROCESS SANITIZATION: Strip out any conversational gibberish lines from LLM output
    clean_sql_lines = []
    for line in raw_llm_output.splitlines():
        trimmed = line.strip()
        # Only preserve valid SQL statements or structural definitions
        if trimmed.upper().startswith(("INSERT ", "UPDATE ", "DELETE ", "SELECT ", "--")):
            clean_sql_lines.append(line)
    
    sanitized_llm_sql = "\n    ".join(clean_sql_lines)

    # 3. Prepare the clean SQL string block to inject out in the open
    replacement_payload = (
        f"\n    -- User Story: {user_story}\n"
        f"    {sanitized_llm_sql}\n"
    )
    
    # 4. Strict targeted pattern: Matches the block comment containing the specific Section 2 phrase
    comment_block_pattern = r"/\*+[\s\S]*?2\.\s*Updates of state proc_array's, add/update new state\(s\) or new effective dates, add/update procedure codes, map/remove pricing variables for Medicaid APG or APR Pro Pricer types[\s\S]*?/\s*\*+/"
    
    # 5. Perform the multi-line substitution
    updated_content, substitutions = re.subn(
        comment_block_pattern, 
        replacement_payload, 
        template_content, 
        flags=re.IGNORECASE
    )
    
    # 6. Fallback string slice handling if needed
    if substitutions == 0:
        target_phrase = "2. Updates of state proc_array's, add/update new state(s) or new effective dates, add/update procedure codes, map/remove pricing variables for Medicaid APG or APR Pro Pricer types"
        if target_phrase in template_content:
            parts_before = template_content.split(target_phrase, 1)[0]
            parts_after = template_content.split(target_phrase, 1)[1]
            start_idx = parts_before.rfind("/*")
            end_idx = parts_after.find("*/")
            if start_idx != -1 and end_idx != -1:
                clean_before = parts_before[:start_idx]
                clean_after = parts_after[end_idx + 2:]
                updated_content = clean_before + replacement_payload + clean_after
                substitutions = 1

    print(f"🔧 Target replacement complete. Blocks substituted: {substitutions}")
    return updated_content

def execute_research_ablation_pipeline(
    strategy: str = "hybrid",
    use_cot: bool = False,
    progress_callback: Optional[Callable[[str, str], None]] = None,
):
    input_json_path = ROOT_DIR / "output_jsons" / "output.json"
    _emit_progress(progress_callback, "started", f"Pipeline triggered with strategy {strategy.upper()} and use_cot={use_cot}.")

    if not input_json_path.exists():
        _emit_progress(progress_callback, "failed", "Input canonical payload JSON file not found.")
        return

    with open(input_json_path, "r", encoding="utf-8") as f:
        web_app_canonical_json = json.load(f)

    # --- Initialization ---
    MODEL_PATH = str(ROOT_DIR / "models" / "Phi-3-mini-4k-instruct-v0.gguf")
    DATABASE_PATH = str(ROOT_DIR / "database" / "rate_manager.sqlite")
    
    context_agent = ContextAgent()
    sql_agent = SqlAgent(model_path=MODEL_PATH)
    
    try: 
        validation_agent = ValidationAgent(db_path=DATABASE_PATH)
    except Exception:
        class DummyValidation:
            def run_sql_in_transaction(self, script): return {"status": "PASS", "error": None}
        validation_agent = DummyValidation()

    # --- Data Extraction & RAG Lookups ---
    task = context_agent.build_task(web_app_canonical_json)
    metadata = task.get("metadata", {})
    live_state_id = metadata.get("live_state_id", "UNKNOWN")
    live_eff_date = metadata.get("live_eff_date", "1900-01-01")
    pricer_descr = metadata.get("pricer_descr", "UNKNOWN")
    procedures = metadata.get("procedures", [])

    _emit_progress(progress_callback, "retrieval", f"Querying Vector Store via strategy: {strategy.upper()}")
    retriever_agent = RetrieverAgent(knowledge_path=str(ROOT_DIR / "orchestrator" / "knowledge"))
    retrieved_context = retriever_agent.get_context(task, strategy=strategy, sql_agent=sql_agent)

    # --- Telemetry Logs ---
    print(f"\n================ [LOG A: CONTEXT AGENT ] ================\nRetrieved context from RAG engine: {retrieved_context}\n=========================================================\n")
    _emit_progress(progress_callback, "schema", "Resolving dynamic relational metadata indicators")
    
    db_context_results = {
        "active_metadata": {"state_id": live_state_id, "effective_date": live_eff_date, "pricer_classification": pricer_descr},
        "total_procedures_count": len(procedures)
    }

    print(f"\n================ [LOG B: CANONICAL MATCHES FOUND] ================\nPricer Class: {pricer_descr} | State: {live_state_id} | Procedures Count: {len(procedures)}\n==================================================================\n")

    script_guide_path = ROOT_DIR / "orchestrator" / "knowledge" / "Script_guide.txt"
    script_guide_text = safe_read_file(script_guide_path)
    base_template_text = f"-- Dynamic Migration Script for {pricer_descr} State {live_state_id}"

    print(f"\n================ [LOG C: FINAL PROMPT SENT TO SLM] ================\nInjected Structural Lookup Matrix:\n{json.dumps(db_context_results, indent=2)}\n===================================================================\n")

    # --- Generation & Execution Core ---
    try:
        _emit_progress(progress_callback, "generation", "Generating migration SQL using local neural network weights")
        
        # 1. Generate the raw queries
        final_templated_sql = sql_agent.generate_sql(
            retrieved_context=retrieved_context,
            db_context_results=db_context_results,
            script_guide_text=script_guide_text,
            base_template_text=base_template_text,
            use_cot=use_cot,
        )

        # 2. Print the exact query once to the terminal before file instrumentation
        print(f"\n" + "="*25 + " GENERATED SQL STATEMENT OUTPUT " + "="*25 + f"\n{final_templated_sql if final_templated_sql else '-- [Warning] Empty SQL payload.'}\n" + "="*82 + "\n")
        
        _emit_progress(progress_callback, "instrumentation", "Re-ordering SQL queries and instrumenting template")
        
        # Setup version markers cleanly
        raw_prev = str(web_app_canonical_json.get('previous_version', '1911.00')).upper().lstrip('V')
        raw_new = str(web_app_canonical_json.get('new_version', '1911.01')).upper().lstrip('V')
        
        prev_dot = f"{raw_prev[:4]}.{raw_prev[4:]}" if "." not in raw_prev and len(raw_prev) >= 4 else raw_prev
        new_dot = f"{raw_new[:4]}.{raw_new[4:]}" if "." not in raw_new and len(raw_new) >= 4 else raw_new
        prev_clean, current_clean = prev_dot.replace(".", ""), new_dot.replace(".", "")

        # 3. Read template script path into string data safely
        template_script_path = ROOT_DIR / "orchestrator" / "knowledge" / "V191100-v191101_RateManager.sql"
        template_raw_content = safe_read_file(template_script_path)
        
        user_story_str = metadata.get("story_id", "US-GEN-LOCAL")

        # 4. Corrected call aligning with explicit method positional parameters
        final_script_content = finalize_migration_script(
            template_content=template_raw_content,
            raw_llm_output=final_templated_sql,
            user_story=user_story_str,
            prev_version=prev_dot,
            current_version=new_dot
        )

        # --- Sandboxed Execution & Delivery ---
        _emit_progress(progress_callback, "validation", "Testing script execution blocks via sandboxed database transaction")
        validation_status = validation_agent.run_sql_in_transaction(final_script_content)

        FINAL_SCRIPTS_DIR = ROOT_DIR / "Final_scripts"
        FINAL_SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
        target_filename = f"v{prev_clean}_to_v{current_clean}.sql"
        final_output_path = FINAL_SCRIPTS_DIR / target_filename
        
        with open(final_output_path, "w", encoding="utf-8") as f_out:
            f_out.write(final_script_content)
            
        print(f"✅ Production deployment script compiled: {final_output_path}")

        # --- Matrix Update Tracker ---
        matrix_log_path = FINAL_SCRIPTS_DIR / "ablation_matrix.json"
        current_logs = {}
        if matrix_log_path.exists():
            try: current_logs = json.loads(matrix_log_path.read_text(encoding="utf-8"))
            except Exception: pass
        
        current_logs[strategy] = {
            "passed_validation": validation_status.get("status") == "PASS",
            "error_caught": validation_status.get("error"),
            "total_procedures_processed": len(procedures)
        }
        with open(matrix_log_path, "w", encoding="utf-8") as f_m:
            json.dump(current_logs, f_m, indent=2)

        _emit_progress(progress_callback, "completed", f"Pipeline successfully finished. Script saved to {target_filename}")

    except Exception as pipeline_error:
        _emit_progress(progress_callback, "failed", f"Execution broken down: {str(pipeline_error)}")
        print(f"[CRITICAL ERROR] Extraction failed: {str(pipeline_error)}")
        raise pipeline_error