import sqlite3
from pathlib import Path
from typing import Dict, Any


class ValidationAgent:
    def __init__(self, db_path: str):
        db_file = Path(db_path)
        if not db_file.exists():
            raise FileNotFoundError(f"SQLite database file not found: {db_file}")
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()

    def test_connection(self) -> str:
        self.cursor.execute("SELECT sqlite_version()")
        return self.cursor.fetchone()[0]

    def run_sql_in_transaction(self, sql_script: str) -> Dict[str, Any]:
        try:
            self.conn.execute("BEGIN")
            self.conn.executescript(sql_script)

            # Add custom validation queries here if needed
            # example:
            # self.cursor.execute("SELECT ...")
            # validation_rows = self.cursor.fetchall()

            self.conn.rollback()
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