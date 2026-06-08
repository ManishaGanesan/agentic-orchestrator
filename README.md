This repo has 2 major components:

1. Dataset Builder
   - Converts regulatory Excel → structured JSON

2. Agentic Orchestrator
   - Generates SQL
   - Validates rules
   - Produces audit logs
   - Prepares PR artifacts

## Run steps 
Use the Windows Python launcher py to build a venv
1. create venv using the system Python (py chooses an installed Python 3)
    - py -3 -m venv .venv
2. activate
    - .\.venv\Scripts\Activate.ps1
3. Install dependencies - within the virtual env
    - python -m pip install -r requirements.txt
    - The -m enforces install within the selected virtual env
4. Press Ctrl+Shift+P and select the correct venv version interpreter
5. Make a copy of env.template file, rename to .env & update client id,secret & project id

## Canonical file run
1. Run the simple canonical build (auto-discovers business excels)

    python .\build_canonical_simple.py `
        --master ".\data\master\master.xlsx" `
        --sql-root ".\data\sql" `
        --out ".\out\canonical_simple.json"

    - This script automatically scans all Excel files under .\data\business_excels and matches them to master rows by title.
    - Only SQL blocks for those stories are included in the output.
## Orchestrator run
1. python orchestrator/main.py
