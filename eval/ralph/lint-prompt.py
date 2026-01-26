#!/usr/bin/env python3
"""
Lint prompt files against the standards defined in improvement doc 018.

This linter validates prompt structure to ensure:
- Consistent step header formatting
- Proper validation markers per step
- Requirements sections with sufficient detail
- No nested numbering anti-patterns
- Single validation per step

Usage:
    python lint-prompt.py <prompt-file.md>
"""

import re
import sys
from pathlib import Path


def lint_prompt(filepath: str) -> tuple[int, int]:
    """
    Lint a prompt file and print results.

    Returns:
        Tuple of (error_count, warning_count)
    """
    path = Path(filepath)
    if not path.exists():
        print(f"Error: File not found: {filepath}")
        return 1, 0

    content = path.read_text()
    lines = content.split('\n')

    print(f"Linting: {filepath}")

    errors = []
    warnings = []

    # Pattern for step headers: ## Step N: or ## Step N (captures full line)
    step_header_pattern = re.compile(r'^(## Step (\d+)[^\n]*)', re.MULTILINE)

    # Find all step headers
    step_matches = list(step_header_pattern.finditer(content))
    step_numbers = [int(m.group(2)) for m in step_matches]

    if not step_matches:
        errors.append("No steps found (expected '## Step N:' format)")
        print(f"  \u2717 No steps found (expected '## Step N:' format)")
    else:
        print(f"  \u2713 Found {len(step_matches)} steps")

    # Check for invalid step headers (## Step without proper number)
    invalid_step_pattern = re.compile(r'^## Step(?!\s+\d)', re.MULTILINE)
    invalid_matches = invalid_step_pattern.findall(content)
    for match in invalid_matches:
        errors.append("Invalid step header format (missing number)")
        print(f"  \u2717 Invalid step header format: '{match}' (missing number)")

    # Extract content for each step
    for i, match in enumerate(step_matches):
        step_num = int(match.group(2))
        start_pos = match.end()  # Position after the full header line

        # Find end of this step's content
        if i + 1 < len(step_matches):
            end_pos = step_matches[i + 1].start()
        else:
            # Find next ## section or end of file
            next_section = re.search(r'^## (?!Step)', content[start_pos:], re.MULTILINE)
            separator = re.search(r'^---', content[start_pos:], re.MULTILINE)

            end_pos = len(content)
            if next_section:
                end_pos = min(end_pos, start_pos + next_section.start())
            if separator:
                end_pos = min(end_pos, start_pos + separator.start())

        step_content = content[start_pos:end_pos]

        # Check 1: Validation marker
        has_validation = '**Validation:**' in step_content or '**Validation**:' in step_content
        has_scarb_build = 'scarb build' in step_content.lower()
        has_snforge_test = 'snforge test' in step_content.lower()

        if not has_validation:
            errors.append(f"Step {step_num}: Missing validation marker")
            print(f"  \u2717 Step {step_num}: Missing validation marker")
        elif not has_scarb_build and not has_snforge_test:
            warnings.append(f"Step {step_num}: Validation marker without 'scarb build' or 'snforge test'")
            print(f"  \u26a0 Step {step_num}: Validation marker without 'scarb build' or 'snforge test'")

        # Check 2: Single validation per step
        if has_scarb_build and has_snforge_test:
            warnings.append(f"Step {step_num}: Both 'scarb build' and 'snforge test' in same step")
            print(f"  \u26a0 Step {step_num}: Both 'scarb build' and 'snforge test' in same step (pick one)")

        # Check 3: Requirements section
        has_requirements = '**Requirements:**' in step_content or '**Requirements**:' in step_content
        if not has_requirements:
            warnings.append(f"Step {step_num}: Missing requirements section")
            print(f"  \u26a0 Step {step_num}: Missing requirements section")
        else:
            # Check for bullet points after requirements
            req_match = re.search(r'\*\*Requirements\*\*:?\s*\n', step_content)
            if req_match:
                after_req = step_content[req_match.end():]
                # Look for bullet points (-, *, or numbered)
                bullets = re.findall(r'^[\s]*[-*\d+\.]\s+.+', after_req, re.MULTILINE)
                if not bullets:
                    warnings.append(f"Step {step_num}: Requirements section has no bullet points")
                    print(f"  \u26a0 Step {step_num}: Requirements section has no bullet points")

        # Check 4: Vague requirements (short description)
        # Get the description: first non-empty paragraph after header, before **Requirements:** or **Validation:**
        # Skip leading whitespace and look for text that's not a markdown marker
        desc_match = re.search(r'^\s*\n\s*([^*#\n][^\n]+)', step_content)
        if desc_match:
            description = desc_match.group(1).strip()
            if len(description) < 20 and description:
                warnings.append(f"Step {step_num}: Description is very short ({len(description)} chars)")
                print(f"  \u26a0 Step {step_num}: Description is very short ({len(description)} chars): '{description}'")

        # Check 5: Nested numbering anti-pattern
        nested_pattern = re.compile(r'^### \d+\.\d+', re.MULTILINE)
        nested_matches = nested_pattern.findall(step_content)
        if nested_matches:
            for nested in nested_matches:
                warnings.append(f"Step {step_num}: Nested numbering found '{nested}'")
                print(f"  \u26a0 Step {step_num}: Nested numbering found '{nested}' (parser won't find sub-steps)")

    # Check step number sequence
    if step_numbers:
        expected = list(range(1, len(step_numbers) + 1))
        if step_numbers != expected:
            if sorted(step_numbers) != expected:
                warnings.append(f"Step numbers are not sequential: {step_numbers}")
                print(f"  \u26a0 Step numbers are not sequential: {step_numbers}")
            else:
                warnings.append(f"Steps are out of order: {step_numbers}")
                print(f"  \u26a0 Steps are out of order: {step_numbers}")

    # Summary
    print(f"\nSummary: {len(errors)} errors, {len(warnings)} warnings")

    return len(errors), len(warnings)


def main():
    if len(sys.argv) < 2:
        print("Usage: python lint-prompt.py <prompt-file.md>")
        print("\nLints prompt files against the standards in improvement doc 018.")
        print("\nChecks performed:")
        print("  - Step header format (## Step N: or ## Step N )")
        print("  - Validation markers (**Validation:** with scarb build or snforge test)")
        print("  - Requirements sections with bullet points")
        print("  - Vague requirements (< 20 char descriptions)")
        print("  - Nested numbering anti-pattern (### 1.1 style)")
        print("  - Single validation per step (not both build and test)")
        sys.exit(1)

    filepath = sys.argv[1]
    errors, warnings = lint_prompt(filepath)

    # Exit with error code if there were errors
    if errors > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
