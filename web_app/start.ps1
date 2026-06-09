# FastAPI Web Application Startup Script
# Excel to SQL Converter

Write-Host "Starting Excel to SQL Converter Web Application..." -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment is activated
if (-not $env:VIRTUAL_ENV) {
    Write-Host "Virtual environment not detected. Activating..." -ForegroundColor Yellow

    if (Test-Path ".venv\Scripts\Activate.ps1") {
        & .\.venv\Scripts\Activate.ps1
        Write-Host "Virtual environment activated." -ForegroundColor Green
    } else {
        Write-Host "Virtual environment not found. Please create it first:" -ForegroundColor Red
        Write-Host "  py -3 -m venv .venv" -ForegroundColor Yellow
        Write-Host "  .\.venv\Scripts\Activate.ps1" -ForegroundColor Yellow
        Write-Host "  python -m pip install -r requirements.txt" -ForegroundColor Yellow
        exit 1
    }
}

# Check if dependencies are installed
Write-Host "Checking dependencies..." -ForegroundColor Cyan
$fastapi = python -c "import fastapi; print('ok')" 2>$null

if ($fastapi -ne "ok") {
    Write-Host "FastAPI not found. Installing dependencies..." -ForegroundColor Yellow
    python -m pip install -r requirements.txt

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install dependencies." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Dependencies checked." -ForegroundColor Green
Write-Host ""

# Create necessary directories
Write-Host "Creating application directories..." -ForegroundColor Cyan
if (-not (Test-Path "web_app\uploads")) {
    New-Item -ItemType Directory -Path "web_app\uploads" -Force | Out-Null
}
if (-not (Test-Path "web_app\outputs")) {
    New-Item -ItemType Directory -Path "web_app\outputs" -Force | Out-Null
}
Write-Host "Directories ready." -ForegroundColor Green
Write-Host ""

# Display startup information
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Excel to SQL Converter - Web Application" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Web Interface:  " -NoNewline; Write-Host "http://localhost:8000" -ForegroundColor Green
Write-Host "  API Docs:       " -NoNewline; Write-Host "http://localhost:8000/docs" -ForegroundColor Green
Write-Host "  Health Check:   " -NoNewline; Write-Host "http://localhost:8000/health" -ForegroundColor Green
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

# Start the application
python -m uvicorn web_app.main:app --reload --host 0.0.0.0 --port 8000
