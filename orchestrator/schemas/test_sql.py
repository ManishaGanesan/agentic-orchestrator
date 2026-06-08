import pyodbc

# -------------------------------
# CONNECTION CONFIG
# -------------------------------
conn = pyodbc.connect(
    "Driver={SQL Server};"
    "Server=wn000191827;"
    "Database=RateMAnager_QA;"
    "Trusted_Connection=yes;"
)

cursor = conn.cursor()

print(" Connected to DB")

# -------------------------------
# STEP 1: CONTEXT FETCH
# -------------------------------
def get_next_state_id():
    cursor.execute("SELECT ISNULL(MAX(LUTSID),0) + 1 FROM dbo.LUT_PricerTypeAPRPro_State")
    return cursor.fetchone()[0]

# -------------------------------
# STEP 2: AGENT GENERATED SQL
# (simulate your agent here)
# now just test trial commands
# -------------------------------
def generate_sql():
    next_id = get_next_state_id()

    sql = f"""
    INSERT INTO dbo.LUT_PricerTypeAPRPro_State
    (LUTSID, LUTPTID, state_id, StateName, effdate, DisplayOrder, Enabled)
    VALUES ({next_id}, 84, 'TX', 'Texas', GETDATE(), 5, 1)
    """

    return sql

# -------------------------------
# STEP 3: VALIDATION QUERY
# -------------------------------
validation_query = """
SELECT state_id, COUNT(*)
FROM dbo.LUT_PricerTypeAPRPro_State
GROUP BY state_id
HAVING COUNT(*) > 1
"""

# -------------------------------
# STEP 4: EXECUTION + VALIDATION LOOP
# -------------------------------
def execute_and_validate():

    agent_sql = generate_sql()

    print("\nGenerated SQL:")
    print(agent_sql)

    try:
        # Start transaction
        cursor.execute("BEGIN TRANSACTION")

        # Execute agent SQL
        cursor.execute(agent_sql)

        print("\nSQL Executed")

        # Run validation
        cursor.execute(validation_query)
        rows = cursor.fetchall()

        #  Decision
        if len(rows) == 0:
            print("\nVALIDATION PASSED")
            cursor.execute("COMMIT")
        else:
            print("\n VALIDATION FAILED - Duplicate Found")
            for r in rows:
                print(r)
            cursor.execute("ROLLBACK")

    except Exception as e:
        print("\n ERROR OCCURRED:")
        print(str(e))
        cursor.execute("ROLLBACK")

# -------------------------------
#  STEP 5: VERIFY DB ACCESS
# -------------------------------
def test_connection():
    cursor.execute("SELECT DB_NAME()")
    print("\nConnected to DB:", cursor.fetchone()[0])

# -------------------------------
#  MAIN RUN
# -------------------------------
if __name__ == "__main__":
    test_connection()
    execute_and_validate()