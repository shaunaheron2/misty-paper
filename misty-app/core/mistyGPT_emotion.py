from deepgram import *
from openai import OpenAI
import ffmpeg, json, os, re, requests, signal, socket, sys, time
from dotenv import load_dotenv
from mutagen.mp3 import MP3
from datetime import datetime
from time import sleep

# Global flag for graceful shutdown
shutdown_requested = False

def signal_handler(sig, frame):
    global shutdown_requested
    print("\n[MistyGPT] Shutdown signal received, terminating gracefully...")
    shutdown_requested = True
from prompt_loader import PromptLoader
from stage_manager import StageManager
from conversation_chain import ConversationChain
from experiment_logger import get_logger
sys.path.append(os.path.join(os.path.join(os.path.dirname(__file__), '..'), 'Python-SDK'))
from mistyPy.Robot import Robot
from mistyPy.Events import Events
# https://platform.openai.com/docs/guides/conversation-state?api-mode=responses
# speech to text --> Text Generation --> Text to Speech --> play on robot

# ----------------------
# Emotion Detection (CUDA lazy-load)
# ----------------------
_emotion_pipe = None

def _ensure_emotion_pipe():
    """Load emotion detection model to CUDA on first use (requires torch/transformers installed)."""
    global _emotion_pipe
    if _emotion_pipe is None:
        try:
            from transformers import pipeline
            # Try CUDA first (device=0), fall back to CPU if unavailable
            try:
                _emotion_pipe = pipeline(
                    "text-classification",
                    model="j-hartmann/emotion-english-distilroberta-base",
                    device=0  # CUDA GPU 0
                )
                print("[Emotion Detection] Loaded on CUDA")
            except Exception:
                # CPU fallback
                _emotion_pipe = pipeline(
                    "text-classification",
                    model="j-hartmann/emotion-english-distilroberta-base"
                )
                print("[Emotion Detection] Loaded on CPU")
        except Exception as e:
            print(f"[Emotion Detection] Failed to load model: {e}")
            _emotion_pipe = "disabled"
    return _emotion_pipe

def detect_emotion(text: str) -> str:
    """
    Detect emotion from user text using transformer model.
    Returns: positive, frustrated, disappointed, anxious, irritated, surprised, neutral
    """
    if not text or not text.strip():
        return "neutral"

    pipe = _ensure_emotion_pipe()
    if pipe == "disabled":
        return "neutral"

    try:
        result = pipe(text)[0]["label"].lower()
    except Exception as e:
        print(f"[Emotion Detection] Error: {e}")
        return "neutral"

    # Map model outputs to simplified emotion categories
    mapping = {
        "joy": "postively engaged",
        "anger": "irritated",
        "sadness": "disappointed",
        "fear": "anxious",
        "disgust": "frustrated",
        "surprise": "curious",
        "neutral": "neutral"
    }
    return mapping.get(result, "neutral")

# ----------------------
# Misty Custom Actions
# ----------------------
custom_actions = {
    "reset": "IMAGE:e_DefaultContent.jpg; ARMS:40,40,1000; HEAD:-5,10,0,1000;",
    "love": "IMAGE:e_Love.jpg; LED-PATTERN:255,0,0,150,0,0,1200,breathe; ARMS:89,-89,1000; HEAD:-5,-10,3,700;",
    "party": "IMAGE:e_EcstacyStarryEyed.jpg; ARMS:0,0,1000; HEAD:-5,0,0,1000; LED-PATTERN:255,0,0,0,0,255,300,blink; PAUSE:4000; LED-PATTERN:0,0,255,40,0,112,1200,breathe; IMAGE:e_Joy2.jpg; ARMS:89,89,1000;",
    "told-you": "ARMS:89,-89,500; HEAD:-5,15,10,500;",
    "surprise2": "LED-PATTERN:0,0,255,40,0,112,200,blink; IMAGE:e_Surprise.jpg; HEAD:-10,0,0,300; ARMS:-89,-89,700;",
    "grief": "IMAGE:e_Grief.jpg; ARMS:89,89,2000; HEAD:6,0,0,3000; LED-PATTERN:0,0,255,40,0,112,1200,breathe; PAUSE:2000;",
    "warn": "IMAGE:e_Contempt.jpg; LED:255,0,0; HEAD:-5,-25,0,500; PAUSE:1000; ARMS:89,-89,700; PAUSE:2000; HEAD:-5,0,0,4000; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500; PAUSE:500; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500; PAUSE:500; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500;",
    "suspicious": "LED-PATTERN:255,0,0,100,0,0,300,blink; IMAGE:e_Contempt.jpg; ARMS:89,-89,700; HEAD:-5,-20,0,500;",
    "fear": "IMAGE:e_Fear.jpg; ARMS:-89,-89,300; HEAD:-10,0,0,300;",
    "hi": "IMAGE:e_Joy2.jpg; ARMS:-80,-80,600; PAUSE:200; ARMS:40,40,600; PAUSE:300; HEAD:-8,15,0,700; PAUSE:400; IMAGE:e_DefaultContent.jpg;",
    "oops": "IMAGE:e_Joy2.jpg; HEAD:0,0,0,1000; PAUSE:1000; IMAGE:e_DefaultContent.jpg;",
    "listen": "IMAGE:e_Joy2.jpg; HEAD:-5,20,0,1000; PAUSE:2500; HEAD:-5,10,0,500; IMAGE:e_DefaultContent.jpg;",
    "hint": "IMAGE:e_ContentRight.jpg; HEAD:-5,10,0,600; PAUSE:600; IMAGE:e_DefaultContent.jpg;",
    "question": "IMAGE:e_Joy.jpg; ARMS:0,0,700; HEAD:-5,10,0,1000;",
    "yes": "IMAGE:e_Joy.jpg; LED:0,255,0; ARMS:-89,89,2000; HEAD:5,0,0,1000; PAUSE:1000; HEAD:-5,0,0,1000;",
    "wrong": "IMAGE:e_ApprehensionConcerned.jpg; ARMS:-80,-80,1000; PAUSE:1000; ARMS:40,40,1000; IMAGE:e_DefaultContent.jpg;",
    "frustrated": "IMAGE:e_Frustrated.jpg; ARMS:-80,-80,1000; PAUSE:1000; ARMS:40,40,1000; IMAGE:e_DefaultContent.jpg;",
    "concerned": "IMAGE:e_ApprehensionConcerned.jpg; LED-PATTERN:0,0,255,40,0,112,1200,breathe; HEAD:-5,-25,0,500; ARMS:-89,-89,2000;",
    "think": "IMAGE:e_ContentRight.jpg; LED-PATTERN:255,255,0,180,235,0,100,blink; HEAD:-15,-10,-10,500; PAUSE:3000; ARMS:89,89,700; HEAD:-5,0,0,700; LED-PATTERN:0,0,255,40,0,112,1200,breathe; IMAGE:e_DefaultContent.jpg;",
    "excited": "IMAGE:e_EcstacyStarryEyed.jpg; LED-PATTERN:255,255,0,180,235,0,100,blink; HEAD:0,0,0,1000; ARMS:-89,-89,2000; PAUSE:1000; HEAD:-10,5,0,1000; PAUSE:1500; LED-PATTERN:0,0,255,40,0,112,1200,breathe;",
    "confused": "IMAGE:e_JoyGoofy3.jpg; ARMS:-80,-80,1000; PAUSE:1000; ARMS:40,40,1000; IMAGE:e_DefaultContent.jpg;",
    "funny": "IMAGE:e_EcstacyHilarious.jpg; ARMS:40,40,1000; PAUSE:1000; IMAGE:e_DefaultContent.jpg;",
    "hint": "IMAGE:e_ContentRight.jpg; HEAD:-5,10,0,600; PAUSE:600; IMAGE:e_DefaultContent.jpg;",
    "goodbye": "IMAGE:e_DefaultContent.jpg; HEAD:0,0,0,1000; PAUSE:1000; IMAGE:e_DefaultContent.jpg;",
    "check-surroundings-slow": "LED-PATTERN:0,0,255,40,0,112,1200,breathe; IMAGE:e_ContentLeft.jpg; HEAD:-5,0,10,500; ARMS:89,89,3000; PAUSE:2000; IMAGE:e_ContentRight.jpg; HEAD:-5,0,-10,500; PAUSE:2000; IMAGE:e_DefaultContent.jpg; HEAD:-5,0,0,500;",
    "sleep": "IMAGE:e_SleepingZZZ.jpg; LED-PATTERN:0,0,255,40,0,155,1200,breathe; HEAD:-25,-30,40,1500; ARMS:89,89,1500;",
    "warn": "IMAGE:e_Contempt.jpg; LED:255,0,0; HEAD:-5,-25,0,500; PAUSE:1000; ARMS:89,-89,700; PAUSE:2000; HEAD:-5,0,0,4000; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500; PAUSE:500; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500; PAUSE:500; ARMS:89,-5,500; PAUSE:500; ARMS:89,-89,500;",
    "correct":"LED-PATTERN:0,0,255,40,0,112,800,breathe; IMAGE:e_Joy2.jpg; HEAD:-15,0,0,100; ARMS:-89,-89,1000;",
    "admire": "ARMS:0,0,500; PAUSE:300; HEAD:-5,-30,0,500; LED-PATTERN:0,0,255,40,0,112,1200,breathe; IMAGE:e_Admiration.jpg;",
"check-it-out":"LED-PATTERN:255,255,255,110,110,110,200,breathe; ARMS:-89,-89,500; HEAD:-5,5,0,500; PAUSE:1000; ARMS:79,79,2000; HEAD:25,5,0,2000; PAUSE:2000; ARMS:-89,-89,2000; HEAD:-5,5,0,2000;",
"head-stroke": "IMAGE:e_EcstacyHilarious.jpg; AUDIO:s_Ecstacy.wav; ARMS:-70,-70,500; LED-PATTERN:100,70,160,180,235,0,400,breathe;"
}
# ----------------------
# Experiment Configuration
# Set the run mode here per participant: "RESPONSIVE" or "CONTROL"
RUN_MODE = "RESPONSIVE"
# ----------------------
class MistyRobot():

    def log_event(self, **data):
        data.setdefault("mode", self.mode)
        print("[LOG]", json.dumps(data))

    def __init__(self, misty_ip_address):

        # Misty IP address
        self.misty_ip_address = misty_ip_address
        # Misty Robot (Python SDK)
        self.misty = Robot(misty_ip_address)
        self.volume = 50


        # create all of our custom actions
        for action_name, action_script in custom_actions.items():
            self.misty.create_action(
                name = action_name,
                script = action_script,
                overwrite = True
            )

        # Load the Deepgram API key from the environment variable
        load_dotenv()
        self.deepgram_api_key = os.getenv('DEEPGRAM_API_KEY')
        if not self.deepgram_api_key:
            raise ValueError("Please set the DEEPGRAM_API_KEY environment variable.")
            
        # variables needed to be initialized for Deepgram speech-to-text
        self.user_transcript_list = []
        self.deepgram_paused = False
        self.cam = False
        self.user_utterance_counter = 1
        self.current_deepgram_transcript = ""

        # --- Mode + small state ---
        self.mode = RUN_MODE  # "RESPONSIVE" or "CONTROL"
        self.is_responsive = (self.mode == "RESPONSIVE")

        # per-utterance scratch
        self.preload_hint = False          # set when we think user will want a hint
        self.did_backchannel = False       # prevent spamming nonverbal cues
        self.last_partial_ts = 0.0

        # Silence handling
        self.last_speech_time = time.time()  # Track when user last spokeaura-stella-e
        self.silence_check_offered = False    # Prevent repeated check-ins during same silence period

        # Auto-exit after wrap stage (configurable timeout in seconds)
        self.wrap_timeout_seconds = int(os.getenv("WRAP_TIMEOUT_SECONDS", "60"))
        print(f"[CONFIG] Wrap stage auto-exit timeout: {self.wrap_timeout_seconds} seconds")

        # Emotion tracking
        self.current_emotion = "neutral"
        self.frustration_count = 0
        self.enable_emotion_detection = os.getenv("ENABLE_EMOTION_DETECTION", "true").lower() == "true"

        # TTS configuration
        self.tts_provider = os.getenv("TTS_PROVIDER", "misty").lower()
        print(f"[CONFIG] TTS Provider: {self.tts_provider}")

        # initialize the OpenAI client for TTS with the OPEN_AI_API_KEY environment variable
        open_ai_api_key = os.getenv('GPT_API_KEY')
        if not open_ai_api_key:
            raise ValueError("Please set the GPT_API_KEY environment variable.")
        self.openai_client = OpenAI(api_key=open_ai_api_key)

        # set the path for the robot speech files for both local and robot access
        # this requires that a HTTP server is running in the same directory as this file using
        # the command: python -m http.server 8000
        self.speech_file_path_local = os.path.join(os.path.dirname(__file__), 'robot_speech_files/speech.mp3')
        local_ip_address = [(s.connect(('8.8.8.8', 80)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1]
        self.speech_file_path_for_misty = 'http://' + local_ip_address + ':8000/robot_speech_files/speech.mp3'

        # Prompts + stage + conversation chain
        self.prompt_loader = PromptLoader()
        self.stage_manager = StageManager(initial_stage="greeting")
        provider = os.getenv("LLM_PROVIDER", "GEMINI")

        # Experiment logging - get next sequential participant ID
        self.logger = get_logger()
        session_id = self.logger.get_next_participant_id()
        self.session_id = session_id
        self.turn_number = 0

        # Initialize conversation chain with session ID
        self.chain = ConversationChain(provider=provider, session_id=session_id)

        # Participant name will be extracted from greeting conversation
        self.participant_name = None
        self.logger.start_session(session_id=session_id, mode=self.mode, participant_name=None)
        print(f"[SESSION] Started new session: {session_id} (mode: {self.mode})")

        # Track task submissions (to know when participant clicked Submit button)
        self.task_submissions = {
            'task1': False,
            'task2': False
        }

        # Track timer expirations (to prompt user when time runs out)
        self.timer_expirations = {
            'task1': False,
            'task2': False
        }

        # reset misty's LED and expression
        self.misty.change_led(100, 70, 160)
        self.misty.start_action(name="reset")

        # initial transcript
        self.current_deepgram_transcript = "Start conversation"
        self.execute_human_robot_dialogue()


    def execute_human_robot_dialogue(self):
        global shutdown_requested

        # keep running until you hit Ctrl+C or the genAI text model believes the conversation is done
        while not shutdown_requested:

            # send the user input to the generative model and get the response
            user_input = self.current_deepgram_transcript or ""

            # Check if user input is empty/silence (skip initial "Start conversation")
            is_silence = (not user_input or len(user_input.strip()) == 0)
            is_initial_start = (user_input == "Start conversation")

            # Debug: Show transcript state every few iterations
            if is_silence and not is_initial_start:
                # Only log silence checks periodically to avoid spam
                pass  # Logging happens below

            # If pure silence (not initial start), handle it specially
            if is_silence and not is_initial_start:
                silence_duration = time.time() - self.last_speech_time
                # Only log every 5 seconds to avoid spam
                if int(silence_duration) % 5 == 0:
                    print(f"[SILENCE] {silence_duration:.1f}s of silence (threshold: 25s)")

                # After 20-30 seconds of silence, offer a check-in (once per silence period)
                if silence_duration > 25 and not self.silence_check_offered:
                    self.silence_check_offered = True
                    # Set a context flag for the LLM to know this is a silence check-in
                    user_input = "[SILENCE_CHECK_IN]"
                else:
                    # Still within acceptable silence or already offered check-in
                    # Check if we're in wrap stage and timeout exceeded - exit gracefully
                    if self.stage_manager.get_current() == "wrap" and silence_duration > self.wrap_timeout_seconds:
                        print(f"\n{'='*80}")
                        print(f"⏱️  AUTO-EXIT: Wrap stage timeout exceeded")
                        print(f"   Silence duration: {silence_duration:.1f}s > {self.wrap_timeout_seconds}s")
                        print(f"   Exiting session gracefully...")
                        print(f"{'='*80}\n")
                        self.logger.log_event(self.session_id, "session_auto_exit", {
                            "reason": "wrap_stage_timeout",
                            "silence_duration": silence_duration,
                            "timeout_threshold": self.wrap_timeout_seconds
                        })
                        break  # Exit the main loop - cleanup happens in finally block

                    # Still silent but haven't hit threshold or already checked in
                    # Sleep briefly to prevent tight loop from consuming 100% CPU
                    time.sleep(0.5)
                    continue  # Skip LLM call, keep checking silence duration

            # User spoke! Update last speech time and reset silence check flag
            if not is_silence and not is_initial_start:
                self.last_speech_time = time.time()
                self.silence_check_offered = False

            # --- Emotion Detection ---
            if self.enable_emotion_detection and user_input and user_input != "[SILENCE_CHECK_IN]":
                self.current_emotion = detect_emotion(user_input)
                print(f"[Emotion Detection] Detected: {self.current_emotion}")

                # Track consecutive frustration
                if self.current_emotion in ("frustrated", "anxious", "irritated", "disappointed"):
                    self.frustration_count += 1
                else:
                    self.frustration_count = 0

                # Log emotion event
                self.logger.log_event(
                    self.session_id,
                    "emotion_detected",
                    {"emotion": self.current_emotion, "frustration_count": self.frustration_count, "user_input": user_input}
                )
            else:
                self.current_emotion = "neutral"

            if self.preload_hint and self.is_responsive:
                user_input += " [HINT_REQUESTED]"   # simple signal to the prompt/policy
                self.preload_hint = False

            # Sync stage with UI (if facilitator advanced via GUI)
            try:
                r = requests.get("http://127.0.0.1:5000/stage_current", timeout=0.3)
                ui_stage = (r.json() or {}).get("stage")
                if isinstance(ui_stage, str) and ui_stage and ui_stage != self.stage_manager.get_current():
                    self.stage_manager.from_dict({"stage": ui_stage})
            except Exception:
                pass

            # Check for task submissions (participant clicked Submit button)
            try:
                r = requests.get("http://127.0.0.1:5000/task_submission_status", timeout=0.3)
                submission_status = r.json() or {}
                for task_id, submitted in submission_status.items():
                    if submitted and not self.task_submissions.get(task_id):
                        # New submission detected!
                        self.task_submissions[task_id] = True
                        print(f"[MistyGPT] Detected {task_id} submission by participant")
                        self.logger.log_event(self.session_id, "task_submission_detected", {"task": task_id})
            except Exception:
                pass

            # Check for timer expirations (time ran out on task)
            try:
                r = requests.get("http://127.0.0.1:5000/timer_expired_status", timeout=0.3)
                timer_status = r.json() or {}
                for task_id, expired in timer_status.items():
                    if expired and not self.timer_expirations.get(task_id):
                        # Timer just expired!
                        self.timer_expirations[task_id] = True
                        print(f"[MistyGPT] Detected {task_id} timer expiration")
                        self.logger.log_event(self.session_id, "timer_expired_detected", {"task": task_id})
            except Exception:
                pass

            # Build prompt parts
            # Build a combined prompt (core + personality + stage)
            current_stage_before_llm = self.stage_manager.get_current()
            print(f"[DEBUG] Current stage BEFORE LLM: {current_stage_before_llm}")
            stage_text = self.prompt_loader.build_prompt(
                role="responsive" if self.is_responsive else "control",
                stage=current_stage_before_llm
            )
            # De-duplicate: stage_text already includes core_system + role + stage
            core = ""
            personality = ""

            # Build context with stage and submission status
            current_stage = self.stage_manager.get_current()
            context = {
                "stage": current_stage,
            }

            # Add emotion information to context (for RESPONSIVE mode to use)
            if self.enable_emotion_detection and self.current_emotion != "neutral":
                context["detected_emotion"] = self.current_emotion
                if self.frustration_count >= 2:
                    context["frustration_note"] = "User seems frustrated - offer encouragement and help"

            # Add submission status hint to context if relevant to current stage
            if current_stage == "task1" and self.task_submissions.get('task1'):
                context["note"] = "Participant has submitted their Task 1 answer"
            elif current_stage == "task2" and self.task_submissions.get('task2'):
                context["note"] = "Participant has submitted their Task 2 answer"

            # Add timer expiration prompt if timer just expired
            if current_stage == "task1" and self.timer_expirations.get('task1'):
                context["timer_expired"] = "task1"
                # Clear the flag after adding to context (one-time prompt)
                self.timer_expirations['task1'] = False
                # Also clear in Flask backend to avoid re-detection
                try:
                    requests.post("http://127.0.0.1:5000/reset_timer", json={"task_id": "task1"}, timeout=0.3)
                except Exception:
                    pass
            elif current_stage == "task2" and self.timer_expirations.get('task2'):
                context["timer_expired"] = "task2"
                # Clear the flag after adding to context (one-time prompt)
                self.timer_expirations['task2'] = False
                # Also clear in Flask backend to avoid re-detection
                try:
                    requests.post("http://127.0.0.1:5000/reset_timer", json={"task_id": "task2"}, timeout=0.3)
                except Exception:
                    pass

            print(f"[DEBUG] Context for LLM: {context}")    

            # Track start time for response time measurement
            llm_start_time = time.time()

            response_json_dict = self.chain.run(
                user_input,
                core=core,
                personality=personality,
                stage_text=stage_text,
                context=context,
            )

            response_text = response_json_dict.get("msg", "")
            response_expression = response_json_dict.get("expression", "question")
            print("AI (text):\t", response_text)
            print("AI (expression):", response_expression)

            # Extract participant name during greeting stage (if not already extracted)
            if self.stage_manager.get_current() == "greeting" and not self.participant_name and user_input and user_input != "[SILENCE_CHECK_IN]" and user_input != "Start conversation":
                # Simple heuristic to extract name from common patterns
                import re
                name_patterns = [
                    r"(?:my name is|i'm|i am|this is|it's|im)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)",  # "My name is Alice", "I'm Bob Smith"
                    r"^([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)$",  # Just "Alice" or "Alice Smith"
                ]
                for pattern in name_patterns:
                    match = re.search(pattern, user_input, re.IGNORECASE)
                    if match:
                        self.participant_name = match.group(1).title()  # Capitalize properly
                        print(f"[SESSION] Participant name detected: {self.participant_name}")
                        # Update the session in database with participant name
                        try:
                            conn = self.logger._get_connection()
                            conn.execute("""
                                UPDATE sessions
                                SET participant_name = ?
                                WHERE session_id = ?
                            """, [self.participant_name, self.session_id])
                            conn.commit()
                            conn.close()
                        except Exception as e:
                            print(f"[WARNING] Could not update participant name: {e}")
                        break

            # Calculate response time
            response_time_ms = int((time.time() - llm_start_time) * 1000)

            # Only skip if response is truly empty (not short valid responses like "Yes", "No", "Okay")
            # Check for actual emptiness rather than just length
            if not response_text or len(response_text.strip()) == 0:
                print("[DEBUG] Empty LLM response - continuing to listen")
                self.current_deepgram_transcript = ""  # Clear transcript before relistening
                self.start_listening()
                continue

            # Log dialogue turn to database
            self.turn_number += 1
            flags = []
            if self.preload_hint:
                flags.append("hint_requested")
            if self.did_backchannel:
                flags.append("backchannel")
            if is_silence and user_input == "[SILENCE_CHECK_IN]":
                flags.append("silence_check_in")
            # Add emotion flags
            if self.enable_emotion_detection and self.current_emotion != "neutral":
                flags.append(f"emotion:{self.current_emotion}")
            if self.frustration_count >= 2:
                flags.append("high_frustration")

            self.logger.log_dialogue_turn(
                session_id=self.session_id,
                turn_number=self.turn_number,
                stage=self.stage_manager.get_current(),
                user_input=user_input,
                llm_response=response_text,
                expression=response_expression,
                response_time_ms=response_time_ms,
                flags=",".join(flags)
            )

            #self.misty.play_audio("s_DisorientedConfused.wav", volume=30)
            time.sleep(1)

            # TTS: Choose between Misty onboard, OpenAI, or Deepgram
            if self.tts_provider == "openai":
                # OpenAI text-to-speech: generating speech and saving to a file
                print("[TTS] Using OpenAI TTS")
                with self.openai_client.audio.speech.with_streaming_response.create(
                    #model="gpt-4o-mini-tts", #tts-1 may also be a good choice, as it was designed with low latency
                    model="tts-1",
                    voice="sage", # see all voice options and play around with them at https://www.openai.fm/
                    input=response_text,
                    instructions="You are a confident and quick, helpful and curious robot.",
                ) as response:
                    response.stream_to_file(self.speech_file_path_local)

                # Play the speech file on Misty
                self.misty.play_audio(self.speech_file_path_for_misty, volume=self.volume)

                # Get the length of the audio file Misty is playing
                audio = MP3(self.speech_file_path_local)
                audio_info = audio.info
                audio_file_length = audio_info.length
                print(f"[DEBUG] Waiting {audio_file_length:.1f}s for OpenAI TTS to complete")

                # Wait for the audio file to finish playing before starting to listen again
                delay_for_stt = 0.001
                if (audio_file_length > delay_for_stt):
                    sleep(audio_file_length - delay_for_stt)

            elif self.tts_provider == "deepgram":
                # Deepgram Aura text-to-speech
                print("[TTS] Using Deepgram Aura TTS")
                try:
                    from deepgram import DeepgramClient, SpeakOptions

                    deepgram = DeepgramClient(self.deepgram_api_key)

                    # Configure Deepgram TTS options
                    # Available voices: https://developers.deepgram.com/docs/tts-models
                    # Aura models: aura-asteria-en (friendly female), aura-luna-en (warm female),
                    #              aura-stella-en (conversational female), aura-athena-en (professional female),
                    #              aura-hera-en (expressive female), aura-orion-en (confident male),
                    #              aura-arcas-en (calm male), aura-perseus-en (energetic male),
                    #              aura-angus-en (irish male), aura-orpheus-en (narrative male),
                    #              aura-helios-en (warm male), aura-zeus-en (authoritative male)
                    options = SpeakOptions(
                        model="aura-stella-en",  # Friendly, engaging voice
                        encoding="mp3",
                    )

                    # Generate speech using the updated API
                    response = deepgram.speak.rest.v("1").save(
                        self.speech_file_path_local,
                        {"text": response_text},
                        options
                    )

                    # Play the speech file on Misty
                    self.misty.play_audio(self.speech_file_path_for_misty, volume=self.volume)

                    # Get the length of the audio file
                    audio = MP3(self.speech_file_path_local)
                    audio_info = audio.info
                    audio_file_length = audio_info.length
                    print(f"[DEBUG] Waiting {audio_file_length:.1f}s for Deepgram TTS to complete")

                    # Wait for audio to finish
                    delay_for_stt = 0.001
                    if (audio_file_length > delay_for_stt):
                        sleep(audio_file_length - delay_for_stt)

                except Exception as e:
                    print(f"[ERROR] Deepgram TTS failed: {e}")
                    print("[TTS] Falling back to Misty onboard TTS")
                    # Fallback to Misty onboard
                    word_count = len(response_text.split())
                    estimated_duration = (word_count / 200) * 60.0
                    wait_time = estimated_duration + 0.1
                    self.misty.speak(response_text)
                    time.sleep(wait_time)

            else:  # Default to Misty onboard TTS
                # Misty onboard TTS
                print("[TTS] Using Misty onboard TTS")
                word_count = len(response_text.split())
                estimated_duration = (word_count / 200) * 60.0  # seconds
                wait_time = estimated_duration + 0.1

                self.misty.speak(response_text)
                print(f"[DEBUG] Waiting {wait_time:.1f}s for speech to complete ({word_count} words)")
                time.sleep(wait_time)

            # Set the expression for the robot
            if (response_expression in custom_actions):
                self.misty.start_action(name=response_expression)
            else:
                print("Expression not found in custom actions. Using default expression.")
                self.misty.start_action(name="question")

            # LLM-controlled stage advancement for greeting stage
            if self.stage_manager.get_current() == "greeting" and response_json_dict.get("advance_stage", False):
                print(f"\n{'='*80}")
                print(f"⚠️  AUTO-ADVANCING STAGE: greeting → brief")
                print(f"   Trigger: LLM completed all greeting steps")
                print(f"{'='*80}\n")
                new_stage = self.stage_manager.advance("llm_greeting_complete")
                print(f"[DEBUG] Advanced from greeting to {new_stage}")
                self.logger.log_event(self.session_id, "stage_change", {"from": "greeting", "to": new_stage, "trigger": "llm_greeting_complete"})
                try:
                    requests.post("http://127.0.0.1:5000/stage", json={"stage": new_stage}, timeout=0.3)
                except Exception:
                    pass

            # Fallback: advance from mission brief to task1 when participant indicates readiness
            # Only advance if user is explicitly ready (not just saying "yes" to something else)
            if self.stage_manager.get_current() == "brief":
                # More specific ready signals that indicate they want to start the tasks
                ready_phrases = ["ready to start", "let's start", "let's begin", "i'm ready", "start the task"]
                ready_words = ["ready", "start", "begin"]

                # Check for explicit readiness, not just "yes/okay" which could be responses to questions
                is_ready = (
                    any(phrase in user_input.lower() for phrase in ready_phrases) or
                    any(word in user_input.lower().split() for word in ready_words)
                )

                print(f"[DEBUG] Brief stage check - user_input: '{user_input}', is_ready: {is_ready}")
                if is_ready:
                    print(f"\n{'='*80}")
                    print(f"⚠️  AUTO-ADVANCING STAGE: brief → task1")
                    print(f"   Trigger: User indicated readiness")
                    print(f"   User input: '{user_input}'")
                    print(f"{'='*80}\n")
                    new_stage = self.stage_manager.advance("fallback_brief_ready")
                    print(f"[DEBUG] Advanced from brief to {new_stage}")
                    self.logger.log_event(self.session_id, "stage_change", {"from": "brief", "to": new_stage, "trigger": "fallback_brief_ready"})
                    try:
                        requests.post("http://127.0.0.1:5000/stage", json={"stage": new_stage}, timeout=0.3)
                    except Exception:
                        pass
                else:
                    print(f"[DEBUG] Staying in brief stage")

            # Heuristics: advance task1 -> task2 when user indicates readiness AND has submitted
            def _norm(s: str) -> str:
                return (s or "").strip().lower()
            def _said_ready_for_next(text: str) -> bool:
                t = _norm(text)
                # Check for readiness indicators: "ready", "next", "move on", "continue", "submitted"
                ready_phrases = ["ready", "next", "move on", "continue", "let's go", "submitted", "ready for task 2", "finished"]
                return any(phrase in t for phrase in ready_phrases)

            if self.stage_manager.get_current() == "task1" and _said_ready_for_next(user_input):
                # Check if user has actually submitted their answer
                if self.task_submissions.get('task1'):
                    # User submitted AND indicated readiness - advance!
                    print(f"\n{'='*80}")
                    print(f"⚠️  AUTO-ADVANCING STAGE: task1 → task2")
                    print(f"   Trigger: User indicated readiness + task1 submitted")
                    print(f"   User input: '{user_input}'")
                    print(f"{'='*80}\n")
                    new_stage = self.stage_manager.advance("task1_completed")
                    self.logger.log_event(self.session_id, "stage_change", {"from": "task1", "to": new_stage, "trigger": "task1_completed"})
                    try:
                        requests.post("http://127.0.0.1:5000/stage", json={"stage": new_stage}, timeout=0.3)
                    except Exception:
                        pass
                else:
                    # User indicated readiness but hasn't submitted - add context for LLM to prompt them
                    print(f"[DEBUG] User indicated readiness for task2 but hasn't submitted task1 answer")
                    context["ready_but_not_submitted"] = "task1"
                    context["prompt_submission_note"] = "User wants to move on but hasn't submitted Task 1 answer. Gently remind them to submit before moving forward."

            # Heuristics: advance task2 -> wrap when user indicates completion AND has submitted
            def _said_task2_solution(text: str) -> bool:
                t = _norm(text)
                # Look for readiness phrases
                mentions_ready = any(k in t for k in ["ready", "next", "submitted", "continue", "done", "finished"])
                return mentions_ready

            if self.stage_manager.get_current() == "task2" and _said_task2_solution(user_input):
                # Check if user has actually submitted their answer
                if self.task_submissions.get('task2'):
                    # User submitted AND indicated completion - advance to wrap!
                    print(f"\n{'='*80}")
                    print(f"⚠️  AUTO-ADVANCING STAGE: task2 → wrap")
                    print(f"   Trigger: User indicated completion + task2 submitted")
                    print(f"   User input: '{user_input}'")
                    print(f"{'='*80}\n")
                    new_stage = self.stage_manager.advance("task2_solved")
                    self.logger.log_event(self.session_id, "stage_change", {"from": "task2", "to": new_stage, "trigger": "task2_solved"})
                    try:
                        requests.post("http://127.0.0.1:5000/stage", json={"stage": new_stage}, timeout=0.3)
                    except Exception:
                        pass
                else:
                    # User indicated completion but hasn't submitted - add context for LLM to prompt them
                    print(f"[DEBUG] User indicated readiness for wrap but hasn't submitted task2 answer")
                    context["ready_but_not_submitted"] = "task2"
                    context["prompt_submission_note"] = "User wants to wrap up but hasn't submitted Task 2 answer. Gently remind them to submit before moving forward."

            # Clear transcript before next iteration to enable silence detection
            self.current_deepgram_transcript = ""

            # start listening again
            self.start_listening()

        # Loop exited
        if shutdown_requested:
            print("[MistyGPT] Main dialogue loop exited due to shutdown signal")
        else:
            print("[MistyGPT] Main dialogue loop exited normally")


    def start_listening(self):
        # Set visual cue for listening mode (no head movement to avoid interfering with head tracker)
        self.misty.display_image("e_DefaultContent.jpg")
        # startup the robot's camera streaming and Deepgram speech-to-text
        self.deepgram_paused = False
        # reset per-utterance flags
        self.did_backchannel = False
        self.preload_hint = False
        self.last_partial_ts = time.time()
        # Don't reset silence tracking here - we want to track cumulative silence
        # Only reset when user actually speaks (handled in main loop)
        self.start_cam()
        self.init_deepgram()


    def start_cam(self):
        self.rtsp_url = 'rtsp://' + self.misty_ip_address + ':1936'
        stat = self.misty.get_av_streaming_service_enabled()
        sleep(.1)
        if (not stat.json()["result"]):
            self.misty.enable_av_streaming_service()
        sleep(.1)
        self.misty.stop_av_streaming()
        sleep(.1)
        self.misty.start_av_streaming(url="rtspd:1936", width=1920, height=1080, frameRate=30)
        sleep(.5)

        self.cam = True
        self.process = (
                    ffmpeg
                    .input(self.rtsp_url,**{"use_wallclock_as_timestamps": "1", "rtsp_transport": "tcp"})
                )
        self.start = time.time()
        print("AV streaming started")


    def init_deepgram(self):
        # Specify the output format (MP3)
        output_format = 'mp3'
        date = datetime.now().strftime("%m-%d-%Y-%H-%M")
        if not os.path.exists('./logs/' + date + '/'):
            os.makedirs('./logs/' + date + '/')
        # Run the FFmpeg command
        self.op1 = self.process.output('-', format="mp3", loglevel="quiet").run_async(pipe_stdout=True, pipe_stdin=True)
        self.op2 = self.process.output('./logs/' + date + '/' + str(self.user_utterance_counter) + '.mp3', format="mp3", loglevel="quiet").run_async(pipe_stdin=True)
        # STEP 1: Create a Deepgram client using the API key
        self.user_utterance_counter += 1
        deepgram = DeepgramClient(self.deepgram_api_key)

        # STEP 2: Create a websocket connection to Deepgram
        # dg_connection = deepgram.listen.live.v("1")
        dg_connection = deepgram.listen.websocket.v("1")
        print("Deepgram speech-to-text listening")

        # change the LED to blue to indicate that the robot is listening
        self.misty.change_led(0, 199, 252)

        # STEP 3: Define the event handlers for the connection
        def on_message(self_local, result, **kwargs):
            text = result.channel.alternatives[0].transcript
            if not text:
                return

            # DEBUG: Print result structure to understand speech_final location
            print(f"[DEBUG] is_final={result.is_final}, speech_final={getattr(result, 'speech_final', 'NOT_FOUND')}, text={text[:50]}")

            # --- INTERIM PARTIALS: Responsive-only nonverbal cues ---
            if self.is_responsive and not result.is_final:
                lower = text.lower()
                now = time.time()

                # Backchannel once per utterance if we detect hesitation
                if not self.did_backchannel and any(k in lower for k in ["uh", "hmm", "...", "umm"]):
                    self.misty.start_action(name="concerned")
                    self.did_backchannel = True
                    self.log_event(event="backchannel_listen", partial=text)

                # Preload a hint if user seems to be asking/struggling
                if any(k in lower for k in ["hint", "help", "stuck", "don't know", "confused"]):
                    self.preload_hint = True
                    # optional tiny visual nudge
                    self.misty.start_action(name="concerned")
                    self.log_event(event="preload_hint_from_partial", partial=text)

                self.last_partial_ts = now
                return

            # --- FINAL hypothesis with speech_final detection ---
            if result.is_final:
                self.user_transcript_list.append(text)
                # Check if this is speech_final (endpointing detected silence)
                # Try multiple possible locations for speech_final flag
                speech_final = getattr(result, 'speech_final', None) or getattr(result.channel, 'speech_final', False)
                if speech_final:
                    utterance = " ".join(self.user_transcript_list).strip()
                    print(f"Speech Final: {utterance}")
                    self.log_event(event="final_transcript", text=utterance, preload_hint=self.preload_hint)
                    self.current_deepgram_transcript = utterance
                    self.user_transcript_list = []
                    self.deepgram_paused = True
                # We need to collect these and concatenate them together when we get a speech_final=true
                # See docs: https://developers.deepgram.com/docs/understand-endpointing-interim-results
                # Speech Final means we have detected sufficient silence to consider this end of speech
                # Speech final is the lowest latency result as it triggers as soon an the endpointing value has triggered
        def on_end(self_local, **kwargs):
            # Backup handler if speech_final doesn't fire
            if self.user_transcript_list and not self.deepgram_paused:
                utterance = " ".join(self.user_transcript_list).strip()
                print(f"UtteranceEnd fallback: {utterance}")
                self.log_event(event="final_transcript_utterance_end", text=utterance, preload_hint=self.preload_hint)
                self.current_deepgram_transcript = utterance
                self.user_transcript_list = []
                self.deepgram_paused = True


        def on_error(self_local, error, **kwargs):
            print(f"\n\n{error}\n\n")

        # STEP 4: Register the event handlers
        dg_connection.on(LiveTranscriptionEvents.Transcript, on_message)
        dg_connection.on(LiveTranscriptionEvents.UtteranceEnd, on_end)
        dg_connection.on(LiveTranscriptionEvents.Error, on_error)

        # STEP 5: Configure Deepgram options for live transcription
        # Adjust endpointing based on current stage - longer for log-reading tasks
        current_stage = self.stage_manager.get_current()
        if current_stage in ["task2"]:
            # Tasks 2 & 3: User reading logs - give more time before cutting off
            endpointing_ms = 500  # 500ms for reading cryptic log entries
            utterance_end_ms = 2000  # 2 seconds backup
        else:
            # Greeting, brief, task1: Normal conversation - fast turn-taking
            endpointing_ms = 200  # 200ms for snappy responses
            utterance_end_ms = 1000  # 1 second backup

        options = LiveOptions(
            model="nova-2",
            language="en-US",
            smart_format=True,
            interim_results=True,
            utterance_end_ms=utterance_end_ms,  # Backup/fallback; primary detection uses speech_final
            vad_events=True,
            endpointing=endpointing_ms
        )

        custom_options: dict = {"mip_opt_out": "true"}

        # STEP 6: Define a thread that streams the audio and sends it to Deepgram
        packet_size = 4096
        dg_connection.start(options, addons=custom_options)
        #sleep(.2) <--- put this back if needed
        self.aud_start = time.time()
        while not self.deepgram_paused == True:
            packet = self.op1.stdout.read(packet_size)
            dg_connection.send(packet)

        # STEP 7: Finish the connection and stop the Misty AV streaming

        # change the LED back to purple to indicate that the robot is not listening
        self.misty.change_led(100, 70, 160)
        
        dg_connection.finish()
        self.op2.communicate(str.encode("q"))
        self.op1.communicate(str.encode("q"))
        sleep(0.2) # used to be 1
        self.op2.terminate()
        self.op1.terminate()
        self.misty.stop_av_streaming()
        
        print("AV streaming and Deepgram STT stopped")


if __name__ == "__main__":

    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # get Misty IP address
    if len(sys.argv) != 2:
        print("Usage: python misty_introduction.py <Misty's IP Address>")
        sys.exit(1)
    misty_ip_address = sys.argv[1]

    misty_robot = None
    try:
        misty_robot = MistyRobot(misty_ip_address)
    except KeyboardInterrupt:
        print("\n[MistyGPT] Interrupted by user")
    finally:
        print("[MistyGPT] Cleaning up and exiting...")
        # Cleanup happens automatically: camera streaming stops, Deepgram closes, logs finalize
        if misty_robot:
            # Stop any ongoing audio/visual streams
            try:
                misty_robot.misty.stop_av_streaming()
            except:
                pass
            # Reset to neutral state
            try:
                misty_robot.misty.change_led(100, 70, 160)
                misty_robot.misty.display_image("e_DefaultContent.jpg")
            except:
                pass
        print("[MistyGPT] Session ended. Ready for next participant.")