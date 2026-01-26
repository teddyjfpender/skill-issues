#!/usr/bin/env python3
"""
Extract actionable feedback from verification results.

Parses build/test errors from verify.json and stderr files
into structured feedback for the next attempt.

Usage:
  extract-feedback.py --verify-json <path> --output <path>
"""

import argparse
import json
import os
import re


def read_file(path: str) -> str:
    if not path or not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


# Common Cairo error patterns and their actionable hints
CAIRO_ERROR_PATTERNS = [
    # Snapshot dereference errors (VERY COMMON)
    (
        r'Expected: "([^"]+)", found: "@\1"',
        lambda m: f"Snapshot dereference needed. Use `*self.field` instead of `self.field` when self is a snapshot (@Type).",
    ),
    (
        r'Unexpected argument type\. Expected: "core::integer::(\w+)", found: "@core::integer::\1"',
        lambda m: f"Snapshot field needs dereferencing. When `self: @T`, use `*self.field` to get owned {m.group(1)} from @{m.group(1)}.",
    ),
    (
        r'Unexpected argument type\. Expected: "(\w+)", found: "@\1"',
        lambda m: f"Dereference snapshot field with `*`. Expected {m.group(1)} but got @{m.group(1)}.",
    ),
    # Type mismatch errors
    (
        r"type mismatch: `([^`]+)` and `([^`]+)`",
        lambda m: f"Type mismatch between `{m.group(1)}` and `{m.group(2)}`. Check trait bounds and dereference operators.",
    ),
    # Missing trait implementation
    (
        r"Trait has no implementation in context: `([^`]+)`",
        lambda m: f"Missing implementation for trait `{m.group(1)}`. Add the required impl or trait bound.",
    ),
    # Unknown type
    (
        r"Type not found\. Did you mean: `([^`]+)`\?",
        lambda m: f"Unknown type. Did you mean `{m.group(1)}`?",
    ),
    # Unknown function
    (
        r"Function not found in context\. Did you mean: `([^`]+)`\?",
        lambda m: f"Unknown function. Did you mean `{m.group(1)}`?",
    ),
    # Missing derive
    (
        r"Method `([^`]+)` not found on type `([^`]+)`.*Consider adding.*`#\[derive\(([^)]+)\)\]`",
        lambda m: f"Add `#[derive({m.group(3)})]` to `{m.group(2)}` to use `{m.group(1)}`.",
    ),
    # Deprecated index view
    (
        r"DeprecatedIndexViewImpl.*type mismatch",
        lambda _: "Array indexing type mismatch. Use `.get(idx)` with `Option` unwrapping instead of direct indexing, or ensure proper snapshot handling with `@arr`.",
    ),
    # Missing Copy trait
    (
        r"Unexpected return type\. Expected: `([^`]+)`, found: `@([^`]+)`",
        lambda m: f"Return type mismatch. Expected `{m.group(1)}` but got snapshot `@{m.group(2)}`. Add `Copy` trait bound or dereference with `*`.",
    ),
    # Variable not found
    (
        r"Variable '([^']+)' not found",
        lambda m: f"Variable `{m.group(1)}` not found. Check spelling and scope.",
    ),
    # Struct field not found
    (
        r"Struct `([^`]+)` has no member `([^`]+)`",
        lambda m: f"Struct `{m.group(1)}` has no field `{m.group(2)}`. Check struct definition.",
    ),
    # Generic constraints
    (
        r"Could not find implementation of trait `([^`]+)` for type `([^`]+)`",
        lambda m: f"No impl of `{m.group(1)}` for `{m.group(2)}`. Add trait bound or implement the trait.",
    ),
]

# Test failure patterns
TEST_ERROR_PATTERNS = [
    (
        r"assertion failed: `([^`]+)`",
        lambda m: f"Test assertion failed: {m.group(1)}",
    ),
    (
        r"panicked with '([^']+)'",
        lambda m: f"Test panicked: {m.group(1)}",
    ),
    (
        r"test (\S+) \.\.\. FAILED",
        lambda m: f"Test `{m.group(1)}` failed",
    ),
]


def extract_errors_from_output(output: str, step: str) -> list[str]:
    """Extract error messages from step output."""
    errors = []
    lines = output.split("\n")

    # Find error blocks (error: ... followed by location and code)
    current_error = []
    in_error = False

    for line in lines:
        if line.startswith("error:") or line.startswith("Error:"):
            if current_error:
                errors.append("\n".join(current_error))
            current_error = [line]
            in_error = True
        elif in_error:
            if line.strip() and not line.startswith("warning:"):
                current_error.append(line)
            else:
                if current_error:
                    errors.append("\n".join(current_error))
                current_error = []
                in_error = False

    if current_error:
        errors.append("\n".join(current_error))

    return errors


def extract_hints_from_error(error: str) -> list[str]:
    """Generate actionable hints from an error message."""
    hints = []

    # Try each pattern
    for pattern, hint_fn in CAIRO_ERROR_PATTERNS:
        match = re.search(pattern, error, re.IGNORECASE | re.DOTALL)
        if match:
            hints.append(hint_fn(match))

    # If no pattern matched, extract a generic hint
    if not hints:
        # Extract the core error message
        match = re.search(r"error:\s*(.+?)(?:\n|$)", error)
        if match:
            hints.append(f"Error: {match.group(1).strip()}")

    return hints


def extract_test_hints(output: str) -> list[str]:
    """Extract hints from test failures."""
    hints = []

    for pattern, hint_fn in TEST_ERROR_PATTERNS:
        for match in re.finditer(pattern, output):
            hints.append(hint_fn(match))

    return hints


def determine_feedback_source(failed_steps: list[str]) -> str:
    """Determine the primary source of feedback."""
    if "build" in failed_steps:
        return "build"
    if "test" in failed_steps:
        return "test"
    if "format" in failed_steps:
        return "format"
    return "build"


def extract_feedback(verify_json_path: str) -> dict:
    """Extract structured feedback from verification results."""
    with open(verify_json_path, "r", encoding="utf-8") as f:
        verify = json.load(f)

    failed_steps = verify.get("failed_steps", [])
    if not failed_steps:
        return {
            "source": "verify",
            "summary": "All verification steps passed",
            "errors": [],
            "actionable_hints": [],
        }

    source = determine_feedback_source(failed_steps)
    all_errors = []
    all_hints = []

    for step in verify.get("steps", []):
        if step.get("status") != "fail":
            continue

        step_name = step.get("step", "")
        stdout_path = step.get("stdout_path", "")
        stderr_path = step.get("stderr_path", "")

        # Read output files
        stdout = read_file(stdout_path)
        stderr = read_file(stderr_path)
        combined = stdout + "\n" + stderr

        # Extract errors
        errors = extract_errors_from_output(combined, step_name)
        all_errors.extend(errors)

        # Generate hints
        if step_name in ("build", "format"):
            for error in errors:
                all_hints.extend(extract_hints_from_error(error))
        elif step_name == "test":
            all_hints.extend(extract_test_hints(combined))

    # Deduplicate hints while preserving order
    seen = set()
    unique_hints = []
    for hint in all_hints:
        if hint not in seen:
            seen.add(hint)
            unique_hints.append(hint)

    # Generate summary
    if "build" in failed_steps:
        summary = f"Build failed with {len(all_errors)} error(s)"
    elif "test" in failed_steps:
        summary = f"Tests failed"
    elif "format" in failed_steps:
        summary = "Code formatting failed"
    else:
        summary = "Verification failed"

    return {
        "source": source,
        "summary": summary,
        "errors": all_errors[:10],  # Limit to 10 errors
        "actionable_hints": unique_hints[:10],  # Limit to 10 hints
    }


def main():
    parser = argparse.ArgumentParser(description="Extract feedback from verification results")
    parser.add_argument("--verify-json", required=True, help="Path to verify.json")
    parser.add_argument("--output", required=True, help="Output path for feedback JSON")
    args = parser.parse_args()

    feedback = extract_feedback(args.verify_json)

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(feedback, f, indent=2)
        f.write("\n")

    print(f"Feedback extracted to {args.output}")
    print(f"  Source: {feedback['source']}")
    print(f"  Summary: {feedback['summary']}")
    print(f"  Errors: {len(feedback['errors'])}")
    print(f"  Hints: {len(feedback['actionable_hints'])}")


if __name__ == "__main__":
    main()
