"""
web_app/main.py
"""
import json
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import uvicorn

ROOT_DIR = Path(__file__).parent.parent
sys.path.append(str(ROOT_DIR))

from dataset_builder.input_processor import InputProcessor
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

LATEST_INPUT: Dict[str, Any] = {}
PIPELINE_STATUS: Dict[str, Any] = {
    "status": "idle",
    "current_step": "idle",
    "message": "Waiting for a run to start.",
    "steps": [],
}


def _set_pipeline_status(status: str, current_step: str, message: str, steps: Optional[List[Dict[str, str]]] = None) -> None:
    global PIPELINE_STATUS
    PIPELINE_STATUS = {
        "status": status,
        "current_step": current_step,
        "message": message,
        "steps": list(steps or PIPELINE_STATUS.get("steps", [])),
    }


def _progress_callback(step: str, message: str) -> None:
    global PIPELINE_STATUS
    steps = list(PIPELINE_STATUS.get("steps", []))
    if steps and steps[-1].get("step") == step:
        steps[-1]["message"] = message
    else:
        steps.append({"step": step, "message": message})
    _set_pipeline_status("running", step, message, steps=steps)


def _run_pipeline(strategy: str, use_cot: bool) -> None:
    try:
        _set_pipeline_status("queued", "queued", "Pipeline queued and about to start.")
        execute_research_ablation_pipeline(strategy=strategy, use_cot=use_cot, progress_callback=_progress_callback)
        _set_pipeline_status("completed", "completed", "Pipeline completed successfully.")
    except Exception as exc:
        _set_pipeline_status("failed", "failed", f"Pipeline failed: {exc}")


@app.get("/", response_class=HTMLResponse)
async def home() -> str:
    html_file = ROOT_DIR / "web_app/static/index.html"
    if html_file.exists():
        return html_file.read_text(encoding="utf-8")
    return "<h1>Excel to SQL Converter</h1><p>Web static file index.html not found.</p>"


@app.get("/api/progress")
async def get_progress() -> Dict[str, Any]:
    return PIPELINE_STATUS


@app.post("/api/upload")
async def upload_files(
    previous_version: str = Form(...),
    new_version: str = Form(...),
    story_id: Optional[str] = Form(None),
    files: List[UploadFile] = File(...),
):
    try:
        if not files:
            raise HTTPException(status_code=400, detail="No files provided")

        global LATEST_INPUT
        LATEST_INPUT = {
            "previous_version": previous_version,
            "new_version": new_version,
            "story_id": story_id,
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
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/api/process")
async def process_files(
    background_tasks: BackgroundTasks,
    strategy: str = Form("hybrid"),
    use_cot: bool = Form(False),
):
    try:
        result = processor.process_folder(str(UPLOAD_DIR))

        final_output = {
            "previous_version": LATEST_INPUT.get("previous_version"),
            "new_version": LATEST_INPUT.get("new_version"),
            "story_id": LATEST_INPUT.get("story_id"),
            "request": f"Generate SQL script updates matching User Story ID: {LATEST_INPUT.get('story_id')}",
            **result,
        }

        output_path = OUTPUT_DIR / "output.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(final_output, f, indent=2, default=str)

        _set_pipeline_status("queued", "processing", "Excel parsing complete. Agent pipeline is starting.")
        background_tasks.add_task(_run_pipeline, strategy=strategy, use_cot=use_cot)

        return {
            "success": True,
            "message": f"Excel structural data parsed successfully. Agent loop running with retrieval: {strategy.upper()} | CoT: {use_cot}.",
            "status": PIPELINE_STATUS,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


if __name__ == "__main__":
    uvicorn.run("web_app.main:app", host="0.0.0.0", port=8000, reload=True)