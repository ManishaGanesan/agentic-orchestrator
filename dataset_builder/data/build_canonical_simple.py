KNOWN_PRICER_TYPES = [
    "Medicare APC", "Medicare DRG", "Medicare ESRD", "Medicare FQHC", "Medicare HHA",
    "Medicare Hospice", "Medicare IPF", "Medicare IRF", "TRICARE CHAMPUS", "Medicare ASC",
    "Contract APC", "Medicare Physician", "Medicare RHC", "Medicare SNF", "Oklahoma APC",
    "Enhanced New York Medicaid APG", "New Mexico Medicaid", "Washington Medicaid APR",
    "New York Psych Exempt", "New York Medicaid APR-DRG", "New York Medicaid APG"
]

def extract_pricer_type_from_filename(filename):
    fname = filename.replace("_", " ").lower()
    for pt in KNOWN_PRICER_TYPES:
        if pt.lower() in fname:
            return pt
    return ""
#!/usr/bin/env python3
"""build_canonical_simple.py

Outputs a SIMPLE JSON per story:
  - story_id
  - title
  - release_version
  - modified_tables (with operations: insert/update/delete/alter)
  - story_type (new field add / update / insert / delete / mixed)
  - fields_added
  - fields_modified

Assumptions (based on your release scripts):
  - SQL contains comment markers like: --US1591186: V2605.00 - ...
  - The statements for that story follow the marker until next US marker or end-of-file.

Usage:
  python build_canonical_simple.py --master <master.xlsx> --sql-root <sql_folder> --out canonical_simple.json

Note:
  - No dataset prep required; uses your existing folder structure.
"""

import argparse
import json
import os
import re
from typing import Dict, List, Any, Optional

import pandas as pd

US_MARKER = re.compile(r"(?im)^\s*--\s*(US\d{5,})\s*:\s*(V\d+(?:[._]\d+)*)\s*-\s*(.*)$")

# SQL statement regexes (lightweight but robust enough)
RX_UPDATE = re.compile(r"(?is)\bUPDATE\s+(?P<table>(?:\[[^\]]+\]|\w+)(?:\s*\.\s*(?:\[[^\]]+\]|\w+))?)\s+SET\s+(?P<set>.*?)(?:\bWHERE\b|;|\bFROM\b)")
RX_INSERT = re.compile(r"(?is)\bINSERT\s+INTO\s+(?P<table>(?:\[[^\]]+\]|\w+)(?:\s*\.\s*(?:\[[^\]]+\]|\w+))?)\s*\((?P<cols>[^\)]{1,2000})\)")
RX_DELETE = re.compile(r"(?is)\bDELETE\s+FROM\s+(?P<table>(?:\[[^\]]+\]|\w+)(?:\s*\.\s*(?:\[[^\]]+\]|\w+))?)\b")
RX_ALTER_ADD = re.compile(r"(?is)\bALTER\s+TABLE\s+(?P<table>(?:\[[^\]]+\]|\w+)(?:\s*\.\s*(?:\[[^\]]+\]|\w+))?)\s+ADD\s+(?P<cols>[^;]{1,2000})")


def norm_ident(s: str) -> str:
    if not s:
        return ''
    return re.sub(r"\s+", " ", s.replace('[','').replace(']','').strip())


def split_set_columns(set_clause: str) -> List[str]:
    """Extract column names from SET clause; handles commas and simple expressions."""
    if not set_clause:
        return []
    # remove newlines
    s = set_clause.replace('\n', ' ')
    # split by commas not inside parentheses (simple)
    parts = re.split(r",(?![^()]*\))", s)
    cols = []
    for p in parts:
        m = re.match(r"\s*(\[[^\]]+\]|\w+)\s*=", p.strip(), flags=re.IGNORECASE)
        if m:
            cols.append(norm_ident(m.group(1)))
    return sorted(set(cols))


def split_insert_columns(cols_text: str) -> List[str]:
    if not cols_text:
        return []
    cols = [norm_ident(c) for c in cols_text.split(',')]
    cols = [c for c in cols if c]
    return sorted(set(cols))


def split_alter_add_columns(cols_text: str) -> List[str]:
    if not cols_text:
        return []
    # capture identifiers at start of each column definition
    # e.g., ADD [NewCol] int NULL, OtherCol varchar(10)
    defs = re.split(r",(?![^()]*\))", cols_text.replace('\n',' '))
    cols = []
    for d in defs:
        m = re.match(r"\s*(\[[^\]]+\]|\w+)", d.strip())
        if m:
            cols.append(norm_ident(m.group(1)))
    return sorted(set(cols))


def extract_story_blocks(sql_text: str) -> List[Dict[str, Any]]:
    """Return list of {story_id, release, title, block_text}."""
    markers = list(US_MARKER.finditer(sql_text))
    blocks = []
    for i, m in enumerate(markers):
        start = m.start()
        end = markers[i+1].start() if i+1 < len(markers) else len(sql_text)
        blocks.append({
            'story_id': m.group(1).upper(),
            'release_version': m.group(2).upper(),
            'title': m.group(3).strip(),
            'block_text': sql_text[start:end]
        })
    return blocks



def parse_block(block_text: str) -> Dict[str, Any]:
    text = block_text

    # Helper: parse a piece of SQL text and return parsed info (tables, fields, ops)
    def _parse_section(sec_text: str) -> Dict[str, Any]:
        modified_tables = {}  # table -> set(ops)
        fields_modified = set()
        fields_added = set()

        for m in RX_UPDATE.finditer(sec_text):
            table = norm_ident(m.group('table'))
            modified_tables.setdefault(table, set()).add('update')
            for c in split_set_columns(m.group('set')):
                fields_modified.add(c)

        for m in RX_INSERT.finditer(sec_text):
            table = norm_ident(m.group('table'))
            modified_tables.setdefault(table, set()).add('insert')
            for c in split_insert_columns(m.group('cols')):
                fields_added.add(c)

        for m in RX_DELETE.finditer(sec_text):
            table = norm_ident(m.group('table'))
            modified_tables.setdefault(table, set()).add('delete')

        for m in RX_ALTER_ADD.finditer(sec_text):
            table = norm_ident(m.group('table'))
            modified_tables.setdefault(table, set()).add('alter_add')
            for c in split_alter_add_columns(m.group('cols')):
                fields_added.add(c)

        ops_all = set().union(*modified_tables.values()) if modified_tables else set()
        if 'alter_add' in ops_all:
            story_type = 'new field add'
        elif ops_all == {'update'}:
            story_type = 'update'
        elif ops_all == {'insert'}:
            story_type = 'insert'
        elif ops_all == {'delete'}:
            story_type = 'delete'
        elif ops_all:
            story_type = 'mixed'
        else:
            story_type = 'unknown'

        mt_out = []
        for t, ops in sorted(modified_tables.items()):
            mt_out.append({
                'table': t,
                'operations': sorted(ops)
            })

        return {
            'modified_tables': mt_out,
            'story_type': story_type,
            'fields_added': sorted(fields_added),
            'fields_modified': sorted(fields_modified)
        }

    # First, try to split the block into comment-labeled sections. Many scripts use
    # comment lines like "-- Medicare HHA" or "-- Medicare ASC" to indicate that
    # the following statements apply to that pricer type until the next such comment.
    sections = []  # list of (pricertype_or_None, section_text)
    current_pt = None
    buf = []
    for line in text.splitlines():
        cm = re.match(r"^\s*--\s*(.+)$", line)
        if cm:
            label = cm.group(1).strip()
            # detect if label contains any known pricer type
            found = None
            for pt in KNOWN_PRICER_TYPES:
                if pt.lower() in label.lower():
                    found = pt
                    break
            if found:
                # flush previous buffer
                if buf:
                    sections.append((current_pt, "\n".join(buf)))
                    buf = []
                current_pt = found
                # don't include the comment line in the buffer
                continue
        buf.append(line)

    if buf:
        sections.append((current_pt, "\n".join(buf)))

    # Parse each section independently to collect fields/tables per pricer type
    per_pricertype: Dict[Optional[str], Dict[str, Any]] = {}
    for pt, sec_text in sections:
        sec_parsed = _parse_section(sec_text)
        # Merge if multiple sections for the same pricer type
        if pt not in per_pricertype:
            per_pricertype[pt] = sec_parsed
        else:
            # merge tables
            existing = per_pricertype[pt]
            # merge modified_tables by table name
            tbl_map = {t['table']: set(t['operations']) for t in existing.get('modified_tables', [])}
            for t in sec_parsed.get('modified_tables', []):
                tbl_map.setdefault(t['table'], set()).update(t['operations'])
            existing['modified_tables'] = [{'table': k, 'operations': sorted(v)} for k, v in sorted(tbl_map.items())]
            # merge fields
            existing['fields_added'] = sorted(set(existing.get('fields_added', [])) | set(sec_parsed.get('fields_added', [])))
            existing['fields_modified'] = sorted(set(existing.get('fields_modified', [])) | set(sec_parsed.get('fields_modified', [])))
            # recompute story_type conservatively
            ops_all = set().union(*[set(t['operations']) for t in existing.get('modified_tables', [])]) if existing.get('modified_tables') else set()
            if 'alter_add' in ops_all:
                existing['story_type'] = 'new field add'
            elif ops_all == {'update'}:
                existing['story_type'] = 'update'
            elif ops_all == {'insert'}:
                existing['story_type'] = 'insert'
            elif ops_all == {'delete'}:
                existing['story_type'] = 'delete'
            elif ops_all:
                existing['story_type'] = 'mixed'
            else:
                existing['story_type'] = 'unknown'

    # Also keep the original whole-block parsing for backward compatibility
    whole_parsed = _parse_section(text)

    # Extract explicit pricertypes from constructs like pricertype = 'X' or IN (...)
    explicit_pricertypes = set()
    for m in re.finditer(r"pricertype\s*=\s*['\"]([^'\"]+)['\"]", text, flags=re.IGNORECASE):
        explicit_pricertypes.add(m.group(1))
    for m in re.finditer(r"pricertype\s+IN\s*\(([^)]+)\)", text, flags=re.IGNORECASE):
        vals = re.findall(r"['\"]([^'\"]+)['\"]", m.group(1))
        explicit_pricertypes.update(vals)

    return {
        'modified_tables': whole_parsed['modified_tables'],
        'story_type': whole_parsed['story_type'],
        'fields_added': whole_parsed['fields_added'],
        'fields_modified': whole_parsed['fields_modified'],
        'pricertypes': sorted(explicit_pricertypes) if explicit_pricertypes else None,
        'per_pricertype': per_pricertype
    }


def load_master(master_path: str) -> Dict[str, Dict[str, str]]:
    df = pd.read_excel(master_path, engine='openpyxl')

    # Find title and description columns (tolerant)
    def find_col(cols, patterns):
        for p in patterns:
            for c in cols:
                if re.search(p, str(c), flags=re.IGNORECASE):
                    return c
        return None

    col_title = find_col(df.columns, [r"\btitle\b", r"\bname\b"])
    col_desc = find_col(df.columns, [r"\bdescription\b", r"\bdesc\b", r"details"])

    # Build mapping keyed by normalized title text -> info
    mapping = {}
    for _, r in df.iterrows():
        title = str(r.get(col_title, '')).strip() if col_title is not None else ''
        desc = str(r.get(col_desc, '')).strip() if col_desc is not None else ''
        # try to extract story id from title text
        m = re.search(r"\b(US\d{5,})\b", title, flags=re.IGNORECASE)
        story_id = m.group(1).upper() if m else ''
        if title:
            mapping[title] = {'story_id': story_id, 'title': title, 'description': desc}
    return mapping


def find_master_entry_for_business(basename: str, master_map: Dict[str, Dict[str, str]]) -> Optional[Dict[str, str]]:
    """Try to find a master row for a business Excel basename.
    Matching strategy (in order):
      - exact match of basename == title
      - case-insensitive exact
      - title contains basename
      - basename contains title
    """
    if not basename:
        return None
    # exact match
    if basename in master_map:
        return master_map[basename]

    # case-insensitive exact
    lower = {k.lower(): v for k, v in master_map.items()}
    if basename.lower() in lower:
        return lower[basename.lower()]

    # containment matches
    for k, v in master_map.items():
        if basename.lower() in k.lower() or k.lower() in basename.lower():
            return v

    return None


def find_sql_files(sql_root: str) -> List[str]:
    out = []
    for root, _, files in os.walk(sql_root):
        for fn in files:
            if fn.lower().endswith('.sql'):
                out.append(os.path.join(root, fn))
    return sorted(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--master', required=True)
    ap.add_argument('--sql-root', required=True)
    ap.add_argument('--out', required=True)
    args = ap.parse_args()
    master_map = load_master(args.master)

    # Discover business excels under data/business_excels (recursively)
    business_root = os.path.join(os.path.dirname(os.path.abspath(args.master)), '..', 'business_excels')
    business_root = os.path.normpath(business_root)
    business_files = []
    # If a --business arg behavior is desired, we could accept it; for now use data folder discovery
    if os.path.isdir(business_root):
        for root, _, files in os.walk(business_root):
            for fn in files:
                if fn.lower().endswith(('.xlsx', '.xlsm', '.xls')):
                    business_files.append(os.path.join(root, fn))


    desired_story_ids = set()
    storyid_to_master = {}
    unmatched_business = []

    # Extract user story number and pricer type from business Excel filename
    story_id_pattern = re.compile(r"US\d{5,}", re.IGNORECASE)
    pricer_type_pattern = re.compile(r"([A-Z][A-Z0-9_ ]{2,})[_ ]+US\d{5,}", re.IGNORECASE)
    for bf in business_files:
        base = os.path.splitext(os.path.basename(bf))[0]
        m = story_id_pattern.search(base)
        if m:
            sid = m.group(0).upper()
            pricer_type = extract_pricer_type_from_filename(base)
            print(f"[DEBUG] Business Excel: {os.path.basename(bf)} | Story ID: {sid} | Pricer Type: {pricer_type}")
            desired_story_ids.add(sid)
            master_entry = None
            for v in master_map.values():
                if v.get('story_id', '').upper() == sid:
                    master_entry = v
                    break
            if master_entry:
                storyid_to_master[sid] = {**master_entry, 'pricer_type': pricer_type}
            else:
                storyid_to_master[sid] = {'story_id': sid, 'title': base, 'description': '', 'pricer_type': pricer_type}
        else:
            unmatched_business.append(bf)

    if unmatched_business:
        print(f"Warning: {len(unmatched_business)} business files did not contain a user story number. Examples:")
        for ub in unmatched_business[:5]:
            print(" - ", ub)


        # Extract user story number and pricer type from business Excel filename
        story_id_pattern = re.compile(r"US\d{5,}", re.IGNORECASE)
        # Pricer type pattern: look for known types or use the part after the user story in the filename
        # Example: "V2601.01 - default value and description updates Medicare_APC_US1524244.xlsx"
        # We'll extract the last all-caps word(s) before the user story number
        pricer_type_pattern = re.compile(r"([A-Z][A-Z0-9_ ]{2,})[_ ]+US\d{5,}", re.IGNORECASE)

        for bf in business_files:
            base = os.path.splitext(os.path.basename(bf))[0]
            m = story_id_pattern.search(base)
            if m:
                sid = m.group(0).upper()
                # Try to extract pricer type from filename
                pt_match = pricer_type_pattern.search(base)
                if pt_match:
                    pricer_type = pt_match.group(1).strip().replace('_', ' ')
                else:
                    # fallback: take last word before US
                    parts = re.split(r"US\d{5,}", base, flags=re.IGNORECASE)
                    pricer_type = parts[0].split()[-1] if len(parts) > 1 and parts[0].split() else ''
                desired_story_ids.add(sid)
                # Try to find master info for this story id
                master_entry = None
                for v in master_map.values():
                    if v.get('story_id', '').upper() == sid:
                        master_entry = v
                        break
                if master_entry:
                    storyid_to_master[sid] = {**master_entry, 'pricer_type': pricer_type}
                else:
                    storyid_to_master[sid] = {'story_id': sid, 'title': base, 'description': '', 'pricer_type': pricer_type}
            else:
                unmatched_business.append(bf)

    stories_out = []
    sql_files = find_sql_files(args.sql_root)

    # For each desired story_id (from business excels/master), find all SQL files whose filename contains that story_id
    for story_id in desired_story_ids:
        master_info = storyid_to_master.get(story_id, {})
        candidate_sql_files = [fp for fp in sql_files if story_id.lower() in os.path.basename(fp).lower()]
        for fp in candidate_sql_files:
            sql_text = open(fp, 'r', encoding='utf-8', errors='ignore').read()
            for b in extract_story_blocks(sql_text):
                if b['story_id'] != story_id:
                    continue
                parsed = parse_block(b['block_text'])
                pricertypes = parsed.get('pricertypes')
                print(f"[DEBUG] SQL File: {os.path.basename(fp)} | Story ID: {story_id} | SQL Block Title: {b['title']} | Pricer Types Found: {pricertypes}")
                excel_pricer_type = master_info.get('pricer_type')

                # If parse_block detected per_pricertype sections, prefer them: create
                # one story entry per labeled section. If there are unlabeled sections
                # (None key), treat them as general (use excel_pricer_type if available).
                per_pt = parsed.get('per_pricertype') or {}
                if per_pt:
                    for pt, sec in per_pt.items():
                        # determine the pricertype label to put in the output
                        out_pt = pt or excel_pricer_type
                        stories_out.append({
                            'story_id': story_id,
                            'title': master_info.get('title') or f"{story_id}: {b['release_version']} - {b['title']}",
                            'release_version': b['release_version'],
                            'story_summary_title': b['title'],
                            'description': master_info.get('description',''),
                            'modified_tables': sec.get('modified_tables', []),
                            'modification_types': sorted({op for t in sec.get('modified_tables', []) for op in t['operations']}),
                            'story_type': sec.get('story_type'),
                            'fields_added': sec.get('fields_added', []),
                            'fields_modified': sec.get('fields_modified', []),
                            'pricertype': out_pt,
                            'source_sql_file': os.path.basename(fp)
                        })
                else:
                    used_pricertypes = pricertypes or ([excel_pricer_type] if excel_pricer_type else [None])
                    for pt in used_pricertypes:
                        stories_out.append({
                            'story_id': story_id,
                            'title': master_info.get('title') or f"{story_id}: {b['release_version']} - {b['title']}",
                            'release_version': b['release_version'],
                            'story_summary_title': b['title'],
                            'description': master_info.get('description',''),
                            'modified_tables': parsed['modified_tables'],
                            'modification_types': sorted({op for t in parsed['modified_tables'] for op in t['operations']}),
                            'story_type': parsed['story_type'],
                            'fields_added': parsed['fields_added'],
                            'fields_modified': parsed['fields_modified'],
                            'pricertype': pt,
                            'source_sql_file': os.path.basename(fp)
                        })

    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump({'schema_version':'simple-1.0','stories':stories_out}, f, indent=2)

    print(f"Wrote {args.out} with {len(stories_out)} story entries")


if __name__ == '__main__':
    main()
