import json
import time
from typing import List, Dict, Any
from orchestrator.rag.rag_engine import RagEngine


class RetrievalAblationHarness:
    def __init__(self, knowledge_path: str = "Knowledge"):
        self.rag = RagEngine(knowledge_path)
        
    def evaluate_query_matrix(self, test_dataset: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Runs identical user queries across all 4 distinct retrieval configurations 
        to capture performance metrics, latency variations, and size constraints.
        """
        strategies = ["sparse", "dense", "hybrid", "raptor"]
        evaluation_log = []

        for item in test_dataset:
            query_id = item.get("id")
            user_request = item.get("user_request")
            canonical_json = item.get("canonical_json", {})
            ground_truth_keywords = item.get("ground_truth_keywords", [])

            query_results = {
                "query_id": query_id,
                "user_request": user_request,
                "strategies": {}
            }

            for strategy in strategies:
                start_time = time.perf_counter()
                
                # Fetch raw structured context dictionary from your engine
                context_payload = self.rag.build_context(user_request, canonical_json, strategy=strategy)
                
                duration = time.perf_counter() - start_time
                
                # Flatten text to check for keyword hits
                all_retrieved_text = json.dumps(context_payload).lower()
                hits = sum(1 for kw in ground_truth_keywords if kw.lower() in all_retrieved_text)
                hit_rate = hits / max(1, len(ground_truth_keywords))

                query_results["strategies"][strategy] = {
                    "latency_seconds": round(duration, 4),
                    "keyword_hit_rate": round(hit_rate, 2),
                    "character_count": len(all_retrieved_text),
                    "logic_guides_retrieved": len(context_payload.get("logic_guides", []))
                }
                
            evaluation_log.append(query_results)

        return {
            "evaluation_timestamp": time.isoformat(time.datetime.utcnow()),
            "results": evaluation_log
        }


if __name__ == "__main__":
    # Define simple mock query sets reflecting medical claims / pricing tasks
    sample_queries = [
        {
            "id": 1,
            "user_request": "Update the procedural pricing constraints for California APR Pro Pricer matching 2026 effective timelines.",
            "canonical_json": {"pricer_type_description": "APR Pro"},
            "ground_truth_keywords": ["LUT_PricerTypeAPRPro_State", "effdate"]
        }
    ]
    
    harness = RetrievalAblationHarness()
    report = harness.evaluate_query_matrix(sample_queries)
    
    with open("retrieval_ablation_metrics.json", "w") as f:
        json.dump(report, f, indent=2)
    print("Mid-semester retrieval benchmarking matrix complete. Saved to 'retrieval_ablation_metrics.json'.")