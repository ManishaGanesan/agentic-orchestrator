import os
import re
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
TABLE_DIR = BASE_DIR / "tables"
POST_DEPLOY_DIR = BASE_DIR / "post-deployment scripts"
SQLITE_PATH = BASE_DIR / "rate_manager.sqlite"

TYPE_MAP = {
    "int": "INTEGER",
    "smallint": "INTEGER",
    "tinyint": "INTEGER",
    "bit": "INTEGER",
    "float": "REAL",
    "datetime": "TEXT",
    "date": "TEXT",
    "char": "TEXT",
    "varchar": "TEXT",
    "nvarchar": "TEXT",
    "text": "TEXT",
}

CREATE_TABLE_RE = re.compile(r"CREATE\s+TABLE\s+\[dbo\]\.\[(?P<table>[^\]]+)\]", re.IGNORECASE)
COLUMN_RE = re.compile(
    r"^\s*\[(?P<name>[^\]]+)\]\s+\[(?P<type>[^\]]+)\](?:\((?P<length>[^\)]+)\))?"
    r"(?P<nullable>.*)$",
    re.IGNORECASE,
)
INSERT_RE = re.compile(r"INSERT\s+\[dbo\]\.\[(?P<table>[^\]]+)\].*?VALUES\s*\((?P<values>[^)]+)\)", re.IGNORECASE)
CAST_RE = re.compile(r"CAST\s*\(\s*N?'(?P<inner>.*?)'\s+AS\s+\w+\s*\)", re.IGNORECASE)
STRING_RE = re.compile(r"^N?'(?P<content>(?:[^']|'')*)'$", re.IGNORECASE)


def read_text(path: Path) -> str:
    data = path.read_bytes()
    for enc in ("utf-16", "utf-8", "latin1"):
        try:
            return data.decode(enc)
        except Exception:
            continue
    raise ValueError(f"Unable to decode {path}")


def normalize_type(sql_type: str, length: str | None) -> str:
    base = sql_type.strip().lower()
    if base not in TYPE_MAP:
        return "TEXT"
    return TYPE_MAP[base]


def parse_create_table(sql: str) -> tuple[str, list[tuple[str, str, bool]]]:
    sql = sql.replace("\r\n", "\n").replace("\r", "\n")
    match = CREATE_TABLE_RE.search(sql)
    if not match:
        raise ValueError("CREATE TABLE statement not found")
    table_name = match.group("table")
    body_start = match.end()
    body = sql[body_start:]
    # Find the proper closing parenthesis by tracking nesting depth
    paren_depth = 0
    closing_paren_pos = -1
    for i, ch in enumerate(body):
        if ch == '(':
            paren_depth += 1
        elif ch == ')':
            paren_depth -= 1
            if paren_depth < 0:
                closing_paren_pos = i
                break
    if closing_paren_pos > 0:
        body = body[:closing_paren_pos]
    columns = []
    for line in body.splitlines():
        line = line.strip()
        if not line or line.upper().startswith("CONSTRAINT") or line.upper().startswith("PRIMARY KEY") or line.upper().startswith("UNIQUE"):
            continue
        col_match = COLUMN_RE.match(line)
        if not col_match:
            continue
        name = col_match.group("name")
        sql_type = col_match.group("type")
        length = col_match.group("length")
        nullable = "NOT NULL" in col_match.group("nullable").upper()
        column_type = normalize_type(sql_type, length)
        columns.append((name, column_type, nullable))
    return table_name, columns


def split_value_list(values_text: str) -> list[str]:
    values = []
    current = []
    depth = 0
    in_quote = False
    escape = False
    for ch in values_text:
        if escape:
            current.append(ch)
            escape = False
            continue
        if ch == "\\":
            current.append(ch)
            escape = True
            continue
        if ch == "'":
            current.append(ch)
            in_quote = not in_quote
            continue
        if not in_quote and ch == "(" :
            depth += 1
            current.append(ch)
            continue
        if not in_quote and ch == ")":
            depth -= 1
            current.append(ch)
            continue
        if not in_quote and depth == 0 and ch == ",":
            value = ''.join(current).strip()
            if value:
                values.append(value)
            current = []
            continue
        current.append(ch)
    if current:
        value = ''.join(current).strip()
        if value:
            values.append(value)
    return values


def parse_value(token: str):
    token = token.strip()
    if token.upper() == "NULL":
        return None
    cast_match = CAST_RE.match(token)
    if cast_match:
        return cast_match.group("inner")
    str_match = STRING_RE.match(token)
    if str_match:
        val = str_match.group("content").replace("''", "'")
        return val
    if token.startswith("N'") and token.endswith("'"):
        return token[2:-1].replace("''", "'")
    if token.startswith("'") and token.endswith("'"):
        return token[1:-1].replace("''", "'")
    if token.isdigit() or (token.startswith("-") and token[1:].isdigit()):
        return int(token)
    try:
        return float(token)
    except ValueError:
        return token


def collect_create_tables() -> dict[str, list[tuple[str, str, bool]]]:
    results = {}
    for sql_path in sorted(TABLE_DIR.glob("*.Table.sql")):
        text = read_text(sql_path)
        try:
            table_name, columns = parse_create_table(text)
        except ValueError:
            continue
        results[table_name] = columns
    for sql_path in sorted(POST_DEPLOY_DIR.glob("*.Table.sql")):
        if sql_path.name.startswith("dbo.LUT_PricerTypeAPRPro_"):
            continue
        text = read_text(sql_path)
        if "CREATE TABLE" not in text.upper():
            continue
        try:
            table_name, columns = parse_create_table(text)
        except ValueError:
            continue
        results.setdefault(table_name, columns)
    return results


def collect_inserts() -> dict[str, list[list]]:
    data: dict[str, list[list]] = {}
    
    for sql_path in sorted(POST_DEPLOY_DIR.glob("*.Table.sql")):
        text = read_text(sql_path)
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        
        # Find all lines starting with INSERT and collect full statements
        lines = text.splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if line.upper().startswith("INSERT"):
                # Collect the full INSERT statement
                stmt_lines = [line]
                # Keep collecting until we find a complete VALUES (...) 
                paren_depth = 0
                found_values = False
                j = i
                
                while j < len(lines):
                    current_line = lines[j].strip()
                    if j > i:
                        stmt_lines.append(current_line)
                    
                    # Count parentheses
                    for ch in current_line:
                        if ch == '(':
                            paren_depth += 1
                        elif ch == ')':
                            paren_depth -= 1
                    
                    # Check if we have VALUES and matching parens
                    if 'VALUES' in current_line.upper():
                        found_values = True
                    
                    if found_values and paren_depth == 0:
                        break
                    j += 1
                
                # Parse the complete statement
                stmt = " ".join(stmt_lines)
                match = re.search(r"INSERT\s+\[dbo\]\.\[([^\]]+)\].*?VALUES\s*\((.+?)\)\s*(?:GO)?$", stmt, re.IGNORECASE | re.DOTALL)
                if match:
                    table = match.group(1)
                    values_text = match.group(2)
                    values = split_value_list(values_text)
                    parsed = [parse_value(v) for v in values]
                    data.setdefault(table, []).append(parsed)
                
                i = j + 1
            else:
                i += 1
    
    return data


def build_sqlite():
    create_tables = collect_create_tables()
    inserts = collect_inserts()
    if SQLITE_PATH.exists():
        SQLITE_PATH.unlink()
    conn = sqlite3.connect(SQLITE_PATH)
    cur = conn.cursor()

    for table_name, columns in create_tables.items():
        cols = []
        for name, coltype, nullable in columns:
            cols.append(f"\"{name}\" {coltype}{' NOT NULL' if nullable else ''}")
        ddl = f"CREATE TABLE IF NOT EXISTS \"{table_name}\" ({', '.join(cols)});"
        cur.execute(ddl)

    for table, rows in inserts.items():
        if table not in create_tables:
            continue
        if not rows:
            continue
        columns = create_tables[table]
        placeholder = ", ".join("?" for _ in columns)
        insert_sql = f"INSERT INTO \"{table}\" VALUES ({placeholder})"
        for row in rows:
            if len(row) != len(columns):
                continue
            cur.execute(insert_sql, row)

    conn.commit()
    conn.close()
    print(f"SQLite database created at: {SQLITE_PATH}")


if __name__ == "__main__":
    build_sqlite()
