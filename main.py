"""
main.py (Root Level)
The root entry point for the orchestrator web app.
"""
import argparse
import sys
from pathlib import Path

import uvicorn

ROOT_DIR = Path(__file__).parent
sys.path.append(str(ROOT_DIR))


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the orchestrator app or trigger a one-off pipeline run.")
    parser.add_argument("--pipeline", action="store_true", help="Run the agent pipeline once instead of serving the web UI")
    parser.add_argument("--strategy", default="raptor", choices=["sparse", "dense", "hybrid", "raptor"])
    parser.add_argument("--use-cot", action="store_true", help="Enable chain-of-thought traces for SQL generation")
    args = parser.parse_args()

    if args.pipeline:
        from orchestrator.runner import execute_research_ablation_pipeline

        print("▶️ Running ablation pipeline manually via root execution CLI entry point...")
        execute_research_ablation_pipeline(strategy=args.strategy, use_cot=args.use_cot)
        return

    print("▶️ Starting the orchestrator web app from the root entry point...")
    uvicorn.run("web_app.main:app", host="0.0.0.0", port=8000, reload=True)


if __name__ == "__main__":
    main()