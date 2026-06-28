"""
main.py (Root Level)
Allows manual execution of your ablation configurations directly from your terminal.
"""
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).parent
sys.path.append(str(ROOT_DIR))

from orchestrator.runner import execute_research_ablation_pipeline

if __name__ == "__main__":
    print("▶️ Running ablation pipeline manually via root execution CLI entry point...")
    # Change strategy here to "sparse", "dense", "hybrid", or "raptor" to isolate your variables
    execute_research_ablation_pipeline(strategy="hybrid")