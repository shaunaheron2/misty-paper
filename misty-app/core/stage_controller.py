#!/usr/bin/env python3
"""
Stage Controller - Manual stage management for experiment control
Allows facilitator to manually advance or rollback stages during the experiment
"""

import requests
import sys

FLASK_URL = "http://127.0.0.1:5000"
VALID_STAGES = ["greeting", "brief", "task1", "task2", "wrap"]

def get_current_stage():
    """Get the current stage from Flask GUI"""
    try:
        response = requests.get(f"{FLASK_URL}/stage_current", timeout=1)
        return response.json().get('stage', 'unknown')
    except Exception as e:
        print(f"❌ Error getting current stage: {e}")
        return None

def set_stage(stage):
    """Set the stage (advance or rollback)"""
    if stage not in VALID_STAGES:
        print(f"❌ Invalid stage: {stage}")
        print(f"   Valid stages: {', '.join(VALID_STAGES)}")
        return False

    try:
        response = requests.post(f"{FLASK_URL}/stage", json={"stage": stage}, timeout=1)
        if response.status_code in (200, 204):
            print(f"✓ Stage set to: {stage}")
            return True
        else:
            print(f"❌ Failed to set stage: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Error setting stage: {e}")
        return False

def rollback_stage(stage):
    """Rollback to a previous stage using the rollback endpoint"""
    if stage not in VALID_STAGES:
        print(f"❌ Invalid stage: {stage}")
        print(f"   Valid stages: {', '.join(VALID_STAGES)}")
        return False

    try:
        response = requests.post(f"{FLASK_URL}/stage_rollback", json={"stage": stage}, timeout=1)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Stage rolled back: {data['old_stage']} → {data['new_stage']}")
            return True
        else:
            print(f"❌ Failed to rollback stage: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Error rolling back stage: {e}")
        return False

def print_help():
    """Print usage instructions"""
    print("\n" + "="*80)
    print("STAGE CONTROLLER - Manual Experiment Stage Management")
    print("="*80)
    print("\nUsage:")
    print("  python stage_controller.py [command] [stage]")
    print("\nCommands:")
    print("  status          - Show current stage")
    print("  set <stage>     - Set stage (advance or rollback)")
    print("  rollback <stage> - Rollback to previous stage (emergency use)")
    print("\nValid Stages:")
    print(f"  {', '.join(VALID_STAGES)}")
    print("\nExamples:")
    print("  python stage_controller.py status")
    print("  python stage_controller.py set task1")
    print("  python stage_controller.py rollback brief")
    print("\nNote: Flask GUI must be running at http://127.0.0.1:5000")
    print("="*80 + "\n")

def main():
    if len(sys.argv) < 2:
        print_help()
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "status":
        current = get_current_stage()
        if current:
            print(f"\n{'='*80}")
            print(f"Current Stage: {current}")
            print(f"{'='*80}\n")

    elif command == "set":
        if len(sys.argv) < 3:
            print("❌ Error: Missing stage argument")
            print("   Usage: python stage_controller.py set <stage>")
            sys.exit(1)

        new_stage = sys.argv[2].lower()
        current = get_current_stage()

        if current:
            print(f"\n{'='*80}")
            print(f"⚠️  Changing Stage: {current} → {new_stage}")
            print(f"{'='*80}\n")

            confirm = input("Continue? (y/n): ").lower()
            if confirm == 'y':
                set_stage(new_stage)
            else:
                print("❌ Cancelled")

    elif command == "rollback":
        if len(sys.argv) < 3:
            print("❌ Error: Missing stage argument")
            print("   Usage: python stage_controller.py rollback <stage>")
            sys.exit(1)

        new_stage = sys.argv[2].lower()
        current = get_current_stage()

        if current:
            print(f"\n{'='*80}")
            print(f"⚠️  ROLLING BACK STAGE: {current} → {new_stage}")
            print(f"   This will affect both the robot and GUI")
            print(f"{'='*80}\n")

            confirm = input("Are you sure? (y/n): ").lower()
            if confirm == 'y':
                rollback_stage(new_stage)
            else:
                print("❌ Cancelled")

    else:
        print(f"❌ Unknown command: {command}")
        print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
