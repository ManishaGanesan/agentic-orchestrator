# Testing Guide for Excel to SQL Converter Web Application

## Prerequisites

Before testing, ensure you have:
1. Python 3.8 or higher installed
2. Virtual environment activated
3. All dependencies installed from `requirements.txt`

## Installation Check

```powershell
# Verify Python installation
python --version

# Should show Python 3.8 or higher
```

## Setup for Testing

```powershell
# 1. Create and activate virtual environment
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1

# 2. Install dependencies
python -m pip install -r requirements.txt

# 3. Verify FastAPI installation
python -c "import fastapi; print('FastAPI version:', fastapi.__version__)"
```

## Running the Application

### Method 1: Using the startup script
```powershell
.\web_app\start.ps1
```

### Method 2: Direct command
```powershell
python -m uvicorn web_app.main:app --reload --host 0.0.0.0 --port 8000
```

### Method 3: Using the main.py directly
```powershell
python web_app/main.py
```

## Testing Endpoints

### 1. Health Check
```powershell
# Using curl (if available)
curl http://localhost:8000/health

# Using PowerShell
Invoke-RestMethod -Uri http://localhost:8000/health -Method Get
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T12:00:00",
  "service": "excel-to-sql-converter"
}
```

### 2. Web Interface
Open browser and navigate to:
- http://localhost:8000

You should see the Excel to SQL Converter interface.

### 3. API Documentation
Open browser and navigate to:
- http://localhost:8000/docs (Swagger UI)
- http://localhost:8000/redoc (ReDoc)

### 4. File Upload Test

Using PowerShell:
```powershell
# Prepare test data
$boundary = [System.Guid]::NewGuid().ToString()
$filePath = "path\to\your\test.xlsx"

# Create multipart form data (example)
# Or use the web interface at http://localhost:8000
```

Or simply use the web interface:
1. Go to http://localhost:8000
2. Fill in:
   - Previous Version: `V2605.00`
   - New Version: `V2606.00`
   - Story ID: `US1234567` (optional)
3. Select an Excel file from your `dataset_builder/data/business_excels/` folder
4. Click "Upload & Process"

### 5. List Jobs
```powershell
Invoke-RestMethod -Uri http://localhost:8000/api/jobs -Method Get
```

## Manual Testing Checklist

- [ ] Application starts without errors
- [ ] Web interface loads at http://localhost:8000
- [ ] API docs accessible at /docs
- [ ] Health check returns 200 OK
- [ ] File upload works with .xlsx files
- [ ] File upload works with .xlsm files
- [ ] Invalid file types are rejected
- [ ] Processing completes successfully
- [ ] Jobs are listed correctly
- [ ] Processed jobs show correct status
- [ ] Download JSON works
- [ ] Delete job works
- [ ] Version fields are validated
- [ ] Multiple file upload works

## Test Data

Use existing test files from:
- `dataset_builder/data/business_excels/` - For regular business Excel files
- `dataset_builder/data/state_Data_Excels/` - For state procedure files

Example test files:
1. `US1532131_V2601.01 - default value and description updates Medicare_ASC.xlsx`
2. `V2403.00 - add one new procedure, new procedure array for Medicaid APG Pro (Illinois)_StateProcedures.xlsx`

## Expected Outputs

After processing, you should see:
1. A job entry in the job list with:
   - Job ID (timestamp-based)
   - Status badge (Processed/Pending)
   - Version information
   - File count

2. Download should provide a JSON file with structure:
```json
{
  "state_procedures": [...],
  "procedure_variables": [...]
}
```

## Troubleshooting

### Port Already in Use
```powershell
# Change port
python -m uvicorn web_app.main:app --reload --port 8080
```

### Module Import Errors
```powershell
# Ensure you're in the project root
cd path\to\pps-rm-agentic-orchestrator

# Reinstall dependencies
python -m pip install -r requirements.txt --force-reinstall
```

### File Upload Fails
- Check file format (.xlsx or .xlsm)
- Check file size (max 100MB by default)
- Ensure `web_app/uploads/` directory exists
- Check disk space

### Processing Errors
- Verify Excel file format matches expected structure
- Check console/logs for detailed error messages
- Ensure InputProcessor can read the file

## Performance Testing

### Load Testing (Optional)
```powershell
# Install locust
pip install locust

# Run load test (if you create a locustfile.py)
locust -f tests/locustfile.py --host=http://localhost:8000
```

## Cleanup After Testing

```powershell
# Remove test uploads and outputs
Remove-Item -Recurse -Force web_app/uploads/*
Remove-Item -Recurse -Force web_app/outputs/*
```

## CI/CD Integration (Future)

For automated testing:
```yaml
# Example GitHub Actions workflow
- name: Test Web Application
  run: |
    pip install -r requirements.txt
    pytest tests/test_web_app.py
```

## Next Steps

After successful testing:
1. ✅ Deploy to development environment
2. ✅ Configure environment variables
3. ✅ Set up monitoring and logging
4. ✅ Deploy to production
5. ✅ Set up automated backups

## Support

If you encounter issues:
1. Check the console output for errors
2. Review the web_app/README.md
3. Check FastAPI documentation: https://fastapi.tiangolo.com/
4. Review the code in web_app/main.py
