import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[2] / 'database' / 'rate_manager.sqlite'

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()

print('Connected to SQLite DB at', DB_PATH)

# -------------------------------
# STEP 1: CONTEXT FETCH
# -------------------------------
def get_next_state_id():
    cursor.execute('SELECT IFNULL(MAX(LUTSID), 0) + 1 FROM LUT_PricerTypeAPRPro_State')
    return cursor.fetchone()[0]

# -------------------------------
# STEP 2: AGENT GENERATED SQL
# (simulate your agent here)
# now just test trial commands
# -------------------------------
def generate_sql():
    next_id = get_next_state_id()

    sql = f"""
INSERT INTO LUT_PricerTypeAPRPro_State
(LUTSID, LUTPTID, state_id, StateName, effdate, DisplayOrder, Enabled)
VALUES ({next_id}, 84, 'TX', 'Texas', DATE('now'), 5, 1);
"""

    return sql

# -------------------------------
# STEP 3: VALIDATION QUERY
# -------------------------------
validation_query = """
SELECT state_id, COUNT(*)
FROM LUT_PricerTypeAPRPro_State
GROUP BY state_id
HAVING COUNT(*) > 1;
"""

# -------------------------------
# STEP 4: EXECUTION + VALIDATION LOOP
# -------------------------------
def execute_and_validate():
    agent_sql = generate_sql()

    print("\nGenerated SQL:")
    print(agent_sql)

    try:
        conn.execute('BEGIN')
        conn.executescript(agent_sql)

        print("\nSQL Executed")

        cursor.execute(validation_query)
        rows = cursor.fetchall()

        if len(rows) == 0:
            print("\nVALIDATION PASSED")
            conn.commit()
        else:
            print("\nVALIDATION FAILED - Duplicate Found")
            for r in rows:
                print(r)
            conn.rollback()

    except Exception as e:
        print("\nERROR OCCURRED:")
        print(str(e))
        conn.rollback()

# -------------------------------
#  STEP 5: VERIFY DB ACCESS
# -------------------------------
def test_connection():
    cursor.execute('SELECT sqlite_version();')
    print("\nConnected to DB version:", cursor.fetchone()[0])

# -------------------------------
#  MAIN RUN
# -------------------------------
if __name__ == '__main__':
    test_connection()
    execute_and_validate()
