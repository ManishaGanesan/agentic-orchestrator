# Deployment Guide - Excel to SQL Converter

This guide covers different deployment options for the Excel to SQL Converter web application.

## Table of Contents
1. [Local Development](#local-development)
2. [Docker Deployment](#docker-deployment)
3. [Azure App Service](#azure-app-service)
4. [Azure Container Instances](#azure-container-instances)
5. [Production Considerations](#production-considerations)

---

## Local Development

### Prerequisites
- Python 3.8+
- pip
- Virtual environment

### Steps

1. **Setup environment**:
```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

2. **Run the application**:
```powershell
.\web_app\start.ps1
# OR
python -m uvicorn web_app.main:app --reload --host 0.0.0.0 --port 8000
```

3. **Access**:
- Web UI: http://localhost:8000
- API Docs: http://localhost:8000/docs

---

## Docker Deployment

### Prerequisites
- Docker installed
- Docker Compose (optional)

### Option 1: Docker Build & Run

1. **Build the image**:
```bash
docker build -t excel-to-sql-converter .
```

2. **Run the container**:
```bash
docker run -d \
  --name excel-to-sql \
  -p 8000:8000 \
  -v $(pwd)/web_app/uploads:/app/web_app/uploads \
  -v $(pwd)/web_app/outputs:/app/web_app/outputs \
  excel-to-sql-converter
```

3. **Access**: http://localhost:8000

### Option 2: Docker Compose

1. **Start services**:
```bash
docker-compose up -d
```

2. **View logs**:
```bash
docker-compose logs -f
```

3. **Stop services**:
```bash
docker-compose down
```

### Docker Commands

```bash
# View running containers
docker ps

# View logs
docker logs excel-to-sql

# Stop container
docker stop excel-to-sql

# Remove container
docker rm excel-to-sql

# Remove image
docker rmi excel-to-sql-converter
```

---

## Azure App Service

### Prerequisites
- Azure CLI installed
- Azure account with active subscription

### Steps

1. **Login to Azure**:
```bash
az login
```

2. **Create Resource Group**:
```bash
az group create \
  --name rg-excel-to-sql \
  --location eastus
```

3. **Create App Service Plan**:
```bash
az appservice plan create \
  --name plan-excel-to-sql \
  --resource-group rg-excel-to-sql \
  --sku B1 \
  --is-linux
```

4. **Create Web App**:
```bash
az webapp create \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql \
  --plan plan-excel-to-sql \
  --runtime "PYTHON:3.11"
```

5. **Configure Deployment**:
```bash
# Set startup command
az webapp config set \
  --resource-group rg-excel-to-sql \
  --name excel-to-sql-converter \
  --startup-file "uvicorn web_app.main:app --host 0.0.0.0 --port 8000"
```

6. **Deploy from local Git** (or use GitHub Actions):
```bash
# Configure deployment
az webapp deployment source config-local-git \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql

# Get deployment URL
az webapp deployment list-publishing-credentials \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql \
  --query scmUri \
  --output tsv

# Add remote and push
git remote add azure <deployment-url>
git push azure main
```

7. **Access**: https://excel-to-sql-converter.azurewebsites.net

### Configure Environment Variables

```bash
az webapp config appsettings set \
  --resource-group rg-excel-to-sql \
  --name excel-to-sql-converter \
  --settings \
    DEBUG=false \
    CLIENT_ID="your-client-id" \
    CLIENT_SECRET="your-client-secret"
```

---

## Azure Container Instances

### Steps

1. **Create Container Registry** (optional):
```bash
az acr create \
  --resource-group rg-excel-to-sql \
  --name exceltoSqlRegistry \
  --sku Basic
```

2. **Build and push image**:
```bash
az acr build \
  --registry exceltoSqlRegistry \
  --image excel-to-sql-converter:latest \
  .
```

3. **Deploy to ACI**:
```bash
az container create \
  --resource-group rg-excel-to-sql \
  --name excel-to-sql-aci \
  --image exceltoSqlRegistry.azurecr.io/excel-to-sql-converter:latest \
  --registry-login-server exceltoSqlRegistry.azurecr.io \
  --registry-username <username> \
  --registry-password <password> \
  --dns-name-label excel-to-sql \
  --ports 8000
```

4. **Access**: http://excel-to-sql.eastus.azurecontainer.io:8000

---

## Production Considerations

### Security

1. **Enable HTTPS**:
   - Use Azure App Service built-in SSL
   - Or configure reverse proxy (nginx) with SSL certificates

2. **Authentication**:
   - Add authentication middleware to FastAPI
   - Use Azure AD integration
   - Implement API keys

3. **Environment Variables**:
   - Never commit `.env` files
   - Use Azure Key Vault for secrets
   - Set environment variables in Azure Portal

### Performance

1. **Scaling**:
```bash
# Scale up (vertical)
az appservice plan update \
  --name plan-excel-to-sql \
  --resource-group rg-excel-to-sql \
  --sku P1V2

# Scale out (horizontal)
az webapp scale \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql \
  --instance-count 3
```

2. **Monitoring**:
   - Enable Application Insights
   - Set up health check endpoints
   - Configure alerts

3. **Storage**:
   - Use Azure Blob Storage for uploads/outputs
   - Implement cleanup jobs for old files
   - Set up backup strategy

### Monitoring

1. **Application Insights**:
```bash
az monitor app-insights component create \
  --app excel-to-sql-insights \
  --location eastus \
  --resource-group rg-excel-to-sql

# Link to Web App
az webapp config appsettings set \
  --resource-group rg-excel-to-sql \
  --name excel-to-sql-converter \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=<key>
```

2. **Log Analytics**:
```bash
# View logs
az webapp log tail \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql
```

### Backup & Recovery

1. **Database Backup** (if using):
   - Regular automated backups
   - Point-in-time recovery

2. **File Storage**:
   - Backup uploads/outputs to Azure Blob Storage
   - Implement versioning

### CI/CD Pipeline

Example GitHub Actions workflow:

```yaml
name: Deploy to Azure

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt

      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v2
        with:
          app-name: 'excel-to-sql-converter'
          publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}
```

### Environment-Specific Configuration

**Development** (`config.dev.py`):
- Debug mode enabled
- Detailed logging
- Local file storage

**Production** (`config.prod.py`):
- Debug mode disabled
- Error-only logging
- Azure Blob Storage
- HTTPS enforced
- Rate limiting enabled

### Cost Optimization

1. **Auto-scaling**: Scale down during off-hours
2. **Reserved Instances**: For consistent workloads
3. **Storage Lifecycle**: Auto-delete old files
4. **Monitoring**: Track usage patterns

---

## Troubleshooting

### Common Issues

1. **Port binding issues**:
   - Ensure port 8000 is not in use
   - Change port in configuration

2. **Module import errors**:
   - Verify Python path
   - Check virtual environment activation
   - Reinstall dependencies

3. **File upload failures**:
   - Check file size limits
   - Verify storage permissions
   - Check disk space

4. **Azure deployment issues**:
   - Check deployment logs
   - Verify startup command
   - Check environment variables

### Getting Help

- Check application logs
- Review Azure diagnostics
- Check FastAPI documentation
- Review web_app/README.md

---

## Rollback Strategy

1. **Azure App Service**:
```bash
# List deployment history
az webapp deployment list \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql

# Rollback to previous deployment
az webapp deployment slot swap \
  --name excel-to-sql-converter \
  --resource-group rg-excel-to-sql \
  --slot staging
```

2. **Docker**:
```bash
# Tag and keep previous versions
docker tag excel-to-sql-converter:latest excel-to-sql-converter:v1.0
docker run -d excel-to-sql-converter:v1.0
```

---

## Next Steps

After deployment:
1. ✅ Test all endpoints
2. ✅ Configure monitoring
3. ✅ Set up alerts
4. ✅ Document API usage
5. ✅ Train users
6. ✅ Plan maintenance windows
