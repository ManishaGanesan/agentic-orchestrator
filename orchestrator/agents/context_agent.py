from typing import Dict


class ContextAgent:
    def build_task(self, input_json: Dict) -> Dict:
        user_request = (
            input_json.get("story_desc")
            or input_json.get("request")
            or "Generate SQL for regulatory change"
        )

        return {
            "user_request": user_request,
            "canonical_json": input_json
        }