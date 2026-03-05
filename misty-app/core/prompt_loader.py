import os

class PromptLoader:
    def __init__(self, base_path: str = "prompts"):
        self.base_path = base_path
        self._load_all()

    def _load_all(self):
        """Load all .md files into a dict for quick access."""
        self.prompts = {}
        for filename in os.listdir(self.base_path):
            if filename.endswith(".md"):
                key = filename.replace(".md", "").lower()
                with open(os.path.join(self.base_path, filename), "r", encoding="utf-8") as f:
                    self.prompts[key] = f.read().strip()

    def get(self, key: str) -> str:
        """Get the contents of a prompt by key (filename without .md)."""
        return self.prompts.get(key.lower(), "")

    def build_prompt(self, role: str = "responsive", stage: str = "task1") -> str:
        """
        Build a combined prompt based on system setup, personality role, and current stage.
        - role: "control" or "responsive"
        - stage: one of "greeting", "brief", "task1", "task2", "wrap"
        """
        role_key = f"role_{role.lower()}"
        stage_map = {
            "greeting": "stage1_greeting",
            "brief": "stage2_mission_brief",
            "task1": "stage3_task1_suspects",
            "task2": "stage4_task2_location",
            "wrap": "stage5_wrap_up",
        }

        keys = [
            "core_system",
            role_key,
            stage_map.get(stage, "")
        ]

        parts = [self.get(k) for k in keys if k]
        return "\n\n".join([p for p in parts if p])  # Filter out empty ones
