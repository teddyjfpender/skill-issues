#!/usr/bin/env python3
"""
Build the reviewer prompt for Cairo code validation.

Assembles:
- Original prompt requirements (for context)
- Rubric criteria (for validation)
- Generated code (to review)

Usage:
  build-reviewer-prompt.py --code <path> --rubric <path> --prompt <path> --output <path>
"""

import argparse
import os


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def build_prompt(
    code_content: str,
    rubric_content: str,
    prompt_content: str,
) -> str:
    """Build the complete reviewer prompt."""
    parts = []

    # Header
    parts.append("# Cairo Code Review Task")
    parts.append("")

    # Original requirements (context)
    parts.append("## Original Requirements")
    parts.append(prompt_content.strip())
    parts.append("")

    # Rubric (validation criteria)
    parts.append("## Evaluation Rubric")
    parts.append("Review the code against these criteria:")
    parts.append("")
    parts.append(rubric_content.strip())
    parts.append("")

    # Code to review
    parts.append("## Code to Review")
    parts.append("```cairo")
    parts.append(code_content.strip())
    parts.append("```")
    parts.append("")

    # Instructions
    parts.append("## Instructions")
    parts.append("")
    parts.append("Review this Cairo code against the evaluation rubric.")
    parts.append("")
    parts.append("For each rubric criterion, check if the code satisfies it.")
    parts.append("Focus on:")
    parts.append("1. **Functional correctness**: Does the code do what the requirements ask?")
    parts.append("2. **Structural requirements**: Are all required types, traits, and functions present?")
    parts.append("3. **Cairo best practices**: Are trait bounds, derives, and attributes correct?")
    parts.append("4. **Completeness**: Is anything missing that would cause compilation or test failures?")
    parts.append("")
    parts.append("Return JSON with this exact shape:")
    parts.append("```json")
    parts.append("{")
    parts.append('  "verdict": "VALID" | "INVALID" | "UNFIXABLE",')
    parts.append('  "issues": [')
    parts.append("    {")
    parts.append('      "criterion": "which rubric item",')
    parts.append('      "severity": "error" | "warning",')
    parts.append('      "description": "what is wrong",')
    parts.append('      "suggestion": "how to fix",')
    parts.append('      "line": 42  // optional line number')
    parts.append("    }")
    parts.append("  ],")
    parts.append('  "notes": "optional summary"')
    parts.append("}")
    parts.append("```")
    parts.append("")
    parts.append("**Verdict meanings:**")
    parts.append("- **VALID**: Code meets all rubric criteria and should compile/pass tests")
    parts.append("- **INVALID**: Code has fixable issues that need to be addressed")
    parts.append("- **UNFIXABLE**: The requirements are impossible or contradictory (rare)")
    parts.append("")
    parts.append("**Severity meanings:**")
    parts.append("- **error**: Must be fixed for code to pass (compilation errors, missing requirements)")
    parts.append("- **warning**: Should be fixed but might not cause failure (style issues, potential bugs)")
    parts.append("")
    parts.append("If the code looks correct, return VALID with an empty issues array.")
    parts.append("Do not include Markdown code fences in your response - return raw JSON only.")
    parts.append("")

    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Build reviewer prompt for Cairo code validation")
    parser.add_argument("--code", required=True, help="Path to code file to review")
    parser.add_argument("--rubric", required=True, help="Path to rubric file")
    parser.add_argument("--prompt", required=True, help="Path to original prompt file")
    parser.add_argument("--output", required=True, help="Output path for prompt")
    args = parser.parse_args()

    # Load inputs
    code_content = read_file(args.code)
    rubric_content = read_file(args.rubric)
    prompt_content = read_file(args.prompt)

    # Build prompt
    prompt = build_prompt(
        code_content=code_content,
        rubric_content=rubric_content,
        prompt_content=prompt_content,
    )

    # Write output
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(prompt)

    print(f"Reviewer prompt written to {args.output}")


if __name__ == "__main__":
    main()
