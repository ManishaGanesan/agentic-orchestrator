"""
web_app/main.py
"""
import os
import json
import shutil
import sys
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

ROOT_DIR = Path(__file__).parent.parent
sys.path.append(str(ROOT_DIR))

from dataset_builder.input_processor import InputProcessor
# FIXED: Safe, clean import from your new core runner file
from orchestrator.runner import execute_research_ablation_pipeline

processor = InputProcessor()
app = FastAPI(title="Automated Multi-Agent Excel-to-SQL Server", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = ROOT_DIR / "input_excels"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR = ROOT_DIR / "output_jsons"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

LATEST_INPUT = {}

@app.get("/", response_class=HTMLResponse)
async def home():
    html_file = ROOT_DIR / "web_app/static/index.html"
    if html_file.exists():
        return html_file.read_text(encoding="utf-8")
    return "<h1>Excel to SQL Converter</h1><p>Web static file index.html not found.</p>"

@app.post("/api/upload")
async def upload_files(
    previous_version: str = Form(...),
    new_version: str = Form(...),
    story_id: Optional[str] = Form(None),
    files: List[UploadFile] = File(...)
):
    try:
        if not files:
            raise HTTPException(status_code=400, detail="No files provided")

        global LATEST_INPUT      
        LATEST_INPUT = {
            "previous_version": previous_version,
            "new_version": new_version,
            "story_id": story_id
        }

        uploaded_files = []
        for file in files:
            if not file.filename.endswith((".xlsx", ".xlsm")):
                raise HTTPException(status_code=400, detail=f"Invalid type: {file.filename}")
            
            file_path = UPLOAD_DIR / file.filename
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            uploaded_files.append(file.filename)

        return {"success": True, "files": uploaded_files, **LATEST_INPUT}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/process")
async def process_files(background_tasks: BackgroundTasks, strategy: str = "hybrid"):
    try:
        result = processor.process_folder(str(UPLOAD_DIR))

        final_output = {
            "previous_version": LATEST_INPUT.get("previous_version"),
            "new_version": LATEST_INPUT.get("new_version"),
            "story_id": LATEST_INPUT.get("story_id"),
            "request": f"Generate SQL script updates matching User Story ID: {LATEST_INPUT.get('story_id')}",
            **result
        }

        output_path = OUTPUT_DIR / "output.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(final_output, f, indent=2, default=str)

        # Trigger background task loop seamlessly
        background_tasks.add_task(execute_research_ablation_pipeline, strategy=strategy)

        return {
            "success": True,
            "message": f"Excel structural data parsed successfully. Agent optimization loop running offline via background tasks with retrieval variant: {strategy.upper()}."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)