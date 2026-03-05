from __future__ import annotations

import json
import os
import shutil
from typing import Dict
from datetime import datetime

from langchain.memory import ConversationBufferMemory
from langchain_community.chat_message_histories import FileChatMessageHistory

try:
    from langchain_google_genai import ChatGoogleGenerativeAI
except Exception:
    ChatGoogleGenerativeAI = None  # type: ignore

try:
    from langchain_openai import ChatOpenAI
except Exception:
    ChatOpenAI = None  # type: ignore


class ConversationChain:
    """LLM wrapper with memory that assembles prompts from loader + stage context.

    Expects the LLM to return JSON with keys: { msg, expression, control? }
    """

    def __init__(self, provider: str = "GEMINI", memory_dir: str = ".memory", session_id: str = "default") -> None:
        os.makedirs(memory_dir, exist_ok=True)
        history_path = os.path.join(memory_dir, f"{session_id}.json")
        # Reset memory on each launch by default; archive previous if enabled
        reset_flag = os.getenv("RESET_MEMORY", "1").lower() not in ("0", "false", "no")
        archive_flag = os.getenv("ARCHIVE_MEMORY", "1").lower() not in ("0", "false", "no")
        if reset_flag and os.path.exists(history_path):
            try:
                if archive_flag:
                    archive_dir = os.getenv("MEMORY_ARCHIVE_DIR", os.path.join(memory_dir, "archive"))
                    os.makedirs(archive_dir, exist_ok=True)
                    ts = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
                    base = os.path.basename(history_path)
                    name, ext = os.path.splitext(base)
                    archived_path = os.path.join(archive_dir, f"{name}-{ts}{ext}")
                    shutil.move(history_path, archived_path)
                else:
                    os.remove(history_path)
            except Exception:
                pass
        self.memory = ConversationBufferMemory(
            memory_key="history",
            chat_memory=FileChatMessageHistory(history_path),
            return_messages=True,
        )

        # Debug prompt logging
        self.session_id = session_id
        self.debug_prompts = os.getenv("DEBUG_PROMPTS", "0").lower() in ("1", "true", "yes", "on")
        self.prompt_log_dir = os.getenv("PROMPT_LOG_DIR", os.path.join(memory_dir, "prompts"))
        self.turn_index = 0
        if self.debug_prompts:
            try:
                os.makedirs(self.prompt_log_dir, exist_ok=True)
            except Exception:
                pass

        provider = provider.upper()
        # Higher temperature for more natural, varied responses (0.7 is a good balance)
        temperature = float(os.getenv("LLM_TEMPERATURE", "0.7"))

        if provider == "GEMINI" and ChatGoogleGenerativeAI is not None:
            model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
            # Support multiple env var names without requiring renames
            google_api_key = (
                os.getenv("GOOGLE_API_KEY")
                or os.getenv("GEMINI_API_KEY")
            )
            # Request JSON-only responses from Gemini
            self.llm = ChatGoogleGenerativeAI(
                model=model_name,
                temperature=temperature,
                google_api_key=google_api_key,
                model_kwargs={"response_mime_type": "application/json"}
            )
        elif provider == "OPENAI" and ChatOpenAI is not None:
            model_name = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
            openai_api_key = os.getenv("OPENAI_API_KEY") or os.getenv("GPT_API_KEY")
            self.llm = ChatOpenAI(model=model_name, temperature=temperature, api_key=openai_api_key)
        else:
            raise RuntimeError("No supported LLM provider available. Install langchain_google_genai or langchain_openai.")

    def build_system(self, core: str, personality: str, stage_text: str) -> str:
        return "\n\n".join([
            core.strip(),
            personality.strip(),
            stage_text.strip(),
            (
                'You must reply ONLY with a single JSON object on one line. '
                'Schema: {"msg": string, "expression": string, "advance_stage": boolean (optional)}. '
                'Set "advance_stage" to true only when explicitly instructed in stage instructions. '
                'Do not include emojis'
            )
        ])

    def run(self, user_text: str, *, core: str, personality: str, stage_text: str, context: Dict[str, str]) -> Dict:
        system_text = self.build_system(core, personality, stage_text)
        human_payload = json.dumps({"user": user_text, **context})
        prompt = [
            ("system", system_text),
            ("human", human_payload)
        ]

        # LangChain Message conversion
        from langchain.schema import SystemMessage, HumanMessage
        system_msg = SystemMessage(content=prompt[0][1])
        human_msg = HumanMessage(content=prompt[1][1])

        # Add memory with correct order: system -> history -> human
        history = self.memory.load_memory_variables({}).get("history")
        if history:
            messages = [system_msg] + history + [human_msg]
        else:
            messages = [system_msg, human_msg]

        # Optional: log prompts (ALWAYS log to file + console for debugging)
        self.turn_index += 1

        # Always log to file
        try:
            log_path = os.path.join(
                self.prompt_log_dir,
                f"{self.session_id}-turn-{self.turn_index:03d}.txt",
            )
            with open(log_path, "w", encoding="utf-8") as f:
                f.write("=== SYSTEM ===\n")
                f.write(system_text)
                f.write("\n\n=== HISTORY ===\n")
                if history:
                    for msg in history:
                        msg_type = type(msg).__name__
                        f.write(f"\n[{msg_type}]\n{msg.content}\n")
                else:
                    f.write("(no history yet)\n")
                f.write("\n\n=== HUMAN ===\n")
                f.write(human_payload)
                f.write("\n")
        except Exception as e:
            print(f"[DEBUG] Failed to log prompt: {e}")

        # Print to console if debug flag enabled
        if self.debug_prompts:
            print(f"\n{'='*80}")
            print(f"[PROMPT DEBUG][turn={self.turn_index}]")
            print(f"{'='*80}")
            print(f"\n=== SYSTEM (assembled prompt) ===\n{system_text}\n")
            print(f"=== HISTORY ({len(history) if history else 0} messages) ===")
            if history:
                for i, msg in enumerate(history):
                    msg_type = type(msg).__name__
                    snippet = msg.content[:200] + "..." if len(msg.content) > 200 else msg.content
                    print(f"  [{i}] {msg_type}: {snippet}")
            else:
                print("  (no history yet)")
            print(f"\n=== HUMAN INPUT ===\n{human_payload}\n")
            print(f"{'='*80}\n")

        resp = self.llm.invoke(messages)

        # Handle both string and list content responses (Gemini can return either)
        if isinstance(resp.content, list):
            # If it's a list, join the parts together
            content = "".join(str(part) for part in resp.content).strip()
        else:
            content = (resp.content or "").strip()

        self.memory.save_context({"input": user_text}, {"output": content})

        # Extract the first valid JSON object from content
        def parse_first_json_object(s: str) -> Dict:
            # Fast path
            try:
                obj = json.loads(s)
                if isinstance(obj, dict):
                    return obj
            except Exception:
                pass
            # Scan for first balanced {...}
            depth = 0
            start = None
            for i, ch in enumerate(s):
                if ch == '{':
                    if depth == 0:
                        start = i
                    depth += 1
                elif ch == '}':
                    if depth > 0:
                        depth -= 1
                        if depth == 0 and start is not None:
                            candidate = s[start:i+1]
                            try:
                                obj = json.loads(candidate)
                                if isinstance(obj, dict):
                                    return obj
                            except Exception:
                                pass
                            break
            return {}

        data = parse_first_json_object(content)
        if not data:
            return {"msg": content, "expression": "thinking"}
        # Keep only the required keys
        msg = data.get("msg", "")
        expression = data.get("expression", "thinking")
        advance_stage = data.get("advance_stage", False)
        return {"msg": msg, "expression": expression, "advance_stage": advance_stage}

