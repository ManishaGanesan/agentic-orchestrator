"""
FastAPI Web Application for Excel to SQL Conversion
Handles file uploads, version management, and SQL script generation
"""
import os
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import sys

sys.path.append(str(Path(__file__).parent.parent))

from dataset_builder.input_processor import InputProcessor

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

UPLOAD_DIR = Path("web_app/uploads")
OUTPUT_DIR = Path("web_app/outputs")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

processor = InputProcessor()


@app.get("/", response_class=HTMLResponse)
async def home():
    """Serve the main HTML interface"""
    html_file = Path("web_app/static/index.html")
    if html_file.exists():
        return html_file.read_text()
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
    background_tasks: BackgroundTasks,
    previous_version: str = Form(..., description="Previous version (e.g., V2605.00)"),
    new_version: str = Form(..., description="New version (e.g., V2606.00)"),
    story_id: Optional[str] = Form(None, description="Story ID (e.g., US1234567)"),
    files: List[UploadFile] = File(..., description="Excel files to process")
):
    """
    Upload Excel files and process them
    Accepts multiple Excel files and version information
    """
    try:
        if not files:
            raise HTTPException(status_code=400, detail="No files provided")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        job_id = f"job_{timestamp}"
        job_dir = UPLOAD_DIR / job_id
        job_dir.mkdir(parents=True, exist_ok=True)

        uploaded_files = []

        for file in files:
            if not file.filename.endswith(('.xlsx', '.xlsm')):
                raise HTTPException(
                    status_code=400, 
                    detail=f"Invalid file type: {file.filename}. Only .xlsx and .xlsm files are allowed"
                )

            file_path = job_dir / file.filename

            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            uploaded_files.append({
                "filename": file.filename,
                "size": os.path.getsize(file_path),
                "path": str(file_path)
            })

        metadata = {
            "job_id": job_id,
            "previous_version": previous_version,
            "new_version": new_version,
            "story_id": story_id,
            "timestamp": timestamp,
            "uploaded_files": uploaded_files
        }

        metadata_file = job_dir / "metadata.json"
        with open(metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)

        return {
            "success": True,
            "job_id": job_id,
            "message": f"Successfully uploaded {len(files)} file(s)",
            "files": uploaded_files,
            "metadata": metadata
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")


@app.post("/api/process/{job_id}")
async def process_job(job_id: str):
    """
    Process uploaded Excel files and generate structured JSON
    """
    try:
        job_dir = UPLOAD_DIR / job_id

        if not job_dir.exists():
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

        metadata_file = job_dir / "metadata.json"
        if not metadata_file.exists():
            raise HTTPException(status_code=404, detail="Job metadata not found")

        with open(metadata_file, "r") as f:
            metadata = json.load(f)

        result = processor.process_folder(str(job_dir))

        output_file = OUTPUT_DIR / f"{job_id}_output.json"
        with open(output_file, "w") as f:
            json.dump(result, f, indent=2, default=str)

        metadata["processed"] = True
        metadata["output_file"] = str(output_file)
        metadata["processing_timestamp"] = datetime.now().isoformat()
        metadata["result_summary"] = {
            "state_procedures_count": len(result.get("state_procedures", [])),
            "procedure_variables_count": len(result.get("procedure_variables", []))
        }

        with open(metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)

        return {
            "success": True,
            "job_id": job_id,
            "message": "Processing completed successfully",
            "result": result,
            "summary": metadata["result_summary"],
            "output_file": str(output_file)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Processing failed: {str(e)}")


@app.get("/api/jobs")
async def list_jobs():
    """
    List all processing jobs
    """
    try:
        jobs = []

        if UPLOAD_DIR.exists():
            for job_dir in sorted(UPLOAD_DIR.iterdir(), reverse=True):
                if job_dir.is_dir():
                    metadata_file = job_dir / "metadata.json"
                    if metadata_file.exists():
                        with open(metadata_file, "r") as f:
                            metadata = json.load(f)
                            jobs.append(metadata)

        return {
            "success": True,
            "count": len(jobs),
            "jobs": jobs
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list jobs: {str(e)}")


@app.get("/api/job/{job_id}")
async def get_job(job_id: str):
    """
    Get job details and status
    """
    try:
        job_dir = UPLOAD_DIR / job_id

        if not job_dir.exists():
            raise HTTPException(status_code=404, detail=f"Job {job_id} not found")

        metadata_file = job_dir / "metadata.json"
        if not metadata_file.exists():
            raise HTTPException(status_code=404, detail="Job metadata not found")

        with open(metadata_file, "r") as f:
            metadata = json.load(f)

        return {
            "success": True,
            "job": metadata
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get job: {str(e)}")


@app.get("/api/download/{job_id}")
async def download_result(job_id: str):
    """
    Download the processed JSON output
    """
    try:
        output_file = OUTPUT_DIR / f"{job_id}_output.json"

        if not output_file.exists():
            raise HTTPException(status_code=404, detail="Output file not found. Process the job first.")

        return FileResponse(
            path=output_file,
            media_type="application/json",
            filename=f"{job_id}_output.json"
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")


@app.delete("/api/job/{job_id}")
async def delete_job(job_id: str):
    """
    Delete a job and its associated files
    """
    try:
        job_dir = UPLOAD_DIR / job_id
        output_file = OUTPUT_DIR / f"{job_id}_output.json"

        if job_dir.exists():
            shutil.rmtree(job_dir)

        if output_file.exists():
            output_file.unlink()

        return {
            "success": True,
            "message": f"Job {job_id} deleted successfully"
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete job: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
