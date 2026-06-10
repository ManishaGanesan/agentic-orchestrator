import json
import os
import pyodbc

from orchestrator.agents.context_agent import ContextAgent
from orchestrator.agents.retriever_agent import RetrieverAgent
from orchestrator.agents.sql_agent import SqlAgent
from orchestrator.agents.validation_agent import ValidationAgent
from orchestrator.agents.audit_agent import AuditAgent


CONNECTION_STRING = (
    "Driver={SQL Server};"
    "Server=wn000191827;"
    "Database=RateManager_DEV;"
    "Trusted_Connection=yes;"
)


def execute_context_queries(connection_string, queries):
    conn = pyodbc.connect(connection_string)
    cursor = conn.cursor()

    output = {}
    for i, query in enumerate(queries, start=1):
        try:
            cursor.execute(query)
            cols = [c[0] for c in cursor.description] if cursor.description else []
            rows = cursor.fetchall() if cursor.description else []
            output[f"query_{i}"] = {
                "sql": query,
                "columns": cols,
                "rows": [[str(col) if hasattr(col, "isoformat") else col for col in r] for r in rows
]
            }
        except Exception as e:
            output[f"query_{i}"] = {
                "sql": query,
                "error": str(e)
            }

    conn.close()
    return output


def main():
    # Example input path
    input_path = os.path.join("Input_excels", "output.json")

    with open(input_path, "r", encoding="utf-8") as f:
        input_json = json.load(f)

    context_agent = ContextAgent()
    retriever_agent = RetrieverAgent(knowledge_path="Knowledge")
    sql_agent = SqlAgent()
    validation_agent = ValidationAgent(CONNECTION_STRING)
    audit_agent = AuditAgent()

    task = context_agent.build_task(input_json)
    retrieved_context = retriever_agent.get_context(task)

    db_context_queries = sql_agent.build_db_context_queries(task["canonical_json"])
    db_context_results = execute_context_queries(CONNECTION_STRING, db_context_queries)

    generated_sql = sql_agent.generate_sql(retrieved_context, db_context_results)
    validation_result = validation_agent.run_sql_in_transaction(generated_sql)

    print("\n=== GENERATED SQL ===\n")
    print(generated_sql)

    print("\n=== VALIDATION RESULT ===\n")
    print(validation_result)

    audit_log = audit_agent.build_audit_log(
        input_json=input_json,
        retrieved_context=retrieved_context,
        db_context_queries=db_context_queries,
        db_context_results=db_context_results,
        generated_sql=generated_sql,
        validation_result=validation_result
    )
    audit_agent.save(audit_log, path="audit_log.json")


if __name__ == "__main__":
    main()



# # from uais_client import call_llm
# from dataset_builder.input_processor import InputProcessor
# import json
# import os
# # def test_llm():

# #     messages = [
# #         {
# #             "role": "system",
# #             "content": "You are a helpful assistant. Reply in one short sentence."
# #         },
# #         {
# #             "role": "user", 
# #             "content": "Hi, what is a prime number?"
# #         }
# #     ]

# #     response = call_llm(messages)

# #     print("\n LLM RESPONSE:\n")
# #     print(response)

# def test_inputprocessor():

#     INPUT_DIR = "input_excels/"

#     result = processor.process_folder(INPUT_DIR)

#     print(json.dumps(result, indent=2, default=str))

#     output_file = os.path.join(INPUT_DIR, "output.json")
#     with open(output_file, "w") as f:
#         json.dump(result, f, indent=2, default=str)

#     print(f"Output saved to: {output_file}")



# processor = InputProcessor()

# if __name__ == "__main__":
#     #test_llm()
#     test_inputprocessor()




