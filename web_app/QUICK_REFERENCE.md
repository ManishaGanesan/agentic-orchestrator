# Quick Reference - Excel to SQL Converter

## 🚀 Start Application

```powershell
# Recommended
.\web_app\start.ps1

# Alternative methods
python web_app/main.py
python -m uvicorn web_app.main:app --reload
```

## 🌐 URLs

| Purpose | URL |
|---------|-----|
| Web Interface | http://localhost:8000 |
| API Documentation | http://localhost:8000/docs |
| Alternative Docs | http://localhost:8000/redoc |
| Health Check | http://localhost:8000/health |

## 📡 API Endpoints

```
POST   /api/upload              Upload files
POST   /api/process/{job_id}    Process job
GET    /api/jobs                List all jobs
GET    /api/job/{job_id}        Get job details
GET    /api/download/{job_id}   Download results
DELETE /api/job/{job_id}        Delete job
```

## 📝 Common Commands

### Development
```powershell
# Start with auto-reload
python -m uvicorn web_app.main:app --reload

# Start on different port
python -m uvicorn web_app.main:app --port 8080

# Test API
python web_app/test_api.py
```

### Docker
```bash
# Build and run
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down

# Rebuild
docker-compose up -d --build
```

### Azure Deployment
```bash
# Deploy to Azure
az webapp up --name excel-to-sql --runtime "PYTHON:3.11"

# View logs
az webapp log tail --name excel-to-sql --resource-group <rg>

# Restart
az webapp restart --name excel-to-sql --resource-group <rg>
```

## 📁 File Locations

```
web_app/
├── main.py              # FastAPI app
├── static/index.html    # Web UI
├── uploads/             # Uploaded files
│   └── job_*/          # Job directories
└── outputs/             # Results
    └── *_output.json   # JSON outputs
```

## 🔧 Configuration

### Environment Variables (.env)
```env
DEBUG=True
HOST=0.0.0.0
PORT=8000
CLIENT_ID=your-id
CLIENT_SECRET=your-secret
```

### Config File (web_app/config.py)
- Upload directory
- Output directory
- Max file size
- Allowed extensions
- CORS settings

## 📊 Supported Files

| Type | Pattern | Description |
|------|---------|-------------|
| State Procedures | `*_StateProcedures.xlsx` | State data |
| Procedure Variables | `*_VariablesforProcedures.xlsx` | Variables |

## 🧪 Testing

```powershell
# Quick test
curl http://localhost:8000/health

# Full API test
python web_app/test_api.py

# Interactive docs
# Visit: http://localhost:8000/docs
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Port in use | Change port: `--port 8080` |
| Import error | `pip install -r requirements.txt` |
| File upload fails | Check format (.xlsx/.xlsm) |
| Module not found | Check virtual environment |

## 💡 Tips

1. **Always use virtual environment**
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```

2. **Check logs for errors**
   - Console output shows detailed errors
   - FastAPI provides helpful error messages

3. **Use API docs for testing**
   - http://localhost:8000/docs
   - Interactive testing interface

4. **File naming convention**
   - State: `*_StateProcedures.xlsx`
   - Variables: `*_VariablesforProcedures.xlsx`

5. **Version format**
   - Use format: `V2605.00`
   - Previous → New version

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| README.md | Complete guide |
| TESTING.md | Testing procedures |
| DEPLOYMENT.md | Deployment guide |
| ARCHITECTURE.md | System architecture |
| SUMMARY.md | Implementation summary |
| QUICK_REFERENCE.md | This file |

## 🆘 Quick Help

```powershell
# Check Python version
python --version

# Check installed packages
pip list

# Install dependencies
pip install -r requirements.txt

# Check if FastAPI works
python -c "import fastapi; print(fastapi.__version__)"

# Check if server is running
curl http://localhost:8000/health
```

## 📞 Status Checks

```powershell
# Application health
Invoke-RestMethod http://localhost:8000/health

# List jobs
Invoke-RestMethod http://localhost:8000/api/jobs

# Get specific job
Invoke-RestMethod http://localhost:8000/api/job/job_20240101_120000
```

## 🎯 Typical Workflow

1. **Start server**: `.\web_app\start.ps1`
2. **Open browser**: http://localhost:8000
3. **Upload files**: Select Excel file(s)
4. **Fill form**: Previous/New version
5. **Process**: Click "Upload & Process"
6. **Download**: Click "Download JSON"

## ⚡ Keyboard Shortcuts

When on http://localhost:8000:
- `Ctrl+R` - Refresh page
- `F5` - Reload
- `F12` - Open developer tools
- `Ctrl+Shift+I` - Inspect element

## 🔒 Security Checklist

For production:
- [ ] Enable HTTPS
- [ ] Add authentication
- [ ] Restrict CORS
- [ ] Enable rate limiting
- [ ] Use environment variables
- [ ] Scan uploaded files
- [ ] Set up monitoring
- [ ] Configure backups

## 📈 Performance Tips

- Use async operations
- Implement caching
- Clean old files regularly
- Monitor memory usage
- Set appropriate timeouts
- Use connection pooling

## 🎓 Learning Resources

- FastAPI: https://fastapi.tiangolo.com
- Uvicorn: https://www.uvicorn.org
- Python: https://docs.python.org
- Docker: https://docs.docker.com

---

**Keep this reference handy for quick lookups!**

*Last Updated: 2024*
