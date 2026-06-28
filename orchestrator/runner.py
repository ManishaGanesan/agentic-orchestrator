"""
orchestrator/runner.py
Shared core execution function to prevent circular imports.
Can be safely imported by both the web app and root-level scripts.
"""
import os
import json
from pathlib import Path
import sys

# Track root directory context pathing boundaries
ROOT_DIR = Path(__file__).parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.append(str(ROOT_DIR))

from orchestrator.agents.context_agent import ContextAgent
from orchestrator.agents.retriever_agent import RetrieverAgent
from orchestrator.agents.sql_agent import SqlAgent
from orchestrator.agents.validation_agent import ValidationAgent
from orchestrator.agents.audit_agent import AuditAgent

def execute_research_ablation_pipeline(strategy: str = "hybrid"):
    """
    Consumes output.json, queries your custom vector stores,
    and runs generation through your fine-tuned local model.
    """
    input_json_path = ROOT_DIR / "output_jsons/output.json"
    
    if not input_json_path.exists():
        print(f"❌ Automation Error: {input_json_path} data check signature not found.")
        return

    print(f"\n⚡ [AGENT PIPELINE AUTOMATION TRIGGERED] Running Strategy: {strategy.upper()} ⚡")
    
    with open(input_json_path, "r", encoding="utf-8") as f:
        web_app_canonical_json = json.load(f)

    # Point this path to your fine-tuned local weights directory
    MODEL_PATH = "microsoft/Phi-3-mini-4k-instruct"     # Using Microsoft's Phi-3 mini lightweight model for testing
    DATABASE_PATH = str(ROOT_DIR / "rate_manager.sqlite")

    # Instantiate Agent Components
    context_agent = ContextAgent()
    retriever_agent = RetrieverAgent(knowledge_path=str(ROOT_DIR / "Knowledge"))
    sql_agent = SqlAgent(model_path=MODEL_PATH)
    validation_agent = ValidationAgent(db_path=DATABASE_PATH)
    audit_agent = AuditAgent()

    # Step 1: Format context tasks
    task = context_agent.build_task(web_app_canonical_json)

    # Step 2: Extract semantic documentation vectors 
    retrieved_context = retriever_agent.get_context(task, strategy=strategy)

    # Step 3: Run schema checks
    db_queries = sql_agent.build_db_context_queries(web_app_canonical_json)
    mock_db_results = {
        "LUT_PricerType": [{"pricertypetid": 12, "pricertypedescr": web_app_canonical_json.get("pricer_type_description", "APR Pro Pricing")}],
        "LUT_PricerTypeAPRPro_State": [{"state_id": "TX", "effdate": "2026-01-01"}]
    }

    # Step 4: Local SLM inference engine processing
    generated_sql = sql_agent.generate_sql(retrieved_context, mock_db_results)
    print(f"\n[Automated SQL Generation Fragment Completed]:\n{generated_sql[:300]}\n")

    # Step 5: Verify via local SQLite transactional checks
    validation_status = validation_agent.run_sql_in_transaction(generated_sql)
    print(f"   -> Transaction Test Execution: {validation_status['status']}")

    # Step 6: Write out the final audit trace files
    audit_log_path = ROOT_DIR / f"output_jsons/canonical_output_{strategy}.json"
    audit_log = audit_agent.build_audit_log(
        input_json=web_app_canonical_json,
        retrieved_context=retrieved_context,
        db_context_queries=db_queries,
        db_context_results=mock_db_results,
        generated_sql=generated_sql,
        validation_result=validation_status
    )
    audit_agent.save(audit_log, path=str(audit_log_path))
    print(f"💾 Step Complete: Traces saved directly to {audit_log_path}\n")