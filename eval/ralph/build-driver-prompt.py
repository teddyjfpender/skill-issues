#!/usr/bin/env python3
"""
Build the driver prompt for Cairo code generation.

Assembles:
- Original prompt requirements
- Rubric criteria
- Pre-loaded skill content (to avoid searching)
- Previous attempt code and errors (if attempt > 1)
- Attempt history summary
- Performance-focused instructions

Usage:
  build-driver-prompt.py --prompt <path> --rubric <path> --history <path> --attempt <n> --output <path> [--skills skill1,skill2]
"""

import argparse
import json
import os
import sys
from pathlib import Path


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def find_repo_root() -> Path:
    """Find the repository root by looking for eval/ directory."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "skills").is_dir():
            return current
        current = current.parent
    return Path.cwd()


def load_skill_content(skill_name: str, repo_root: Path) -> str:
    """Load skill content from the skills directory."""
    skill_dir = repo_root / "skills" / skill_name

    if not skill_dir.exists():
        return f"[Skill '{skill_name}' not found at {skill_dir}]"

    parts = [f"### Skill: {skill_name}"]

    # Load SKILL.md if present
    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists():
        content = read_file(str(skill_md))
        parts.append(content.strip())

    # Load key reference files (limit to avoid huge prompts)
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        for ref_file in sorted(refs_dir.glob("*.md"))[:2]:  # Max 2 reference files
            ref_content = read_file(str(ref_file))
            # Truncate large reference files
            if len(ref_content) > 3000:
                ref_content = ref_content[:3000] + "\n[... truncated ...]"
            parts.append(f"\n#### Reference: {ref_file.name}")
            parts.append(ref_content.strip())

    return "\n\n".join(parts)


def truncate_lines(text: str, max_lines: int = 50) -> str:
    """Truncate text to last N lines."""
    lines = text.strip().split("\n")
    if len(lines) <= max_lines:
        return text
    return f"[... truncated {len(lines) - max_lines} lines ...]\n" + "\n".join(lines[-max_lines:])


def summarize_attempts(history: dict, current_attempt: int) -> str:
    """Summarize previous attempts without full code."""
    summaries = []
    for attempt in history.get("attempts", []):
        num = attempt.get("number", 0)
        if num >= current_attempt:
            continue

        parts = [f"### Attempt {num}"]

        # Review result
        review = attempt.get("review_result", {})
        if review.get("verdict"):
            parts.append(f"- Review verdict: {review['verdict']}")
            if review.get("issues"):
                issues_summary = ", ".join(i.get("description", "")[:50] for i in review["issues"][:3])
                parts.append(f"- Review issues: {issues_summary}")

        # Verify result
        verify = attempt.get("verify_result", {})
        if verify.get("status"):
            parts.append(f"- Verify status: {verify['status']}")
            if verify.get("failed_steps"):
                parts.append(f"- Failed steps: {', '.join(verify['failed_steps'])}")

        # Feedback
        feedback = attempt.get("feedback", {})
        if feedback.get("summary"):
            parts.append(f"- Issue: {feedback['summary']}")
        if feedback.get("actionable_hints"):
            hints = "; ".join(feedback["actionable_hints"][:3])
            parts.append(f"- Hints: {hints}")

        summaries.append("\n".join(parts))

    return "\n\n".join(summaries) if summaries else ""


def get_last_attempt_details(history: dict, current_attempt: int) -> dict:
    """Get detailed info from the most recent attempt."""
    for attempt in reversed(history.get("attempts", [])):
        if attempt.get("number", 0) == current_attempt - 1:
            return attempt
    return {}


def build_prompt(
    prompt_content: str,
    rubric_content: str,
    history: dict,
    attempt_num: int,
    max_attempts: int,
    skills_content: str = "",
) -> str:
    """Build the complete driver prompt."""
    parts = []

    # Header with performance guidance
    parts.append("# Cairo Code Generation Task")
    parts.append("")
    parts.append("## IMPORTANT: Performance Guidelines")
    parts.append("")
    parts.append("You are in an iterative code generation loop. Your goal is to generate code QUICKLY.")
    parts.append("")
    parts.append("**DO:**")
    parts.append("- Generate code immediately using the skills and context provided below")
    parts.append("- Make your best attempt even if uncertain - you'll get feedback to iterate")
    parts.append("- Focus on satisfying the requirements, not on exploring the codebase")
    parts.append("")
    parts.append("**DO NOT:**")
    parts.append("- Search for skill files - they are pre-loaded below")
    parts.append("- Extensively research existing code patterns")
    parts.append("- Read more than 2-3 files for reference")
    parts.append("- Aim for perfection on the first attempt")
    parts.append("")
    parts.append("The loop will provide error feedback if your code doesn't compile or tests fail.")
    parts.append("Iterate quickly rather than researching extensively.")
    parts.append("")

    # Pre-loaded skills (fixes skill path confusion)
    if skills_content:
        parts.append("## Pre-loaded Skills Reference")
        parts.append("")
        parts.append("Use these skills as your primary reference. Do NOT search for skill files.")
        parts.append("")
        parts.append(skills_content)
        parts.append("")

    # Original requirements
    parts.append("## Original Requirements")
    parts.append(prompt_content.strip())
    parts.append("")

    # Rubric
    parts.append("## Evaluation Criteria (Rubric)")
    parts.append(rubric_content.strip())
    parts.append("")

    # Attempt info
    parts.append(f"## Attempt {attempt_num} of {max_attempts}")
    parts.append("")

    # Previous attempts context (if not first attempt)
    if attempt_num > 1:
        parts.append("## Previous Attempts")
        parts.append("")

        # Full details for last attempt
        last_attempt = get_last_attempt_details(history, attempt_num)
        if last_attempt:
            parts.append(f"### Most Recent Attempt ({attempt_num - 1})")
            parts.append("")

            # Show the code from last attempt
            driver_result = last_attempt.get("driver_result", {})
            code_path = driver_result.get("code_path", "")
            if code_path and os.path.exists(code_path):
                code_content = read_file(code_path)
                parts.append("**Code submitted:**")
                parts.append("```cairo")
                parts.append(truncate_lines(code_content, max_lines=100))
                parts.append("```")
                parts.append("")

            # Review feedback
            review = last_attempt.get("review_result", {})
            if review.get("verdict"):
                parts.append(f"**Review verdict:** {review['verdict']}")
                if review.get("issues"):
                    parts.append("")
                    parts.append("**Review issues:**")
                    for issue in review["issues"]:
                        severity = issue.get("severity", "error")
                        desc = issue.get("description", "")
                        suggestion = issue.get("suggestion", "")
                        parts.append(f"- [{severity}] {desc}")
                        if suggestion:
                            parts.append(f"  - Suggestion: {suggestion}")
                parts.append("")

            # Verification errors
            feedback = last_attempt.get("feedback", {})
            if feedback.get("errors"):
                parts.append("**Verification errors:**")
                parts.append("```")
                for error in feedback["errors"][:10]:  # Limit to 10 errors
                    parts.append(truncate_lines(error, max_lines=20))
                parts.append("```")
                parts.append("")

            if feedback.get("actionable_hints"):
                parts.append("**Suggestions to fix:**")
                for hint in feedback["actionable_hints"]:
                    parts.append(f"- {hint}")
                parts.append("")

        # Summary of older attempts (if more than 2)
        if attempt_num > 2:
            parts.append("### Earlier Attempts Summary")
            parts.append("(Avoid repeating these approaches)")
            parts.append("")
            summary = summarize_attempts(history, attempt_num - 1)  # Exclude last attempt
            if summary:
                parts.append(summary)
                parts.append("")

    # Instructions
    parts.append("## Instructions")
    parts.append("")
    parts.append("Generate Cairo code that:")
    parts.append("1. Satisfies ALL requirements from the original prompt")
    parts.append("2. Passes ALL evaluation criteria from the rubric")
    parts.append("3. Compiles successfully with `scarb build`")
    parts.append("4. Passes all tests with `snforge test` (if tests are required)")
    parts.append("")

    if attempt_num > 1:
        parts.append("**IMPORTANT:** Address the issues from the previous attempt. Do not repeat the same mistakes.")
        parts.append("")

    parts.append('Return JSON only with shape {"code": string, "notes": string}.')
    parts.append('Put the complete Cairo code in "code" and any caveats or notes in "notes" (empty string is ok).')
    parts.append("Do not include Markdown code fences in the code field.")
    parts.append("")

    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Build driver prompt for Cairo code generation")
    parser.add_argument("--prompt", required=True, help="Path to prompt file")
    parser.add_argument("--rubric", required=True, help="Path to rubric file")
    parser.add_argument("--history", required=True, help="Path to history.json")
    parser.add_argument("--attempt", type=int, required=True, help="Current attempt number")
    parser.add_argument("--max-attempts", type=int, default=5, help="Maximum attempts")
    parser.add_argument("--output", required=True, help="Output path for prompt")
    parser.add_argument("--skills", default="", help="Comma-separated list of skill names to pre-load")
    args = parser.parse_args()

    # Load inputs
    prompt_content = read_file(args.prompt)
    rubric_content = read_file(args.rubric)

    history = {}
    if os.path.exists(args.history):
        history = json.loads(read_file(args.history))

    # Load skill content
    skills_content = ""
    if args.skills:
        repo_root = find_repo_root()
        skill_names = [s.strip() for s in args.skills.split(",") if s.strip()]
        skill_parts = []
        for skill_name in skill_names:
            skill_parts.append(load_skill_content(skill_name, repo_root))
        skills_content = "\n\n---\n\n".join(skill_parts)

    # Build prompt
    prompt = build_prompt(
        prompt_content=prompt_content,
        rubric_content=rubric_content,
        history=history,
        attempt_num=args.attempt,
        max_attempts=args.max_attempts,
        skills_content=skills_content,
    )

    # Write output
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(prompt)

    print(f"Driver prompt written to {args.output}")


if __name__ == "__main__":
    main()
