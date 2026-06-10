import os
from typing import Dict, List


class SimpleKnowledgeStore:
    def __init__(self, base_path: str = "Knowledge"):
        self.base_path = base_path

    def _read_folder(self, folder_path: str) -> List[Dict]:
        items = []
        if not os.path.exists(folder_path):
            return items

        for file_name in os.listdir(folder_path):
            full_path = os.path.join(folder_path, file_name)
            if not os.path.isfile(full_path):
                continue

            with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                items.append({
                    "file_name": file_name,
                    "path": full_path,
                    "content": f.read()
                })
        return items

    def load_all(self) -> Dict[str, List[Dict]]:
        return {
            "logic_guides": self._read_folder(os.path.join(self.base_path, "Logic_guide")),
            "script_guides": self._read_folder(os.path.join(self.base_path, "Script_guide")),
            "templates": self._read_folder(os.path.join(self.base_path, "Template")),
            "kt_docs": self._read_folder(os.path.join(self.base_path, "KT")),
        }