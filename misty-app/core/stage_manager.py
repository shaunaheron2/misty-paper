from __future__ import annotations

from typing import List, Optional


class StageManager:
    """Tracks the current stage of the multi-stage interaction.

    Stages follow the prompt keys used by PromptLoader.build_prompt:
    greeting -> brief -> task1 -> task2 -> wrap
    """

    def __init__(self, initial_stage: str = "greeting") -> None:
        self._stages: List[str] = [
            "greeting",
            "brief",
            "task1",
            "task2",
            "wrap",
        ]
        self._index: int = self._safe_index(initial_stage)

    def _safe_index(self, stage: str) -> int:
        try:
            return self._stages.index(stage)
        except ValueError:
            return 0

    def get_current(self) -> str:
        return self._stages[self._index]

    def can_advance(self) -> bool:
        return self._index < len(self._stages) - 1

    def advance(self, reason: Optional[str] = None) -> str:
        if self.can_advance():
            self._index += 1
        return self.get_current()

    def reset(self) -> None:
        self._index = 0

    def to_dict(self) -> dict:
        return {"stage": self.get_current(), "index": self._index}

    def from_dict(self, data: dict) -> None:
        stage = data.get("stage")
        if stage:
            self._index = self._safe_index(stage)

