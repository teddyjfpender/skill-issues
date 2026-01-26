#!/usr/bin/env python3
"""
Manage history.json for ralph-loop.

Usage:
  update-history.py init <history_path> <prompt_id> --config <config_json>
  update-history.py start-attempt <history_path> <attempt_num>
  update-history.py set-driver <history_path> <attempt_num> --code-path <path> [--notes <notes>] [--exit-code <code>]
  update-history.py set-review <history_path> <attempt_num> --verdict <verdict> [--issues <json>] [--notes <notes>]
  update-history.py set-verify <history_path> <attempt_num> --status <status> [--failed-steps <json>] [--path <path>]
  update-history.py set-feedback <history_path> <attempt_num> --source <src> [--summary <text>] [--errors <json>] [--hints <json>]
  update-history.py end-attempt <history_path> <attempt_num>
  update-history.py finish <history_path> --status <status> [--successful-attempt <num>]
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_history(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_history(path: str, data: dict):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def get_attempt(history: dict, num: int) -> dict:
    for attempt in history["attempts"]:
        if attempt["number"] == num:
            return attempt
    raise ValueError(f"Attempt {num} not found")


def cmd_init(args):
    config = json.loads(args.config) if args.config else {}
    history = {
        "prompt_id": args.prompt_id,
        "prompt_path": config.get("prompt_path", ""),
        "rubric_path": config.get("rubric_path", ""),
        "started_at": utc_now(),
        "ended_at": "",
        "status": "running",
        "successful_attempt": None,
        "config": {
            "max_attempts": config.get("max_attempts", 5),
            "driver_backend": config.get("driver_backend", "codex"),
            "driver_model": config.get("driver_model", ""),
            "driver_skills": config.get("driver_skills", []),
            "reviewer_backend": config.get("reviewer_backend", "codex"),
            "reviewer_model": config.get("reviewer_model", ""),
            "reviewer_skills": config.get("reviewer_skills", []),
            "pre_validate": config.get("pre_validate", False),
            "timeout": config.get("timeout", 120),
        },
        "attempts": [],
    }
    save_history(args.history_path, history)
    print(f"Initialized history at {args.history_path}")


def cmd_start_attempt(args):
    history = load_history(args.history_path)
    attempt = {
        "number": args.attempt_num,
        "started_at": utc_now(),
        "ended_at": "",
        "driver_result": {},
        "review_result": {},
        "verify_result": {},
        "feedback": {},
    }
    history["attempts"].append(attempt)
    save_history(args.history_path, history)
    print(f"Started attempt {args.attempt_num}")


def cmd_set_driver(args):
    history = load_history(args.history_path)
    attempt = get_attempt(history, args.attempt_num)
    attempt["driver_result"] = {
        "code_path": args.code_path or "",
        "notes": args.notes or "",
        "exit_code": args.exit_code if args.exit_code is not None else 0,
    }
    save_history(args.history_path, history)
    print(f"Set driver result for attempt {args.attempt_num}")


def cmd_set_review(args):
    history = load_history(args.history_path)
    attempt = get_attempt(history, args.attempt_num)
    issues = json.loads(args.issues) if args.issues else []
    attempt["review_result"] = {
        "verdict": args.verdict,
        "issues": issues,
        "notes": args.notes or "",
    }
    save_history(args.history_path, history)
    print(f"Set review result for attempt {args.attempt_num}")


def cmd_set_verify(args):
    history = load_history(args.history_path)
    attempt = get_attempt(history, args.attempt_num)
    failed_steps = json.loads(args.failed_steps) if args.failed_steps else []
    attempt["verify_result"] = {
        "status": args.status,
        "failed_steps": failed_steps,
        "verify_json_path": args.path or "",
    }
    save_history(args.history_path, history)
    print(f"Set verify result for attempt {args.attempt_num}")


def cmd_set_feedback(args):
    history = load_history(args.history_path)
    attempt = get_attempt(history, args.attempt_num)
    errors = json.loads(args.errors) if args.errors else []
    hints = json.loads(args.hints) if args.hints else []
    attempt["feedback"] = {
        "source": args.source,
        "summary": args.summary or "",
        "errors": errors,
        "actionable_hints": hints,
    }
    save_history(args.history_path, history)
    print(f"Set feedback for attempt {args.attempt_num}")


def cmd_end_attempt(args):
    history = load_history(args.history_path)
    attempt = get_attempt(history, args.attempt_num)
    attempt["ended_at"] = utc_now()
    save_history(args.history_path, history)
    print(f"Ended attempt {args.attempt_num}")


def cmd_finish(args):
    history = load_history(args.history_path)
    history["status"] = args.status
    history["ended_at"] = utc_now()
    if args.successful_attempt is not None:
        history["successful_attempt"] = args.successful_attempt
    save_history(args.history_path, history)
    print(f"Finished loop with status: {args.status}")


def main():
    parser = argparse.ArgumentParser(description="Manage ralph-loop history.json")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # init
    p_init = subparsers.add_parser("init", help="Initialize new history.json")
    p_init.add_argument("history_path", help="Path to history.json")
    p_init.add_argument("prompt_id", help="Prompt identifier")
    p_init.add_argument("--config", help="JSON string with config options")
    p_init.set_defaults(func=cmd_init)

    # start-attempt
    p_start = subparsers.add_parser("start-attempt", help="Start a new attempt")
    p_start.add_argument("history_path", help="Path to history.json")
    p_start.add_argument("attempt_num", type=int, help="Attempt number")
    p_start.set_defaults(func=cmd_start_attempt)

    # set-driver
    p_driver = subparsers.add_parser("set-driver", help="Set driver result")
    p_driver.add_argument("history_path", help="Path to history.json")
    p_driver.add_argument("attempt_num", type=int, help="Attempt number")
    p_driver.add_argument("--code-path", help="Path to generated code")
    p_driver.add_argument("--notes", help="Driver notes")
    p_driver.add_argument("--exit-code", type=int, help="Exit code")
    p_driver.set_defaults(func=cmd_set_driver)

    # set-review
    p_review = subparsers.add_parser("set-review", help="Set review result")
    p_review.add_argument("history_path", help="Path to history.json")
    p_review.add_argument("attempt_num", type=int, help="Attempt number")
    p_review.add_argument("--verdict", required=True, choices=["VALID", "INVALID", "UNFIXABLE"])
    p_review.add_argument("--issues", help="JSON array of issues")
    p_review.add_argument("--notes", help="Reviewer notes")
    p_review.set_defaults(func=cmd_set_review)

    # set-verify
    p_verify = subparsers.add_parser("set-verify", help="Set verify result")
    p_verify.add_argument("history_path", help="Path to history.json")
    p_verify.add_argument("attempt_num", type=int, help="Attempt number")
    p_verify.add_argument("--status", required=True, choices=["pass", "fail"])
    p_verify.add_argument("--failed-steps", help="JSON array of failed step names")
    p_verify.add_argument("--path", help="Path to verify.json")
    p_verify.set_defaults(func=cmd_set_verify)

    # set-feedback
    p_feedback = subparsers.add_parser("set-feedback", help="Set feedback for next attempt")
    p_feedback.add_argument("history_path", help="Path to history.json")
    p_feedback.add_argument("attempt_num", type=int, help="Attempt number")
    p_feedback.add_argument("--source", required=True, choices=["reviewer", "format", "build", "test"])
    p_feedback.add_argument("--summary", help="Brief summary")
    p_feedback.add_argument("--errors", help="JSON array of error messages")
    p_feedback.add_argument("--hints", help="JSON array of actionable hints")
    p_feedback.set_defaults(func=cmd_set_feedback)

    # end-attempt
    p_end = subparsers.add_parser("end-attempt", help="Mark attempt as ended")
    p_end.add_argument("history_path", help="Path to history.json")
    p_end.add_argument("attempt_num", type=int, help="Attempt number")
    p_end.set_defaults(func=cmd_end_attempt)

    # finish
    p_finish = subparsers.add_parser("finish", help="Mark loop as finished")
    p_finish.add_argument("history_path", help="Path to history.json")
    p_finish.add_argument("--status", required=True, choices=["success", "failure", "unfixable"])
    p_finish.add_argument("--successful-attempt", type=int, help="Which attempt succeeded")
    p_finish.set_defaults(func=cmd_finish)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
