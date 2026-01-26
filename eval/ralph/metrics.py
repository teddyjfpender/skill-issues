#!/usr/bin/env python3
"""
Metrics tracking for ralph loop runs.

This module provides functions to track and record metrics during code generation runs,
including timing, iterations, step progress, and error tracking.

Usage as module:
    from metrics import Metrics
    m = Metrics()
    m.start_run(prompt_id="test", rubric_id="test-rubric", ...)
    m.record_step(1, "completed", 5.2)
    m.record_iteration(1, "failed", errors=["syntax error"])
    m.end_run("pass")
    m.save_metrics("metrics.json")

Usage from command line:
    python3 metrics.py start --prompt-id <id> --rubric-id <id> --output <path> [options]
    python3 metrics.py step --metrics-path <path> --step-num <n> --status <status> --duration <secs> [--lint-warnings N] [--lint-fixed N]
    python3 metrics.py iteration --metrics-path <path> --attempt-num <n> --status <status>
    python3 metrics.py lint --metrics-path <path> --warnings-before <n> --warnings-after <n>
    python3 metrics.py end --metrics-path <path> --status <pass|fail|partial>
    python3 metrics.py summary --metrics-path <path>
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


def utc_now() -> str:
    """Return current UTC time as ISO 8601 string."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def utc_now_dt() -> datetime:
    """Return current UTC datetime."""
    return datetime.now(timezone.utc)


def parse_datetime(dt_str: str) -> datetime:
    """Parse ISO 8601 datetime string."""
    # Handle both with and without timezone
    if dt_str.endswith("Z"):
        dt_str = dt_str[:-1] + "+00:00"
    return datetime.fromisoformat(dt_str)


class Metrics:
    """Track and record metrics for a ralph loop run."""

    def __init__(self):
        self._data: Dict[str, Any] = {}
        self._start_dt: Optional[datetime] = None

    def start_run(
        self,
        prompt_id: str,
        rubric_id: str,
        driver_config: Optional[Dict[str, str]] = None,
        reviewer_config: Optional[Dict[str, str]] = None,
        skills: Optional[List[str]] = None,
        steps_total: int = 0,
        max_iterations: int = 5,
    ) -> None:
        """Initialize metrics for a new run.

        Args:
            prompt_id: Identifier for the prompt being processed
            rubric_id: Identifier for the rubric being used
            driver_config: Dict with 'backend' and 'model' keys for driver
            reviewer_config: Dict with 'backend' and 'model' keys for reviewer
            skills: List of skill names loaded
            steps_total: Total number of steps expected
            max_iterations: Maximum retry attempts allowed
        """
        driver_config = driver_config or {}
        reviewer_config = reviewer_config or {}
        skills = skills or []

        self._start_dt = utc_now_dt()

        self._data = {
            "prompt_id": prompt_id,
            "rubric_id": rubric_id,
            "start_time": utc_now(),
            "end_time": "",
            "duration_seconds": 0.0,
            "iterations": 0,
            "max_iterations": max_iterations,
            "steps_completed": 0,
            "steps_total": steps_total,
            "correctness": "running",
            "skills_used": skills,
            "driver_backend": driver_config.get("backend", ""),
            "driver_model": driver_config.get("model", ""),
            "reviewer_backend": reviewer_config.get("backend", ""),
            "reviewer_model": reviewer_config.get("model", ""),
            "tokens_estimated": 0,
            "errors_encountered": [],
            "step_details": [],
            "iteration_details": [],
            "lint": {
                "total_warnings": 0,
                "warnings_fixed": 0,
                "per_step": [],
            },
        }

    def record_step(
        self,
        step_num: int,
        status: str,
        duration: float,
        errors: Optional[List[str]] = None,
        lint_warnings: int = 0,
        lint_fixed: int = 0,
    ) -> None:
        """Record completion of a step.

        Args:
            step_num: Step number (1-indexed)
            status: Step status ('completed', 'failed', 'skipped')
            duration: Duration in seconds
            errors: Optional list of error messages
            lint_warnings: Number of lint warnings detected
            lint_fixed: Number of lint warnings fixed by --fix
        """
        errors = errors or []

        step_record = {
            "step": step_num,
            "status": status,
            "duration_seconds": duration,
            "timestamp": utc_now(),
            "errors": errors,
            "lint_warnings": lint_warnings,
            "lint_fixed": lint_fixed,
        }

        self._data["step_details"].append(step_record)

        # Update lint totals
        if lint_warnings > 0:
            self._data["lint"]["total_warnings"] += lint_warnings
            self._data["lint"]["warnings_fixed"] += lint_fixed
            self._data["lint"]["per_step"].append({
                "step": step_num,
                "warnings_before_fix": lint_warnings,
                "warnings_after_fix": lint_warnings - lint_fixed,
                "warnings_fixed": lint_fixed,
            })

        if status == "completed":
            self._data["steps_completed"] = max(
                self._data["steps_completed"], step_num
            )

        # Track unique error types
        for error in errors:
            error_type = self._classify_error(error)
            if error_type not in self._data["errors_encountered"]:
                self._data["errors_encountered"].append(error_type)

    def record_lint(
        self,
        warnings_before: int,
        warnings_after: int,
    ) -> None:
        """Record lint warnings for the current step.

        Args:
            warnings_before: Number of warnings before any fix
            warnings_after: Number of warnings after fix (if fix was run)
        """
        warnings_fixed = warnings_before - warnings_after

        # Update totals
        self._data["lint"]["total_warnings"] += warnings_before
        self._data["lint"]["warnings_fixed"] += warnings_fixed

    def record_iteration(
        self,
        attempt_num: int,
        status: str,
        errors: Optional[List[str]] = None,
        duration: float = 0.0,
    ) -> None:
        """Record an iteration/retry attempt.

        Args:
            attempt_num: Attempt number (1-indexed)
            status: Iteration status ('success', 'failed', 'timeout')
            errors: Optional list of error messages
            duration: Optional duration in seconds
        """
        errors = errors or []

        iteration_record = {
            "attempt": attempt_num,
            "status": status,
            "duration_seconds": duration,
            "timestamp": utc_now(),
            "errors": errors,
        }

        self._data["iteration_details"].append(iteration_record)
        self._data["iterations"] = max(self._data["iterations"], attempt_num)

        # Track unique error types
        for error in errors:
            error_type = self._classify_error(error)
            if error_type not in self._data["errors_encountered"]:
                self._data["errors_encountered"].append(error_type)

    def end_run(
        self,
        final_status: str,
        final_code_path: Optional[str] = None,
        steps_completed: Optional[int] = None,
        best_code_path: Optional[str] = None,
    ) -> None:
        """Finalize metrics after run completion.

        Args:
            final_status: Final status ('pass', 'fail', 'partial')
            final_code_path: Optional path to final generated code
            steps_completed: Optional override for steps completed count (for partial runs)
            best_code_path: Optional path to best code achieved (for failed runs)
        """
        end_dt = utc_now_dt()
        self._data["end_time"] = utc_now()

        if self._start_dt:
            duration = (end_dt - self._start_dt).total_seconds()
            self._data["duration_seconds"] = round(duration, 2)

        self._data["correctness"] = final_status

        if final_code_path:
            self._data["final_code_path"] = final_code_path

        # For partial/failed runs, track the best code achieved
        if steps_completed is not None:
            self._data["steps_completed"] = steps_completed

        if best_code_path:
            self._data["best_code_path"] = best_code_path

    def set_tokens_estimated(self, tokens: int) -> None:
        """Set the estimated token count for prompts.

        Args:
            tokens: Estimated token count
        """
        self._data["tokens_estimated"] = tokens

    def save_metrics(self, output_path: str) -> None:
        """Save metrics to a JSON file.

        Args:
            output_path: Path to output JSON file
        """
        os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(self._data, f, indent=2)
            f.write("\n")

    def to_dict(self) -> Dict[str, Any]:
        """Return metrics as a dictionary."""
        return self._data.copy()

    def summary(self) -> str:
        """Return a human-readable summary string.

        Returns:
            Formatted summary of the metrics
        """
        data = self._data
        lines = [
            "=" * 50,
            "RALPH LOOP METRICS SUMMARY",
            "=" * 50,
            "",
            f"Prompt: {data.get('prompt_id', 'N/A')}",
            f"Rubric: {data.get('rubric_id', 'N/A')}",
            "",
            "--- Timing ---",
            f"Start:    {data.get('start_time', 'N/A')}",
            f"End:      {data.get('end_time', 'N/A')}",
            f"Duration: {data.get('duration_seconds', 0):.2f} seconds",
            "",
            "--- Progress ---",
            f"Steps:      {data.get('steps_completed', 0)} / {data.get('steps_total', 0)} completed",
            f"Iterations: {data.get('iterations', 0)} / {data.get('max_iterations', 0)} used",
            f"Result:     {data.get('correctness', 'unknown').upper()}",
            "",
            "--- Configuration ---",
            f"Driver:   {data.get('driver_backend', 'N/A')} / {data.get('driver_model', 'N/A')}",
            f"Reviewer: {data.get('reviewer_backend', 'N/A')} / {data.get('reviewer_model', 'N/A')}",
            f"Skills:   {', '.join(data.get('skills_used', [])) or 'none'}",
            "",
            "--- Tokens ---",
            f"Estimated: {data.get('tokens_estimated', 0):,}",
            "",
        ]

        errors = data.get("errors_encountered", [])
        if errors:
            lines.append("--- Errors Encountered ---")
            for err in errors:
                lines.append(f"  - {err}")
            lines.append("")

        # Lint statistics
        lint_data = data.get("lint", {})
        total_warnings = lint_data.get("total_warnings", 0)
        warnings_fixed = lint_data.get("warnings_fixed", 0)
        if total_warnings > 0 or warnings_fixed > 0:
            lines.append("--- Lint Statistics ---")
            lines.append(f"Total Warnings: {total_warnings}")
            lines.append(f"Warnings Fixed: {warnings_fixed}")
            warnings_remaining = total_warnings - warnings_fixed
            lines.append(f"Warnings Remaining: {warnings_remaining}")
            per_step = lint_data.get("per_step", [])
            if per_step:
                lines.append("Per-step breakdown:")
                for step_lint in per_step:
                    step = step_lint.get("step", "?")
                    before = step_lint.get("warnings_before_fix", 0)
                    after = step_lint.get("warnings_after_fix", 0)
                    fixed = step_lint.get("warnings_fixed", 0)
                    lines.append(f"  Step {step}: {before} warnings ({fixed} fixed, {after} remaining)")
            lines.append("")

        lines.append("=" * 50)

        return "\n".join(lines)

    def _classify_error(self, error_msg: str) -> str:
        """Classify an error message into a category.

        Args:
            error_msg: Raw error message

        Returns:
            Error category string
        """
        error_lower = error_msg.lower()

        if "timeout" in error_lower:
            return "timeout"
        elif "syntax" in error_lower or "parse" in error_lower:
            return "syntax_error"
        elif "import" in error_lower or "module" in error_lower:
            return "import_error"
        elif "type" in error_lower and ("mismatch" in error_lower or "expected" in error_lower):
            return "type_error"
        elif "undefined" in error_lower or "not found" in error_lower:
            return "undefined_reference"
        elif "test" in error_lower and ("fail" in error_lower or "assert" in error_lower):
            return "test_failure"
        elif "build" in error_lower or "compile" in error_lower:
            return "build_error"
        elif "network" in error_lower or "connection" in error_lower:
            return "network_error"
        else:
            return "other_error"


def load_metrics(input_path: str) -> Metrics:
    """Load metrics from a JSON file.

    Args:
        input_path: Path to input JSON file

    Returns:
        Metrics object with loaded data
    """
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    m = Metrics()
    m._data = data

    # Restore start datetime if available
    if data.get("start_time"):
        try:
            m._start_dt = parse_datetime(data["start_time"])
        except (ValueError, TypeError):
            pass

    return m


# =============================================================================
# Command-line interface
# =============================================================================

def cmd_start(args):
    """Handle 'start' command."""
    skills = []
    if args.skills:
        skills = [s.strip() for s in args.skills.split(",") if s.strip()]

    driver_config = {
        "backend": args.driver_backend or "",
        "model": args.driver_model or "",
    }
    reviewer_config = {
        "backend": args.reviewer_backend or "",
        "model": args.reviewer_model or "",
    }

    m = Metrics()
    m.start_run(
        prompt_id=args.prompt_id,
        rubric_id=args.rubric_id,
        driver_config=driver_config,
        reviewer_config=reviewer_config,
        skills=skills,
        steps_total=args.steps_total,
        max_iterations=args.max_iterations,
    )

    if args.tokens:
        m.set_tokens_estimated(args.tokens)

    m.save_metrics(args.output)
    print(f"Initialized metrics at {args.output}")


def cmd_step(args):
    """Handle 'step' command."""
    m = load_metrics(args.metrics_path)

    errors = []
    if args.errors:
        try:
            errors = json.loads(args.errors)
        except json.JSONDecodeError:
            errors = [args.errors]

    lint_warnings = args.lint_warnings if args.lint_warnings else 0
    lint_fixed = args.lint_fixed if args.lint_fixed else 0

    m.record_step(
        step_num=args.step_num,
        status=args.status,
        duration=args.duration,
        errors=errors,
        lint_warnings=lint_warnings,
        lint_fixed=lint_fixed,
    )
    m.save_metrics(args.metrics_path)
    print(f"Recorded step {args.step_num}: {args.status}")


def cmd_iteration(args):
    """Handle 'iteration' command."""
    m = load_metrics(args.metrics_path)

    errors = []
    if args.errors:
        try:
            errors = json.loads(args.errors)
        except json.JSONDecodeError:
            errors = [args.errors]

    m.record_iteration(
        attempt_num=args.attempt_num,
        status=args.status,
        errors=errors,
        duration=args.duration or 0.0,
    )
    m.save_metrics(args.metrics_path)
    print(f"Recorded iteration {args.attempt_num}: {args.status}")


def cmd_end(args):
    """Handle 'end' command."""
    m = load_metrics(args.metrics_path)
    m.end_run(
        final_status=args.status,
        final_code_path=args.final_code,
        steps_completed=args.steps_completed,
        best_code_path=args.best_code,
    )
    m.save_metrics(args.metrics_path)
    print(f"Finalized metrics with status: {args.status}")


def cmd_lint(args):
    """Handle 'lint' command."""
    m = load_metrics(args.metrics_path)
    m.record_lint(
        warnings_before=args.warnings_before,
        warnings_after=args.warnings_after,
    )
    m.save_metrics(args.metrics_path)
    warnings_fixed = args.warnings_before - args.warnings_after
    print(f"Recorded lint: {args.warnings_before} warnings, {warnings_fixed} fixed")


def cmd_summary(args):
    """Handle 'summary' command."""
    m = load_metrics(args.metrics_path)
    print(m.summary())


def main():
    parser = argparse.ArgumentParser(
        description="Track and record metrics for ralph loop runs"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # start
    p_start = subparsers.add_parser("start", help="Initialize metrics for a new run")
    p_start.add_argument("--prompt-id", required=True, help="Prompt identifier")
    p_start.add_argument("--rubric-id", required=True, help="Rubric identifier")
    p_start.add_argument("--output", required=True, help="Output path for metrics.json")
    p_start.add_argument("--driver-backend", help="Driver backend (codex/claude)")
    p_start.add_argument("--driver-model", help="Driver model name")
    p_start.add_argument("--reviewer-backend", help="Reviewer backend (codex/claude)")
    p_start.add_argument("--reviewer-model", help="Reviewer model name")
    p_start.add_argument("--skills", help="Comma-separated list of skills")
    p_start.add_argument("--steps-total", type=int, default=0, help="Total steps expected")
    p_start.add_argument("--max-iterations", type=int, default=5, help="Max iterations")
    p_start.add_argument("--tokens", type=int, default=0, help="Estimated token count")
    p_start.set_defaults(func=cmd_start)

    # step
    p_step = subparsers.add_parser("step", help="Record a step completion")
    p_step.add_argument("--metrics-path", required=True, help="Path to metrics.json")
    p_step.add_argument("--step-num", type=int, required=True, help="Step number")
    p_step.add_argument("--status", required=True, choices=["completed", "failed", "skipped"])
    p_step.add_argument("--duration", type=float, required=True, help="Duration in seconds")
    p_step.add_argument("--errors", help="JSON array or single error string")
    p_step.add_argument("--lint-warnings", type=int, help="Number of lint warnings detected")
    p_step.add_argument("--lint-fixed", type=int, help="Number of lint warnings fixed by --fix")
    p_step.set_defaults(func=cmd_step)

    # iteration
    p_iter = subparsers.add_parser("iteration", help="Record an iteration attempt")
    p_iter.add_argument("--metrics-path", required=True, help="Path to metrics.json")
    p_iter.add_argument("--attempt-num", type=int, required=True, help="Attempt number")
    p_iter.add_argument("--status", required=True, choices=["success", "failed", "timeout"])
    p_iter.add_argument("--errors", help="JSON array or single error string")
    p_iter.add_argument("--duration", type=float, help="Duration in seconds")
    p_iter.set_defaults(func=cmd_iteration)

    # end
    p_end = subparsers.add_parser("end", help="Finalize metrics")
    p_end.add_argument("--metrics-path", required=True, help="Path to metrics.json")
    p_end.add_argument("--status", required=True, choices=["pass", "fail", "partial"])
    p_end.add_argument("--final-code", help="Path to final generated code")
    p_end.add_argument("--steps-completed", type=int, help="Override steps completed count (for partial runs)")
    p_end.add_argument("--best-code", help="Path to best code achieved (for failed runs)")
    p_end.set_defaults(func=cmd_end)

    # lint
    p_lint = subparsers.add_parser("lint", help="Record lint warnings")
    p_lint.add_argument("--metrics-path", required=True, help="Path to metrics.json")
    p_lint.add_argument("--warnings-before", type=int, required=True, help="Number of warnings before fix")
    p_lint.add_argument("--warnings-after", type=int, required=True, help="Number of warnings after fix")
    p_lint.set_defaults(func=cmd_lint)

    # summary
    p_summary = subparsers.add_parser("summary", help="Print human-readable summary")
    p_summary.add_argument("--metrics-path", required=True, help="Path to metrics.json")
    p_summary.set_defaults(func=cmd_summary)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
