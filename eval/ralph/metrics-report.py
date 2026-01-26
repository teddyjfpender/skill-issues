#!/usr/bin/env python3
"""
Generate summary reports from ralph loop metrics files.

This script reads one or more metrics.json files and produces aggregate statistics
and summaries across multiple runs.

Usage:
    # Single file summary
    python3 metrics-report.py metrics.json

    # Multiple files summary
    python3 metrics-report.py run1/metrics.json run2/metrics.json

    # Glob pattern (quoted to prevent shell expansion)
    python3 metrics-report.py '.ralph/*/metrics.json'

    # Output as JSON
    python3 metrics-report.py --format json metrics.json

    # Find all metrics files in a directory
    python3 metrics-report.py --find-in .ralph/
"""

import argparse
import glob
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional


def load_metrics(path: str) -> Optional[Dict[str, Any]]:
    """Load a metrics.json file.

    Args:
        path: Path to the metrics.json file

    Returns:
        Dict with metrics data, or None if file is invalid
    """
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        print(f"Warning: Could not load {path}: {e}", file=sys.stderr)
        return None


def format_duration(seconds: float) -> str:
    """Format duration in human-readable form.

    Args:
        seconds: Duration in seconds

    Returns:
        Formatted string like "1m 30s" or "45s"
    """
    if seconds < 60:
        return f"{seconds:.1f}s"
    elif seconds < 3600:
        mins = int(seconds // 60)
        secs = seconds % 60
        return f"{mins}m {secs:.0f}s"
    else:
        hours = int(seconds // 3600)
        mins = int((seconds % 3600) // 60)
        return f"{hours}h {mins}m"


def calculate_statistics(metrics_list: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Calculate aggregate statistics from multiple metrics.

    Args:
        metrics_list: List of metrics dictionaries

    Returns:
        Dict with aggregate statistics
    """
    if not metrics_list:
        return {}

    # Counts by status
    status_counts = {"pass": 0, "fail": 0, "partial": 0, "running": 0}
    for m in metrics_list:
        status = m.get("correctness", "unknown")
        if status in status_counts:
            status_counts[status] += 1

    # Timing statistics
    durations = [m.get("duration_seconds", 0) for m in metrics_list if m.get("duration_seconds", 0) > 0]
    avg_duration = sum(durations) / len(durations) if durations else 0
    min_duration = min(durations) if durations else 0
    max_duration = max(durations) if durations else 0
    total_duration = sum(durations)

    # Iteration statistics
    iterations = [m.get("iterations", 0) for m in metrics_list]
    avg_iterations = sum(iterations) / len(iterations) if iterations else 0
    max_iterations_used = max(iterations) if iterations else 0

    # Step statistics
    steps_completed = [m.get("steps_completed", 0) for m in metrics_list]
    steps_total = [m.get("steps_total", 0) for m in metrics_list]
    total_steps_completed = sum(steps_completed)
    total_steps_expected = sum(steps_total)

    # Error statistics
    all_errors: Dict[str, int] = {}
    for m in metrics_list:
        for error in m.get("errors_encountered", []):
            all_errors[error] = all_errors.get(error, 0) + 1

    # Token statistics
    tokens = [m.get("tokens_estimated", 0) for m in metrics_list if m.get("tokens_estimated", 0) > 0]
    total_tokens = sum(tokens)
    avg_tokens = total_tokens // len(tokens) if tokens else 0

    # Model usage
    driver_backends: Dict[str, int] = {}
    driver_models: Dict[str, int] = {}
    reviewer_backends: Dict[str, int] = {}
    reviewer_models: Dict[str, int] = {}

    for m in metrics_list:
        db = m.get("driver_backend", "")
        if db:
            driver_backends[db] = driver_backends.get(db, 0) + 1
        dm = m.get("driver_model", "")
        if dm:
            driver_models[dm] = driver_models.get(dm, 0) + 1
        rb = m.get("reviewer_backend", "")
        if rb:
            reviewer_backends[rb] = reviewer_backends.get(rb, 0) + 1
        rm = m.get("reviewer_model", "")
        if rm:
            reviewer_models[rm] = reviewer_models.get(rm, 0) + 1

    # Skills usage
    skills_used: Dict[str, int] = {}
    for m in metrics_list:
        for skill in m.get("skills_used", []):
            skills_used[skill] = skills_used.get(skill, 0) + 1

    return {
        "total_runs": len(metrics_list),
        "status_counts": status_counts,
        "pass_rate": status_counts["pass"] / len(metrics_list) if metrics_list else 0,
        "timing": {
            "total_seconds": total_duration,
            "average_seconds": avg_duration,
            "min_seconds": min_duration,
            "max_seconds": max_duration,
        },
        "iterations": {
            "average": avg_iterations,
            "max_used": max_iterations_used,
            "total": sum(iterations),
        },
        "steps": {
            "total_completed": total_steps_completed,
            "total_expected": total_steps_expected,
            "completion_rate": total_steps_completed / total_steps_expected if total_steps_expected > 0 else 0,
        },
        "tokens": {
            "total": total_tokens,
            "average": avg_tokens,
        },
        "errors": all_errors,
        "driver_backends": driver_backends,
        "driver_models": driver_models,
        "reviewer_backends": reviewer_backends,
        "reviewer_models": reviewer_models,
        "skills_used": skills_used,
    }


def format_text_report(
    metrics_list: List[Dict[str, Any]],
    stats: Dict[str, Any],
    show_individual: bool = True,
) -> str:
    """Format a text report from metrics data.

    Args:
        metrics_list: List of metrics dictionaries
        stats: Aggregate statistics
        show_individual: Whether to show per-run details

    Returns:
        Formatted text report
    """
    lines = []

    # Header
    lines.append("=" * 60)
    lines.append("RALPH LOOP METRICS REPORT")
    lines.append("=" * 60)
    lines.append("")

    # Summary
    lines.append("--- Summary ---")
    lines.append(f"Total Runs:    {stats.get('total_runs', 0)}")

    status_counts = stats.get("status_counts", {})
    pass_count = status_counts.get("pass", 0)
    fail_count = status_counts.get("fail", 0)
    partial_count = status_counts.get("partial", 0)
    running_count = status_counts.get("running", 0)

    lines.append(f"Pass:          {pass_count} ({stats.get('pass_rate', 0):.1%})")
    lines.append(f"Fail:          {fail_count}")
    if partial_count > 0:
        lines.append(f"Partial:       {partial_count}")
    if running_count > 0:
        lines.append(f"Running:       {running_count}")
    lines.append("")

    # Timing
    lines.append("--- Timing ---")
    timing = stats.get("timing", {})
    lines.append(f"Total Time:    {format_duration(timing.get('total_seconds', 0))}")
    lines.append(f"Average:       {format_duration(timing.get('average_seconds', 0))}")
    lines.append(f"Min:           {format_duration(timing.get('min_seconds', 0))}")
    lines.append(f"Max:           {format_duration(timing.get('max_seconds', 0))}")
    lines.append("")

    # Iterations
    lines.append("--- Iterations ---")
    iterations = stats.get("iterations", {})
    lines.append(f"Total:         {iterations.get('total', 0)}")
    lines.append(f"Average:       {iterations.get('average', 0):.1f}")
    lines.append(f"Max Used:      {iterations.get('max_used', 0)}")
    lines.append("")

    # Steps
    lines.append("--- Steps ---")
    steps = stats.get("steps", {})
    lines.append(f"Completed:     {steps.get('total_completed', 0)} / {steps.get('total_expected', 0)}")
    lines.append(f"Completion:    {steps.get('completion_rate', 0):.1%}")
    lines.append("")

    # Tokens
    tokens = stats.get("tokens", {})
    if tokens.get("total", 0) > 0:
        lines.append("--- Tokens ---")
        lines.append(f"Total:         {tokens.get('total', 0):,}")
        lines.append(f"Average:       {tokens.get('average', 0):,}")
        lines.append("")

    # Errors
    errors = stats.get("errors", {})
    if errors:
        lines.append("--- Errors ---")
        for error, count in sorted(errors.items(), key=lambda x: -x[1]):
            lines.append(f"  {error}: {count}")
        lines.append("")

    # Model usage
    driver_models = stats.get("driver_models", {})
    reviewer_models = stats.get("reviewer_models", {})
    if driver_models or reviewer_models:
        lines.append("--- Models ---")
        if driver_models:
            lines.append("Driver:")
            for model, count in sorted(driver_models.items(), key=lambda x: -x[1]):
                lines.append(f"  {model}: {count}")
        if reviewer_models:
            lines.append("Reviewer:")
            for model, count in sorted(reviewer_models.items(), key=lambda x: -x[1]):
                lines.append(f"  {model}: {count}")
        lines.append("")

    # Skills usage
    skills = stats.get("skills_used", {})
    if skills:
        lines.append("--- Skills ---")
        for skill, count in sorted(skills.items(), key=lambda x: -x[1]):
            lines.append(f"  {skill}: {count}")
        lines.append("")

    # Individual runs (if requested and multiple)
    if show_individual and len(metrics_list) > 1:
        lines.append("--- Individual Runs ---")
        lines.append("")
        lines.append(f"{'Prompt':<30} {'Status':<10} {'Duration':<12} {'Iter':<6} {'Steps':<10}")
        lines.append("-" * 70)

        for m in metrics_list:
            prompt_id = m.get("prompt_id", "unknown")[:30]
            status = m.get("correctness", "?")
            duration = format_duration(m.get("duration_seconds", 0))
            iters = m.get("iterations", 0)
            steps = f"{m.get('steps_completed', 0)}/{m.get('steps_total', 0)}"

            lines.append(f"{prompt_id:<30} {status:<10} {duration:<12} {iters:<6} {steps:<10}")

        lines.append("")

    lines.append("=" * 60)

    return "\n".join(lines)


def format_json_report(
    metrics_list: List[Dict[str, Any]],
    stats: Dict[str, Any],
) -> str:
    """Format a JSON report from metrics data.

    Args:
        metrics_list: List of metrics dictionaries
        stats: Aggregate statistics

    Returns:
        JSON string
    """
    report = {
        "generated_at": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc
        ).isoformat(),
        "statistics": stats,
        "runs": [
            {
                "prompt_id": m.get("prompt_id"),
                "rubric_id": m.get("rubric_id"),
                "correctness": m.get("correctness"),
                "duration_seconds": m.get("duration_seconds"),
                "iterations": m.get("iterations"),
                "steps_completed": m.get("steps_completed"),
                "steps_total": m.get("steps_total"),
                "errors_encountered": m.get("errors_encountered", []),
            }
            for m in metrics_list
        ],
    }
    return json.dumps(report, indent=2)


def find_metrics_files(directory: str) -> List[str]:
    """Find all metrics.json files in a directory tree.

    Args:
        directory: Root directory to search

    Returns:
        List of paths to metrics.json files
    """
    paths = []
    for root, _, files in os.walk(directory):
        for f in files:
            if f == "metrics.json":
                paths.append(os.path.join(root, f))
    return sorted(paths)


def main():
    parser = argparse.ArgumentParser(
        description="Generate summary reports from ralph loop metrics files"
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Paths to metrics.json files (supports glob patterns)",
    )
    parser.add_argument(
        "--find-in",
        metavar="DIR",
        help="Find all metrics.json files in directory",
    )
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--no-individual",
        action="store_true",
        help="Don't show individual run details in text format",
    )

    args = parser.parse_args()

    # Collect all file paths
    all_paths: List[str] = []

    if args.find_in:
        all_paths.extend(find_metrics_files(args.find_in))

    for pattern in args.paths:
        # Handle glob patterns
        if "*" in pattern or "?" in pattern:
            all_paths.extend(glob.glob(pattern, recursive=True))
        else:
            all_paths.append(pattern)

    if not all_paths:
        print("Error: No metrics files specified", file=sys.stderr)
        print("Usage: metrics-report.py <path>... or --find-in <dir>", file=sys.stderr)
        sys.exit(1)

    # Load all metrics
    metrics_list = []
    for path in all_paths:
        data = load_metrics(path)
        if data:
            metrics_list.append(data)

    if not metrics_list:
        print("Error: No valid metrics files found", file=sys.stderr)
        sys.exit(1)

    # Calculate statistics
    stats = calculate_statistics(metrics_list)

    # Format and output
    if args.format == "json":
        print(format_json_report(metrics_list, stats))
    else:
        print(format_text_report(metrics_list, stats, show_individual=not args.no_individual))


if __name__ == "__main__":
    main()
