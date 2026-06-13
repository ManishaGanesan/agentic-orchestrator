# Excel to SQL Converter - Web Application

A lightweight FastAPI web application that provides a user-friendly interface for converting Excel files to SQL scripts using AI agents.

## Features

- 📤 **File Upload**: Upload multiple Excel files (.xlsx, .xlsm)
- 📝 **Version Management**: Specify previous and new versions
- 🔄 **Automatic Processing**: Converts Excel data to structured JSON
- 📊 **Job Management**: Track all processing jobs with status
- ⬇️ **Download Results**: Download processed JSON files
- 🎨 **Clean UI**: Modern, responsive interface
- 🚀 **Fast & Lightweight**: Built with FastAPI for performance

## Prerequisites

- **Python 3.11+** installed and on your PATH (verify with `python --version`)
- **Git** to clone the repository
- A terminal (PowerShell on Windows, bash/zsh on macOS/Linux)

## Installation

> Run all commands from the **project root** (`pps-rm-agentic-orchestrator`), not from the `web_app` folder. The app uses paths relative to the project root.

1. **Clone the repository** (skip if you already have it):
```bash
git clone <repository-url>
cd pps-rm-agentic-orchestrator
```

2. **Create and activate a virtual environment**:

```powershell
# Windows (PowerShell)
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
```
```bash
# macOS / Linux
python3 -m venv .venv
source .venv/bin/activate
```
> If PowerShell blocks activation with a "running scripts is disabled" error, run once:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

Once activated, your prompt shows `(.venv)`.

3. **Install dependencies**:
```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

4. **Configure environment variables**:

> Note: `.env.template` and `.env` live in the **project root**, one level *above* `web_app/` — not inside the `web_app/` folder. The app reads the root `.env` at startup (see [config.py](config.py)), so it must be created there.

Copy the template to a `.env` file in the project root and fill in your values:
```powershell
# Windows (PowerShell)
Copy-Item .env.template .env
```
```bash
# macOS / Linux
cp .env.template .env
```

The `.env` file holds credentials and configuration. Required and optional values:

| Variable | Required | Description |
|----------|----------|-------------|
| `CLIENT_ID` | Yes | OAuth client ID |
| `CLIENT_SECRET` | Yes | OAuth client secret |
| `PROJECT_ID` | Optional | Project identifier for the AI gateway |
| `AZURE_ENDPOINT` | Optional | AI gateway base URL |
| `DEPLOYMENT_NAME` | Optional | Model deployment name (e.g. `gpt-4.1_2025-04-14`) |
| `API_VERSION` | Optional | API version string |

> Never commit your `.env` file — it contains secrets. The basic upload/convert workflow runs without credentials; they are only needed for AI-assisted SQL generation.

## Running the Application

### Option 1: Direct Python
```bash
python web_app/main.py
```

### Option 2: Using Uvicorn
```bash
uvicorn web_app.main:app --reload --host 0.0.0.0 --port 8000
```

### Option 3: Using the startup script
```bash
# Windows PowerShell
.\web_app\start.ps1

# Or run from Python
python -m uvicorn web_app.main:app --reload
```

The application will be available at:
- **Web Interface**: http://localhost:8000
- **API Documentation**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc

## API Endpoints

### Web Interface
- `GET /` - Main web interface

### Health Check
- `GET /health` - Health check endpoint

### File Operations
- `POST /api/upload` - Upload Excel files with version info
- `POST /api/process/{job_id}` - Process uploaded files
- `GET /api/download/{job_id}` - Download processed JSON

### Job Management
- `GET /api/jobs` - List all jobs
- `GET /api/job/{job_id}` - Get specific job details
- `DELETE /api/job/{job_id}` - Delete a job

## Usage

1. **Open the web interface** at http://localhost:8000

2. **Fill in the form**:
   - Previous Version (required): e.g., `V2605.00`
   - New Version (required): e.g., `V2606.00`
   - Story ID (optional): e.g., `US1234567`
   - Select Excel file(s)

3. **Upload & Process**:
   - Click "Upload & Process" button
   - Wait for processing to complete
   - View results in the job list

4. **Download Results**:
   - Click "Download JSON" on any processed job
   - Get the structured output file

## File Structure

```
web_app/
├── main.py              # FastAPI application
├── static/
│   └── index.html       # Web interface
├── uploads/             # Uploaded files (auto-created)
│   └── job_*/          # Individual job directories
└── outputs/             # Processed outputs (auto-created)
    └── *_output.json   # Result files
```

## Supported Excel Files

The application processes two types of Excel files:

1. **State Procedures**: `*_StateProcedures.xlsx` or `.xlsm`
2. **Variables for Procedures**: `*_VariablesforProcedures.xlsx` or `.xlsm`

## Output Format

The processed output is a JSON file containing:

```json
{
  "state_procedures": [
    {
      "state_name": "...",
      "state_id": "...",
      "effective_date": "...",
      "action": "ADD/UPDATE",
      "procedures": [...],
      "source_file": "..."
    }
  ],
  "procedure_variables": [
    {
      "action": "ADD/UPDATE",
      "pdescription": {...},
      "pcode": {...},
      "variables": [...],
      "source_file": "..."
    }
  ]
}
```

## Configuration

The application uses the following directories:
- **Upload Directory**: `web_app/uploads/` - Stores uploaded files
- **Output Directory**: `web_app/outputs/` - Stores processed results

Both directories are created automatically on startup.

## Development

### Run in Development Mode
```bash
uvicorn web_app.main:app --reload --host 0.0.0.0 --port 8000
```

### Access API Documentation
FastAPI provides automatic interactive API documentation:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Deployment

### Azure App Service (Recommended)

1. **Create App Service**:
```bash
az webapp up --name excel-to-sql-converter --runtime "PYTHON:3.11"
```

2. **Configure startup command** in Azure Portal:
```
uvicorn web_app.main:app --host 0.0.0.0 --port 8000
```

3. **Set environment variables** in Configuration settings if needed

### Docker (Alternative)

A Dockerfile will be provided if needed for containerized deployment.

## Troubleshooting

### Port already in use
```bash
# Change port in command
uvicorn web_app.main:app --reload --port 8080
```

### Import errors
```bash
# Ensure you're in the project root directory
# And dependencies are installed
pip install -r requirements.txt
```

### "ModuleNotFoundError" or wrong Python being used
- Make sure the virtual environment is activated (your prompt should show `(.venv)`).
- Reinstall dependencies after activating: `python -m pip install -r requirements.txt`.

### PowerShell: "running scripts is disabled on this system"
Activation is blocked by the execution policy. Run once, then re-activate:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### File upload fails
- Check file format (.xlsx or .xlsm only)
- Ensure sufficient disk space
- Check upload directory permissions

## Next Steps

To extend this application:
1. Add SQL script generation from processed JSON
2. Integrate with OpenAI API for enhanced processing
3. Add user authentication
4. Implement database storage for job history
5. Add email notifications for completed jobs

## Support

For issues or questions, please refer to the main repository documentation.
