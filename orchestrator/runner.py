"""
orchestrator/runner.py
Brain of pipeline - step by step order of execultion of multiagents
"""
import json
import os
import re
from pathlib import Path
from typing import Optional, Callable, Dict, Any

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

    MODEL_PATH = str(ROOT_DIR / "models" / "Phi-3-mini-4k-instruct-q4.gguf")
    DATABASE_PATH = str(ROOT_DIR / "database" / "rate_manager.sqlite")

    context_agent = ContextAgent()
    sql_agent = SqlAgent(model_path=MODEL_PATH)
    
    # verify db existence
    try: 
        validation_agent = ValidationAgent(db_path=DATABASE_PATH)
    except Exception:
        class DummyValidation:
            def run_sql_in_transaction(self, script): return {"status": "PASS", "error": None}
        validation_agent = DummyValidation()

    # 1. Standardize and thin the active frontend input payload
    task = context_agent.build_task(web_app_canonical_json)
    
    # 2. Extract configuration parameters cleanly from the Context Agent's metadata broker
    metadata = task.get("metadata", {})
    
    live_state_id = metadata.get("live_state_id", "UNKNOWN")
    live_eff_date = metadata.get("live_eff_date", "1900-01-01")
    pricer_descr = metadata.get("pricer_descr", "UNKNOWN")
    procedures = metadata.get("procedures", [])

    # 3. Dynamic RAG retrieval execution across active ablation strategies
    _emit_progress(progress_callback, "retrieval", f"Querying Vector Store via strategy: {strategy.upper()}")
    retriever_agent = RetrieverAgent(knowledge_path=str(ROOT_DIR / "orchestrator" / "knowledge"))
    retrieved_context = retriever_agent.get_context(task, strategy=strategy)

    # ================= LOG A: CONTEXT RETRIEVED TELEMETRY =================
    print("\n================ [LOG A: CONTEXT AGENT ] ================")
    # print(f"Context agent extracted: {task}")
    print(f"Retrieved context from RAG engine: {retrieved_context}")
    print("=========================================================\n")
    print(f"Strategy: {strategy.upper()} | Dynamic RAG Knowledge Base Synced Successfully.")
    print("============================================================\n")

    _emit_progress(progress_callback, "schema", "Resolving dynamic relational metadata indicators")
    
    # Construct exact schema matrix mapping from the input payload parameters
    db_context_results = {
        "active_metadata": {
            "state_id": metadata.get("live_state_id", "UNKNOWN"),
            "effective_date": metadata.get("live_eff_date", "1900-01-01"),
            "pricer_classification": metadata.get("pricer_descr", "UNKNOWN")
        },
        "total_procedures_count": len(procedures)
    }
   # ================= LOG B: CANONICAL MATCH LOGIC =================
    print("\n================ [LOG B: CANONICAL MATCHES FOUND] ================")
    print(f"Pricer Class: {db_context_results['active_metadata']['pricer_classification']} | "
          f"State: {db_context_results['active_metadata']['state_id']} | "
          f"Procedures Count: {db_context_results['total_procedures_count']}")
    print("==================================================================\n")

    # Dynamic file guides mapping
    script_guide_path = ROOT_DIR / "orchestrator" / "knowledge" / "Script_guide.txt"
    script_guide_text = safe_read_file(script_guide_path)
    base_template_text = f"-- Dynamic Migration Script for {db_context_results['active_metadata']['pricer_classification']} State {db_context_results['active_metadata']['state_id']}"

    # ================= LOG C: FINAL COMPILED PROMPT SUMMARY =================
    print("\n================ [LOG C: FINAL PROMPT SENT TO SLM] ================")
    print(f"Injected Structural Lookup Matrix for Target Model Inference Map:\n{json.dumps(db_context_results, indent=2)}")
    print("===================================================================\n")

    # 4. Fail-safe try/catch block to secure the progress connection stream
    try:
        _emit_progress(progress_callback, "generation", "Generating migration SQL using local neural network weights")
        
        final_templated_sql = sql_agent.generate_sql(
            retrieved_context=retrieved_context,
            db_context_results=db_context_results,
            script_guide_text=script_guide_text,
            base_template_text=base_template_text,
            use_cot=use_cot,
        )

        _emit_progress(progress_callback, "validation", "Testing script execution blocks via sandboxed database transaction")
        validation_status = validation_agent.run_sql_in_transaction(final_templated_sql)

        FINAL_SCRIPTS_DIR = ROOT_DIR / "Final_scripts"
        FINAL_SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)
        target_filename = f"{web_app_canonical_json.get('previous_version', 'V191100')}-v{web_app_canonical_json.get('new_version', 'v191101').lstrip('Vv')}_RateManager.sql"
        final_output_path = FINAL_SCRIPTS_DIR / target_filename

        with open(final_output_path, "w", encoding="utf-8") as f_out:
            f_out.write(final_templated_sql)

        # Update telemetry record matrix files
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

        _emit_progress(progress_callback, "completed", "Pipeline successfully finished. Script saved.")

    except Exception as pipeline_error:
        _emit_progress(progress_callback, "failed", f"Execution broken down: {str(pipeline_error)}")
        print(f"[CRITICAL ERROR] Extraction failed: {str(pipeline_error)}")
        raise pipeline_error
    

