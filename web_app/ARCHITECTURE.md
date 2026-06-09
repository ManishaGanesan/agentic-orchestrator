# Excel to SQL Converter - Architecture Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER BROWSER                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Web Interface (index.html)                     │  │
│  │  • File Upload Form                                       │  │
│  │  • Job Management Dashboard                               │  │
│  │  • Real-time Status Updates                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTP/HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FASTAPI WEB APPLICATION                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   API Endpoints                           │  │
│  │  • POST /api/upload      - Upload files                   │  │
│  │  • POST /api/process     - Process job                    │  │
│  │  • GET  /api/jobs        - List jobs                      │  │
│  │  • GET  /api/download    - Download results               │  │
│  │  • DELETE /api/job       - Delete job                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Business Logic Layer                         │  │
│  │  • File Validation                                        │  │
│  │  • Job Management                                         │  │
│  │  • Metadata Handling                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   EXISTING COMPONENTS                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              InputProcessor                               │  │
│  │  • Excel File Parser                                      │  │
│  │  • State Procedures Handler                               │  │
│  │  • Procedure Variables Handler                            │  │
│  │  • JSON Output Generator                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FILE STORAGE                                │
│  ┌──────────────────┐      ┌──────────────────┐                │
│  │  Uploads/        │      │  Outputs/         │                │
│  │  • job_*/        │      │  • *_output.json  │                │
│  │    - *.xlsx      │      │                   │                │
│  │    - metadata    │      │                   │                │
│  └──────────────────┘      └──────────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow Diagram

```
User Action: Upload Excel File
    │
    ▼
┌─────────────────────────────────────┐
│ 1. Web Form Submission               │
│    • Files: Excel files              │
│    • Data: Versions, Story ID        │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 2. POST /api/upload                  │
│    • Validate file types             │
│    • Create job directory            │
│    • Save files                      │
│    • Generate job_id                 │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 3. Save Metadata                     │
│    • Job info                        │
│    • Upload timestamp                │
│    • File details                    │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 4. POST /api/process/{job_id}        │
│    • Load metadata                   │
│    • Call InputProcessor             │
│    • Process Excel files             │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 5. InputProcessor.process_folder()   │
│    • Detect file types               │
│    • Parse State Procedures          │
│    • Parse Procedure Variables       │
│    • Generate structured JSON        │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 6. Save Output                       │
│    • Write JSON to outputs/          │
│    • Update metadata                 │
│    • Set processed status            │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 7. Return Results                    │
│    • Success status                  │
│    • Result summary                  │
│    • Output file path                │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 8. UI Update                         │
│    • Show success message            │
│    • Update job list                 │
│    • Enable download button          │
└─────────────────────────────────────┘
```

## Component Interaction

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ 1. Upload Request
       │
       ▼
┌─────────────┐      2. Validate & Save      ┌─────────────┐
│   FastAPI   ├──────────────────────────────▶│ File System │
│    main.py  │◀──────────────────────────────┤  uploads/   │
└──────┬──────┘      3. Job Created          └─────────────┘
       │
       │ 4. Process Request
       │
       ▼
┌─────────────┐     5. Process Excel         ┌─────────────┐
│InputPro-    ├──────────────────────────────▶│  openpyxl   │
│cessor       │◀──────────────────────────────┤   pandas    │
└──────┬──────┘     6. Parsed Data           └─────────────┘
       │
       │ 7. Generate JSON
       │
       ▼
┌─────────────┐     8. Save Result           ┌─────────────┐
│   FastAPI   ├──────────────────────────────▶│ File System │
│   main.py   │◀──────────────────────────────┤  outputs/   │
└──────┬──────┘     9. Saved                  └─────────────┘
       │
       │ 10. Success Response
       │
       ▼
┌─────────────┐
│   Browser   │
│   (Update)  │
└─────────────┘
```

## Data Flow

```
Excel File (.xlsx)
    │
    ├─▶ State Procedures File
    │   └─▶ InputProcessor._process_state_procedures()
    │       └─▶ {
    │             state_name: "...",
    │             state_id: "...",
    │             effective_date: "...",
    │             action: "ADD/UPDATE",
    │             procedures: [...]
    │           }
    │
    └─▶ Procedure Variables File
        └─▶ InputProcessor._process_variables()
            └─▶ {
                  action: "ADD/UPDATE",
                  pdescription: {...},
                  pcode: {...},
                  variables: [...]
                }

Combined Output:
    {
      "state_procedures": [...],
      "procedure_variables": [...]
    }
    │
    └─▶ Saved to outputs/{job_id}_output.json
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   AZURE CLOUD                            │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │          Azure App Service                      │    │
│  │  ┌──────────────────────────────────────────┐  │    │
│  │  │     Python 3.11 Runtime                   │  │    │
│  │  │  ┌────────────────────────────────────┐  │  │    │
│  │  │  │   FastAPI Application              │  │  │    │
│  │  │  │   (web_app/main.py)                │  │  │    │
│  │  │  └────────────────────────────────────┘  │  │    │
│  │  └──────────────────────────────────────────┘  │    │
│  │                    │                             │    │
│  │                    ▼                             │    │
│  │  ┌──────────────────────────────────────────┐  │    │
│  │  │     Azure Blob Storage                    │  │    │
│  │  │  • Uploads Container                      │  │    │
│  │  │  • Outputs Container                      │  │    │
│  │  └──────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │     Application Insights                        │    │
│  │  • Monitoring                                   │    │
│  │  • Logging                                      │    │
│  │  • Analytics                                    │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │     Azure Key Vault                             │    │
│  │  • API Keys                                     │    │
│  │  • Secrets                                      │    │
│  │  • Certificates                                 │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Docker Architecture

```
┌─────────────────────────────────────────┐
│        Docker Container                  │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │   Python 3.11 Base Image           │ │
│  └────────────────────────────────────┘ │
│                 │                        │
│                 ▼                        │
│  ┌────────────────────────────────────┐ │
│  │   Application Code                 │ │
│  │   • web_app/                       │ │
│  │   • dataset_builder/               │ │
│  │   • orchestrator/                  │ │
│  └────────────────────────────────────┘ │
│                 │                        │
│                 ▼                        │
│  ┌────────────────────────────────────┐ │
│  │   Dependencies                     │ │
│  │   • FastAPI                        │ │
│  │   • Uvicorn                        │ │
│  │   • pandas, openpyxl               │ │
│  └────────────────────────────────────┘ │
│                 │                        │
│                 ▼                        │
│  ┌────────────────────────────────────┐ │
│  │   Uvicorn Server                   │ │
│  │   Port: 8000                       │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
                 │
                 ▼
          Host Machine
      Port Mapping: 8000:8000
      Volumes: uploads/, outputs/
```

## Security Layers (Recommended for Production)

```
┌─────────────────────────────────────┐
│  1. Network Layer                    │
│     • HTTPS/TLS                      │
│     • Firewall Rules                 │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  2. Authentication Layer             │
│     • OAuth 2.0 / Azure AD          │
│     • API Keys                       │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  3. Application Layer                │
│     • Input Validation               │
│     • Rate Limiting                  │
│     • CORS Policy                    │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  4. Data Layer                       │
│     • File Type Validation           │
│     • Size Limits                    │
│     • Virus Scanning                 │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  5. Storage Layer                    │
│     • Encryption at Rest             │
│     • Access Control                 │
│     • Audit Logging                  │
└─────────────────────────────────────┘
```

---

*This diagram represents the complete architecture of the Excel to SQL Converter web application*
