"""
FastAPI Web Application for Excel to SQL Conversion
Handles file uploads, version management, and SQL script generation
"""
import os
import json
from platform import processor
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import sys
import subprocess
sys.path.append(str(Path(__file__).parent.parent))
from dataset_builder.input_processor import InputProcessor
processor = InputProcessor()
app = FastAPI(
    title="Excel to SQL Converter",
    description="AI-powered tool to convert Excel changes into SQL scripts",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


UPLOAD_DIR = Path("input_excels")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR = Path("output_jsons")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

@app.get("/", response_class=HTMLResponse)
async def home():
    """Serve the main HTML interface"""
    html_file = Path("web_app/static/index.html")
    if html_file.exists():
        return html_file.read_text(encoding="utf-8")
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Excel to SQL Converter</title>
    </head>
    <body>
        <h1>Excel to SQL Converter</h1>
        <p>Web interface file not found. Please ensure static/index.html exists.</p>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "excel-to-sql-converter"
    }

@app.post("/api/upload")
async def upload_files(
    previous_version: str = Form(...),
    new_version: str = Form(...),
    story_id: Optional[str] = Form(None),
    files: List[UploadFile] = File(...)
):
    """
    Upload Excel files directly to input_excels/
    """
    try:
        if not files:
            raise HTTPException(status_code=400, detail="No files provided")

        uploaded_files = []

        # for existing_file in UPLOAD_DIR.iterdir():
        #     if existing_file.is_file():
        #         existing_file.unlink()
        global LATEST_INPUT      
        LATEST_INPUT = {
            "previous_version": previous_version,
            "new_version": new_version,
            "story_id": story_id
        }
        for file in files:
            if not file.filename.endswith((".xlsx", ".xlsm")):
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid file type: {file.filename}"
                )

            file_path = UPLOAD_DIR / file.filename

            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            uploaded_files.append(file.filename)

        return {
            "success": True,
            "message": f"{len(files)} file(s) uploaded successfully",
            "files": uploaded_files,
            "previous_version": previous_version,
            "new_version": new_version,
            "story_id": story_id
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/process")
async def process_files():
    try:
        # Run processor
        result = processor.process_folder(str(UPLOAD_DIR))

        # ✅ Merge metadata directly with original JSON
        final_output = {
            "previous_version": LATEST_INPUT.get("previous_version"),
            "new_version": LATEST_INPUT.get("new_version"),
            "story_id": LATEST_INPUT.get("story_id"),
            **result
        }

        # ✅ Save in output folder
        output_path = OUTPUT_DIR / "output.json"

        with open(output_path, "w") as f:
            json.dump(final_output, f, indent=2, default=str)

        return {
            "success": True,
            "message": f"Processing completed. Output saved to {output_path}"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
