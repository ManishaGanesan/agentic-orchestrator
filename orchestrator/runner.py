"""
orchestrator/runner.py
"""
import json
import sys
from pathlib import Path
from typing import Callable, Optional

# Track root directory context pathing boundaries
ROOT_DIR = Path(__file__).parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.append(str(ROOT_DIR))

from orchestrator.agents.context_agent import ContextAgent
from orchestrator.agents.retriever_agent import RetrieverAgent
from orchestrator.agents.sql_agent import SqlAgent
from orchestrator.agents.validation_agent import ValidationAgent
from orchestrator.agents.audit_agent import AuditAgent


def _emit_progress(progress_callback: Optional[Callable[[str, str], None]], step: str, message: str) -> None:
    if progress_callback:
        progress_callback(step, message)
    print(f"[PROGRESS][{step}] {message}")


def execute_research_ablation_pipeline(
    strategy: str = "hybrid",
    use_cot: bool = False,
    progress_callback: Optional[Callable[[str, str], None]] = None,
):
    """
    Consumes output.json, queries your custom vector stores,
    and runs generation through your fine-tuned local model.
    """
    input_json_path = ROOT_DIR / "output_jsons/output.json"

    if not input_json_path.exists():
        _emit_progress(progress_callback, "input", f"Input file not found: {input_json_path}")
        return

    _emit_progress(progress_callback, "started", f"Pipeline triggered with strategy {strategy.upper()}")

    with open(input_json_path, "r", encoding="utf-8") as f:
        web_app_canonical_json = json.load(f)

    MODEL_PATH = str(ROOT_DIR / "models" / "Phi-3-mini-4k-instruct-q4.gguf")
    DATABASE_PATH = str(ROOT_DIR / "database" / "rate_manager.sqlite")

    context_agent = ContextAgent()
    sql_agent = SqlAgent(model_path=MODEL_PATH)
    validation_agent = ValidationAgent(db_path=DATABASE_PATH)
    audit_agent = AuditAgent()
    retriever_agent = RetrieverAgent(knowledge_path=str(ROOT_DIR / "orchestrator" / "knowledge"))

    _emit_progress(progress_callback, "context", "Building task context from the canonical payload")
    task = context_agent.build_task(web_app_canonical_json)

    _emit_progress(progress_callback, "retrieval", "Retrieving relevant knowledge with the selected strategy")
    retrieved_context = retriever_agent.get_context(task, strategy=strategy)

    _emit_progress(progress_callback, "schema", "Preparing schema and database context")
    db_queries = sql_agent.build_db_context_queries(web_app_canonical_json)
    mock_db_results = {
        "LUT_PricerType": [{"pricertypetid": 12, "pricertypedescr": web_app_canonical_json.get("pricer_type_description", "APR Pro Pricing")}],
        "LUT_PricerTypeAPRPro_State": [{"state_id": "TX", "effdate": "2026-01-01"}],
    }

    script_guide_path = ROOT_DIR / "orchestrator" / "knowledge" / "Script_guide.txt"
    base_template_path = ROOT_DIR / "orchestrator" / "knowledge" / "V191100-v191101_RateManager.sql"

    with open(script_guide_path, "r", encoding="utf-8", errors="ignore") as f:
        script_guide_text = f.read()[:1500]

    if base_template_path.exists():
        with open(base_template_path, "r", encoding="utf-8") as f:
            full_template = f.read()
            start_marker = "/***************** The following type of updates"
            end_marker = "ALTER TABLE [dbo].[LUT_RateGrouperVersion] ADD CONSTRAINT"
            start_idx = full_template.find(start_marker)
            end_idx = full_template.find(end_marker)
            if start_idx != -1 and end_idx != -1:
                base_template_text = full_template[start_idx:end_idx].strip()
            else:
                base_template_text = full_template[:1500]
    else:
        base_template_text = "-- [Fallback Baseline Template]"

    _emit_progress(progress_callback, "generation", "Generating SQL with the local model")
    generated_sql = sql_agent.generate_sql(
        retrieved_context=retrieved_context,
        db_context_results=mock_db_results,
        script_guide_text=script_guide_text,
        base_template_text=base_template_text,
        use_cot=use_cot,
    )

    if "</thinking>" in generated_sql:
        final_templated_sql = generated_sql.split("</thinking>")[-1].strip()
    else:
        final_templated_sql = generated_sql.replace("```sql", "").replace("```", "").strip()

    _emit_progress(progress_callback, "validation", "Running validation against the local database")
    validation_status = validation_agent.run_sql_in_transaction(final_templated_sql)

    FINAL_SCRIPTS_DIR = ROOT_DIR / "Final_scripts"
    FINAL_SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)

    prev_version = web_app_canonical_json.get("previous_version", "V191100")
    new_version = web_app_canonical_json.get("new_version", "v191101")

    target_filename = f"{prev_version}-v{new_version.lstrip('Vv')}_RateManager.sql"
    final_output_path = FINAL_SCRIPTS_DIR / target_filename

    with open(final_output_path, "w", encoding="utf-8") as f_out:
        f_out.write(final_templated_sql)

    audit_log_path = FINAL_SCRIPTS_DIR / f"canonical_output_{strategy}.json"
    audit_log = audit_agent.build_audit_log(
        input_json=web_app_canonical_json,
        retrieved_context=retrieved_context,
        db_context_queries=db_queries,
        db_context_results=mock_db_results,
        generated_sql=final_templated_sql,
        validation_result=validation_status,
    )
    audit_agent.save(audit_log, path=str(audit_log_path))

    _emit_progress(progress_callback, "completed", f"Completed and wrote {final_output_path}")
