"""
Simple DuckDB logger for experimental data collection.
Logs participant responses, dialogue turns, timing, and events.
"""

import duckdb
import os
from datetime import datetime
from typing import Optional, Dict, Any


class ExperimentLogger:
    def __init__(self, db_path: str = "experiment_data.duckdb"):
        self.db_path = db_path
        # Don't keep persistent connection - open/close as needed
        self._create_tables()

    def _get_connection(self):
        """Get a new database connection."""
        return duckdb.connect(self.db_path)

    def _create_tables(self):
        """Create tables if they don't exist."""
        conn = self._get_connection()
        try:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    session_id VARCHAR PRIMARY KEY,
                    participant_name VARCHAR,
                    mode VARCHAR,  -- RESPONSIVE or CONTROL
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    total_duration_seconds INTEGER,
                    completed BOOLEAN DEFAULT FALSE
                )
            """)

            conn.execute("""
                CREATE TABLE IF NOT EXISTS task_responses (
                    id INTEGER PRIMARY KEY,
                    session_id VARCHAR,
                    task_name VARCHAR,  -- task1, task2, task3
                    response_data JSON,  -- Store all task answers as JSON
                    submitted_at TIMESTAMP,
                    time_spent_seconds INTEGER,
                    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
                )
            """)

            conn.execute("""
                CREATE TABLE IF NOT EXISTS dialogue_turns (
                    id INTEGER PRIMARY KEY,
                    session_id VARCHAR,
                    turn_number INTEGER,
                    timestamp TIMESTAMP,
                    stage VARCHAR,
                    user_input TEXT,
                    llm_response TEXT,
                    expression VARCHAR,
                    response_time_ms INTEGER,
                    flags TEXT,  -- comma-separated flags like "hint_requested,backchannel"
                    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
                )
            """)

            conn.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id INTEGER PRIMARY KEY,
                    session_id VARCHAR,
                    timestamp TIMESTAMP,
                    event_type VARCHAR,  -- stage_change, silence_check, error, etc.
                    event_data JSON,
                    FOREIGN KEY (session_id) REFERENCES sessions(session_id)
                )
            """)

            # Create sequence for auto-incrementing IDs
            conn.execute("CREATE SEQUENCE IF NOT EXISTS seq_task_responses START 1")
            conn.execute("CREATE SEQUENCE IF NOT EXISTS seq_dialogue START 1")
            conn.execute("CREATE SEQUENCE IF NOT EXISTS seq_events START 1")
            conn.commit()
        finally:
            conn.close()

    def start_session(self, session_id: str, mode: str, participant_name: Optional[str] = None):
        """Start a new experimental session. If session already exists, skip creation."""
        conn = self._get_connection()
        try:
            # Check if session already exists
            existing = conn.execute("""
                SELECT session_id FROM sessions WHERE session_id = ?
            """, [session_id]).fetchone()

            if not existing:
                # Only insert if session doesn't exist
                conn.execute("""
                    INSERT INTO sessions (session_id, participant_name, mode, start_time, completed)
                    VALUES (?, ?, ?, ?, FALSE)
                """, [session_id, participant_name, mode, datetime.now()])
                conn.commit()
        finally:
            conn.close()

    def end_session(self, session_id: str):
        """Mark session as completed and calculate duration."""
        conn = self._get_connection()
        try:
            conn.execute("""
                UPDATE sessions
                SET end_time = ?,
                    total_duration_seconds = EXTRACT(EPOCH FROM (? - start_time)),
                    completed = TRUE
                WHERE session_id = ?
            """, [datetime.now(), datetime.now(), session_id])
            conn.commit()
        finally:
            conn.close()

    def log_task_response(self, session_id: str, task_name: str, response_data: Dict[str, Any], time_spent: int):
        """Log a task response (suspect ID, status determination, location)."""
        import json
        conn = self._get_connection()
        try:
            conn.execute("""
                INSERT INTO task_responses (id, session_id, task_name, response_data, submitted_at, time_spent_seconds)
                VALUES (nextval('seq_task_responses'), ?, ?, ?, ?, ?)
            """, [session_id, task_name, json.dumps(response_data), datetime.now(), time_spent])
            conn.commit()
        finally:
            conn.close()

    def log_dialogue_turn(self, session_id: str, turn_number: int, stage: str,
                         user_input: str, llm_response: str, expression: str,
                         response_time_ms: int = 0, flags: str = ""):
        """Log a single dialogue turn."""
        conn = self._get_connection()
        try:
            conn.execute("""
                INSERT INTO dialogue_turns (id, session_id, turn_number, timestamp, stage,
                                           user_input, llm_response, expression, response_time_ms, flags)
                VALUES (nextval('seq_dialogue'), ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [session_id, turn_number, datetime.now(), stage, user_input, llm_response,
                  expression, response_time_ms, flags])
            conn.commit()
        finally:
            conn.close()

    def log_event(self, session_id: str, event_type: str, event_data: Dict[str, Any]):
        """Log a generic event (stage change, silence check, etc)."""
        import json
        conn = self._get_connection()
        try:
            conn.execute("""
                INSERT INTO events (id, session_id, timestamp, event_type, event_data)
                VALUES (nextval('seq_events'), ?, ?, ?, ?)
            """, [session_id, datetime.now(), event_type, json.dumps(event_data)])
            conn.commit()
        finally:
            conn.close()

    def get_next_participant_id(self) -> str:
        """Generate next sequential participant ID (P01, P02, P03, ...)."""
        conn = self._get_connection()
        try:
            # Get all session IDs that match pattern P##
            result = conn.execute("""
                SELECT session_id FROM sessions
                WHERE session_id LIKE 'P%'
                ORDER BY session_id DESC
                LIMIT 1
            """).fetchone()

            if not result:
                # No previous sessions, start with P01
                return "P01"

            last_id = result[0]
            # Extract number from P## format
            try:
                num = int(last_id[1:])
                next_num = num + 1
                return f"P{next_num:02d}"
            except (ValueError, IndexError):
                # Fallback if format is unexpected
                return "P01"
        finally:
            conn.close()

    def get_session_summary(self, session_id: str) -> Dict[str, Any]:
        """Get a summary of a session for analysis."""
        conn = self._get_connection()
        try:
            session = conn.execute("""
                SELECT * FROM sessions WHERE session_id = ?
            """, [session_id]).fetchone()

            if not session:
                return {}

            dialogue_count = conn.execute("""
                SELECT COUNT(*) FROM dialogue_turns WHERE session_id = ?
            """, [session_id]).fetchone()[0]

            responses = conn.execute("""
                SELECT task_name, response_data, time_spent_seconds
                FROM task_responses
                WHERE session_id = ?
                ORDER BY submitted_at
            """, [session_id]).fetchall()

            return {
                "session_id": session[0],
                "participant_name": session[1],
                "mode": session[2],
                "duration_seconds": session[5],
                "dialogue_turns": dialogue_count,
                "task_responses": responses
            }
        finally:
            conn.close()

    def close(self):
        """Close the database connection (no-op with connection-per-operation pattern)."""
        pass  # Connections are closed after each operation


# Singleton instance
_logger_instance = None

def get_logger(db_path: str = "experiment_data.duckdb") -> ExperimentLogger:
    """Get or create the singleton logger instance."""
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = ExperimentLogger(db_path)
    return _logger_instance
