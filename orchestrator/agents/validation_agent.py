import pyodbc
from typing import Dict, Any


class ValidationAgent:
    def __init__(self, connection_string: str):
        self.conn = pyodbc.connect(connection_string)
        self.cursor = self.conn.cursor()

    def test_connection(self) -> str:
        self.cursor.execute("SELECT DB_NAME()")
        return self.cursor.fetchone()[0]

    def run_sql_in_transaction(self, sql_script: str) -> Dict[str, Any]:
        try:
            self.cursor.execute("BEGIN TRANSACTION")

            statements = [s.strip() for s in sql_script.split(";") if s.strip()]
            for stmt in statements:
                self.cursor.execute(stmt)

            # Add custom validation queries here if needed
            # example:
            # self.cursor.execute("SELECT ...")
            # validation_rows = self.cursor.fetchall()

            self.cursor.execute("ROLLBACK")
            return {
                "status": "PASS",
                "error": None
            }

        except Exception as e:
            try:
                self.cursor.execute("ROLLBACK")
            except Exception:
                pass

            return {
                "status": "FAIL",
                "error": str(e)
            }