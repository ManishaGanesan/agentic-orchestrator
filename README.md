This repo has 3 major components:

1. Dataset Builder
   - Converts regulatory Excel → structured JSON

2. Agentic Orchestrator
   - Generates SQL
   - Validates rules
   - Produces audit logs
   - Prepares PR artifacts

3. Web Application (NEW!)
   - FastAPI-based web interface
   - Upload Excel files via browser
   - Process and download results
   - Job management and tracking

## Run steps (Command Line)
Use the Windows Python launcher py to build a venv
1. create venv using the system Python (py chooses an installed Python 3)
    - py -3 -m venv .venv
    - python3 -m venv venv (mac)
2. activate
    - .\.venv\Scripts\Activate.ps1
    - source venv/bin/activate (macos)
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

## Web Application run
1. **Trigger ps in venv**: .\web_app\start.ps1
2. **Open in browser**: http://localhost:8000
3. **Upload and process**:
   - Enter previous/new versions
   - Select Excel file(s)
   - Click "Upload & Process"
   - Verify Output.json file under input_excels folder
📚 See [web_app/README.md](web_app/README.md) for detailed documentation.