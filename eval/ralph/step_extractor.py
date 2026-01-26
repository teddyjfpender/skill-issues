"""
Step extraction module for parsing step markers from prompt files.

Extracts step content from prompts that use "## Step N" or "## Step N: Description" markers.
Used by step-loop.sh for incremental code generation.
"""

import re
from typing import Optional, Tuple, List


def count_steps(content: str) -> int:
    """
    Count the number of steps in a prompt file.

    Looks for "## Step N" markers at the beginning of lines.

    Args:
        content: The full content of the prompt file

    Returns:
        Number of steps found
    """
    pattern = re.compile(r'^## Step \d+', re.MULTILINE)
    matches = pattern.findall(content)
    return len(matches)


def extract_step_content(content: str, step_num: int) -> Optional[str]:
    """
    Extract the content of a specific step from a prompt file.

    Supports formats:
    - "## Step 1"
    - "## Step 1: Description"

    Step content extends from the header line until:
    - The next "## Step N" marker
    - The next "## Section" (capitalized word after ##)
    - End of file

    Args:
        content: The full content of the prompt file
        step_num: The step number to extract (1-based)

    Returns:
        The step content (without the header line), or None if step not found
    """
    # Pattern matches "## Step N" optionally followed by ": Description"
    step_pattern = re.compile(r'^## Step (\d+)(?::\s*.+)?$', re.MULTILINE)
    matches = list(step_pattern.finditer(content))

    if not matches:
        return None

    # Find the position of our step
    start_pos = None
    end_pos = len(content)

    for i, m in enumerate(matches):
        if int(m.group(1)) == step_num:
            # Start after the header line
            newline_pos = content.find('\n', m.start())
            if newline_pos == -1:
                # Header is at end of file with no newline
                return ""
            start_pos = newline_pos + 1

            # End at next step or section boundary
            if i + 1 < len(matches):
                end_pos = matches[i + 1].start()
            else:
                # Look for next ## section that's not a Step
                # Match "## " followed by a capital letter (section headers)
                next_section = re.search(r'^## [A-Z]', content[m.end():], re.MULTILINE)
                if next_section:
                    end_pos = m.end() + next_section.start()
            break

    if start_pos is None:
        return None

    extracted = content[start_pos:end_pos].strip()

    # Remove trailing --- if present (section dividers)
    extracted = re.sub(r'\n---\s*$', '', extracted)

    return extracted


def extract_preamble(content: str) -> str:
    """
    Extract everything before "## Step 1".

    This typically includes the problem description, requirements,
    and any setup instructions.

    Args:
        content: The full content of the prompt file

    Returns:
        Content before the first step marker, or empty string if none
    """
    pattern = re.compile(r'^## Step 1', re.MULTILINE)
    match = pattern.search(content)

    if match:
        return content[:match.start()].rstrip()

    return content


def get_step_info(content: str, step_num: int) -> Optional[Tuple[str, str]]:
    """
    Get step header and content.

    Args:
        content: The full content of the prompt file
        step_num: The step number to extract (1-based)

    Returns:
        Tuple of (header, content) or None if step not found
    """
    step_pattern = re.compile(r'^(## Step (\d+)(?::\s*.+)?)$', re.MULTILINE)
    matches = list(step_pattern.finditer(content))

    for m in matches:
        if int(m.group(2)) == step_num:
            header = m.group(1)
            step_content = extract_step_content(content, step_num)
            if step_content is not None:
                return (header, step_content)

    return None


def list_steps(content: str) -> List[Tuple[int, str]]:
    """
    List all steps with their headers.

    Args:
        content: The full content of the prompt file

    Returns:
        List of (step_number, header_line) tuples
    """
    step_pattern = re.compile(r'^(## Step (\d+)(?::\s*.+)?)$', re.MULTILINE)
    matches = step_pattern.finditer(content)

    return [(int(m.group(2)), m.group(1)) for m in matches]


def is_valid_step_marker(line: str) -> bool:
    """
    Check if a line is a valid step marker.

    Valid formats:
    - "## Step 1"
    - "## Step 1: Description"

    Invalid formats (not supported):
    - "### Step 1" (wrong heading level)
    - "- Step 1:" (list format)
    - "Step 1" (no heading prefix)

    Args:
        line: A single line to check

    Returns:
        True if the line is a valid step marker
    """
    pattern = re.compile(r'^## Step \d+(?::\s*.+)?$')
    return bool(pattern.match(line.strip()))
