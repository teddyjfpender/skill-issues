"""
Unit tests for step extraction from prompt files.

Tests the step_extractor module which parses "## Step N" markers
from prompt files used by step-loop.sh.

Run with: pytest eval/ralph/tests/test_step_extraction.py
"""

import pytest
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from step_extractor import (
    count_steps,
    extract_step_content,
    extract_preamble,
    get_step_info,
    list_steps,
    is_valid_step_marker,
)


# =============================================================================
# Test Fixtures - Sample Prompt Snippets
# =============================================================================

@pytest.fixture
def basic_prompt():
    """Basic prompt with simple ## Step N format."""
    return """# Cairo Matrix Algebra

Implement a basic matrix library in Cairo.

## Step 1

Implement the Matrix struct and constructor.

## Step 2

Implement matrix addition.

## Step 3

Implement matrix multiplication.
"""


@pytest.fixture
def prompt_with_colon_descriptions():
    """Prompt using ## Step N: Description format."""
    return """# Vector Operations

## Step 1: Define the Vector struct

Create a Vector struct with x, y, z fields.

## Step 2: Implement dot product

Calculate the dot product of two vectors.

## Step 3: Implement cross product

Calculate the cross product of two vectors.
"""


@pytest.fixture
def prompt_with_code_blocks():
    """Prompt with multi-line step content including code blocks."""
    return """# Cairo Example

## Step 1

Implement the following function:

```cairo
fn add(a: felt252, b: felt252) -> felt252 {
    a + b
}
```

Make sure it handles edge cases.

## Step 2

Write tests for the add function:

```cairo
#[test]
fn test_add() {
    assert(add(2, 3) == 5, 'should be 5');
}
```
"""


@pytest.fixture
def prompt_with_sections():
    """Prompt with both steps and other section types."""
    return """# Implementation Guide

## Overview

This document describes the implementation steps.

## Step 1

First implementation step.

## Step 2

Second implementation step.

## Testing

After implementing, run the tests.

## Notes

Additional notes here.
"""


@pytest.fixture
def prompt_step_at_end():
    """Prompt where the last step has no following section."""
    return """# Simple Task

## Step 1

Do the first thing.

## Step 2

Do the second thing.

## Step 3

This is the final step with no section after it.
It has multiple lines.
And some more content."""


@pytest.fixture
def prompt_with_dividers():
    """Prompt with --- section dividers."""
    return """# Task

## Step 1

Content for step 1.

---

## Step 2

Content for step 2.

---
"""


@pytest.fixture
def empty_step_prompt():
    """Prompt with an empty step."""
    return """# Task

## Step 1

## Step 2

This step has content.
"""


@pytest.fixture
def single_step_prompt():
    """Prompt with only one step."""
    return """# Simple Task

## Requirements

Build a thing.

## Step 1

The only step.
"""


# =============================================================================
# Tests for count_steps
# =============================================================================

class TestCountSteps:
    """Tests for counting steps in a prompt."""

    def test_count_basic_steps(self, basic_prompt):
        """Should count basic ## Step N markers."""
        assert count_steps(basic_prompt) == 3

    def test_count_steps_with_colons(self, prompt_with_colon_descriptions):
        """Should count ## Step N: Description markers."""
        assert count_steps(prompt_with_colon_descriptions) == 3

    def test_count_single_step(self, single_step_prompt):
        """Should count a single step."""
        assert count_steps(single_step_prompt) == 1

    def test_count_no_steps(self):
        """Should return 0 when no steps present."""
        content = "# Title\n\nNo steps here.\n"
        assert count_steps(content) == 0

    def test_count_empty_content(self):
        """Should return 0 for empty content."""
        assert count_steps("") == 0

    def test_count_ignores_invalid_markers(self):
        """Should not count invalid step formats."""
        content = """# Task

### Step 1

Wrong heading level.

- Step 2: List format

Step 3

No heading prefix.
"""
        assert count_steps(content) == 0


# =============================================================================
# Tests for extract_step_content
# =============================================================================

class TestExtractStepContent:
    """Tests for extracting step content."""

    def test_extract_basic_step(self, basic_prompt):
        """Should extract basic step content."""
        content = extract_step_content(basic_prompt, 1)
        assert content is not None
        assert "Implement the Matrix struct" in content
        assert "## Step 2" not in content

    def test_extract_step_with_colon(self, prompt_with_colon_descriptions):
        """Should extract step with colon description format."""
        content = extract_step_content(prompt_with_colon_descriptions, 2)
        assert content is not None
        assert "Calculate the dot product" in content
        assert "Define the Vector" not in content
        assert "cross product" not in content

    def test_extract_step_with_code_blocks(self, prompt_with_code_blocks):
        """Should extract multi-line content with code blocks."""
        content = extract_step_content(prompt_with_code_blocks, 1)
        assert content is not None
        assert "```cairo" in content
        assert "fn add" in content
        assert "a + b" in content
        assert "edge cases" in content

    def test_extract_step_before_non_step_section(self, prompt_with_sections):
        """Should stop at non-step ## sections."""
        content = extract_step_content(prompt_with_sections, 2)
        assert content is not None
        assert "Second implementation step" in content
        # Should not include content from ## Testing section
        assert "After implementing" not in content

    def test_extract_last_step_at_eof(self, prompt_step_at_end):
        """Should extract step at end of file with no following section."""
        content = extract_step_content(prompt_step_at_end, 3)
        assert content is not None
        assert "final step" in content
        assert "multiple lines" in content
        assert "some more content" in content

    def test_extract_nonexistent_step(self, basic_prompt):
        """Should return None for nonexistent step."""
        content = extract_step_content(basic_prompt, 99)
        assert content is None

    def test_extract_step_from_empty_content(self):
        """Should return None from empty content."""
        content = extract_step_content("", 1)
        assert content is None

    def test_extract_empty_step(self, empty_step_prompt):
        """Should return empty string for step with no content."""
        content = extract_step_content(empty_step_prompt, 1)
        # Empty step should return empty string (or just whitespace stripped)
        assert content is not None
        assert content == ""

    def test_extract_removes_trailing_dividers(self, prompt_with_dividers):
        """Should remove trailing --- dividers from step content."""
        content = extract_step_content(prompt_with_dividers, 1)
        assert content is not None
        assert "Content for step 1" in content
        # Trailing --- should be stripped
        assert not content.endswith("---")

    def test_extract_step_zero_returns_none(self, basic_prompt):
        """Step 0 should return None (steps are 1-indexed)."""
        content = extract_step_content(basic_prompt, 0)
        assert content is None

    def test_extract_step_negative_returns_none(self, basic_prompt):
        """Negative step number should return None."""
        content = extract_step_content(basic_prompt, -1)
        assert content is None


# =============================================================================
# Tests for extract_preamble
# =============================================================================

class TestExtractPreamble:
    """Tests for extracting content before Step 1."""

    def test_extract_preamble_basic(self, basic_prompt):
        """Should extract content before ## Step 1."""
        preamble = extract_preamble(basic_prompt)
        assert "Cairo Matrix Algebra" in preamble
        assert "Implement a basic matrix library" in preamble
        assert "## Step 1" not in preamble

    def test_extract_preamble_with_sections(self, prompt_with_sections):
        """Should include non-step sections before Step 1."""
        preamble = extract_preamble(prompt_with_sections)
        assert "Implementation Guide" in preamble
        assert "Overview" in preamble
        assert "describes the implementation" in preamble

    def test_extract_preamble_no_steps(self):
        """Should return entire content if no steps."""
        content = "# Title\n\nJust some content.\n"
        preamble = extract_preamble(content)
        # When no steps, returns entire content (may or may not strip trailing newline)
        assert preamble == content or preamble == content.rstrip()

    def test_extract_preamble_empty_content(self):
        """Should return empty string for empty content."""
        preamble = extract_preamble("")
        assert preamble == ""


# =============================================================================
# Tests for get_step_info
# =============================================================================

class TestGetStepInfo:
    """Tests for getting step header and content together."""

    def test_get_step_info_basic(self, basic_prompt):
        """Should return header and content tuple."""
        info = get_step_info(basic_prompt, 1)
        assert info is not None
        header, content = info
        assert header == "## Step 1"
        assert "Matrix struct" in content

    def test_get_step_info_with_colon(self, prompt_with_colon_descriptions):
        """Should return full header including description."""
        info = get_step_info(prompt_with_colon_descriptions, 1)
        assert info is not None
        header, content = info
        assert header == "## Step 1: Define the Vector struct"
        assert "Vector struct" in content

    def test_get_step_info_nonexistent(self, basic_prompt):
        """Should return None for nonexistent step."""
        info = get_step_info(basic_prompt, 99)
        assert info is None


# =============================================================================
# Tests for list_steps
# =============================================================================

class TestListSteps:
    """Tests for listing all steps."""

    def test_list_steps_basic(self, basic_prompt):
        """Should list all steps with numbers and headers."""
        steps = list_steps(basic_prompt)
        assert len(steps) == 3
        assert steps[0] == (1, "## Step 1")
        assert steps[1] == (2, "## Step 2")
        assert steps[2] == (3, "## Step 3")

    def test_list_steps_with_colons(self, prompt_with_colon_descriptions):
        """Should include full headers with descriptions."""
        steps = list_steps(prompt_with_colon_descriptions)
        assert len(steps) == 3
        assert steps[0][0] == 1
        assert "Define the Vector" in steps[0][1]

    def test_list_steps_empty(self):
        """Should return empty list when no steps."""
        steps = list_steps("# No steps here\n")
        assert steps == []


# =============================================================================
# Tests for is_valid_step_marker
# =============================================================================

class TestIsValidStepMarker:
    """Tests for validating step marker format."""

    def test_valid_basic_marker(self):
        """Should accept basic ## Step N format."""
        assert is_valid_step_marker("## Step 1") is True
        assert is_valid_step_marker("## Step 10") is True
        assert is_valid_step_marker("## Step 999") is True

    def test_valid_marker_with_colon(self):
        """Should accept ## Step N: Description format."""
        assert is_valid_step_marker("## Step 1: Do something") is True
        assert is_valid_step_marker("## Step 2: Another task") is True

    def test_valid_marker_with_whitespace(self):
        """Should accept markers with leading/trailing whitespace."""
        assert is_valid_step_marker("  ## Step 1  ") is True
        assert is_valid_step_marker("\t## Step 1\n") is True

    def test_invalid_wrong_heading_level(self):
        """Should reject ### Step N (wrong heading level)."""
        assert is_valid_step_marker("### Step 1") is False
        assert is_valid_step_marker("# Step 1") is False
        assert is_valid_step_marker("#### Step 1") is False

    def test_invalid_list_format(self):
        """Should reject - Step N: (list format)."""
        assert is_valid_step_marker("- Step 1:") is False
        assert is_valid_step_marker("* Step 1:") is False

    def test_invalid_no_prefix(self):
        """Should reject Step N without ## prefix."""
        assert is_valid_step_marker("Step 1") is False
        assert is_valid_step_marker("Step 1: Do thing") is False

    def test_invalid_missing_space(self):
        """Should reject ##Step N (missing space)."""
        assert is_valid_step_marker("##Step 1") is False

    def test_invalid_non_numeric(self):
        """Should reject non-numeric step markers."""
        assert is_valid_step_marker("## Step A") is False
        assert is_valid_step_marker("## Step one") is False


# =============================================================================
# Tests for Edge Cases and Error Handling
# =============================================================================

class TestEdgeCases:
    """Tests for edge cases and error handling."""

    def test_step_with_only_header_at_eof(self):
        """Step header at EOF with no content or newline."""
        content = "# Title\n\n## Step 1"
        result = extract_step_content(content, 1)
        # Should return empty string, not None
        assert result == ""

    def test_non_sequential_step_numbers(self):
        """Should handle non-sequential step numbers."""
        content = """# Task

## Step 1

First step.

## Step 5

Fifth step (skipped 2-4).

## Step 3

Third step (out of order).
"""
        assert count_steps(content) == 3
        assert extract_step_content(content, 1) is not None
        assert extract_step_content(content, 5) is not None
        assert extract_step_content(content, 3) is not None
        # Step 2 doesn't exist
        assert extract_step_content(content, 2) is None

    def test_unicode_in_step_content(self):
        """Should handle unicode characters in step content."""
        content = """# Task

## Step 1

Implement the following: alpha + beta = gamma
Handle special chars: < > & " '
"""
        result = extract_step_content(content, 1)
        assert result is not None
        assert "alpha" in result

    def test_very_long_step_content(self):
        """Should handle very long step content."""
        long_content = "x" * 10000
        content = f"""# Task

## Step 1

{long_content}

## Step 2

Short step.
"""
        result = extract_step_content(content, 1)
        assert result is not None
        assert len(result) >= 10000

    def test_step_with_nested_headers(self):
        """Should handle ### sub-headers within step content."""
        content = """# Task

## Step 1

### Sub-section A

Content A.

### Sub-section B

Content B.

## Step 2

Next step.
"""
        result = extract_step_content(content, 1)
        assert result is not None
        assert "Sub-section A" in result
        assert "Sub-section B" in result
        assert "Content A" in result
        assert "Content B" in result
        # Should not include Step 2
        assert "Next step" not in result

    def test_step_marker_in_code_block(self):
        """Step markers inside code blocks are still detected (known limitation)."""
        # Note: This tests current behavior. A more sophisticated parser
        # would ignore markers inside code blocks.
        content = """# Task

## Step 1

Here's an example:

```markdown
## Step 2

This is not a real step.
```

Real content continues.
"""
        # Current behavior: counts the marker in code block
        # This is a known limitation documented here
        count = count_steps(content)
        assert count == 2  # Counts both markers (known limitation)

    def test_windows_line_endings(self):
        """Windows-style line endings (known limitation - not fully supported).

        The regex uses ^ with MULTILINE flag, which only matches after \n, not \r\n.
        This documents the current behavior rather than a requirement.
        """
        content = "# Task\r\n\r\n## Step 1\r\n\r\nContent here.\r\n\r\n## Step 2\r\n\r\nMore content.\r\n"
        # Windows line endings: step counting may work but extraction may fail
        # This is a known limitation - prompt files should use Unix line endings
        count = count_steps(content)
        # Counting works because the pattern matches ## Step N in the middle of lines
        assert count == 2
        # Note: extraction may return None due to line ending handling
        # Convert to Unix line endings for reliable extraction
        unix_content = content.replace('\r\n', '\n')
        result = extract_step_content(unix_content, 1)
        assert result is not None
        assert "Content here" in result


# =============================================================================
# Integration-style tests with realistic prompt content
# =============================================================================

class TestRealisticPrompts:
    """Tests with realistic prompt content similar to actual usage."""

    def test_cairo_implementation_prompt(self):
        """Test with a realistic Cairo implementation prompt."""
        prompt = """# Cairo Matrix Algebra Library

Implement a comprehensive matrix algebra library in Cairo.

## Requirements

- Support matrices of any size
- Implement basic operations
- Handle edge cases

## Step 1: Define Matrix Struct

Create the Matrix struct with the following fields:
- rows: u32
- cols: u32
- data: Array<felt252>

Implement a constructor `new(rows: u32, cols: u32)` that creates
a zero-initialized matrix.

## Step 2: Implement Addition

Implement the `add` method for Matrix:

```cairo
fn add(self: @Matrix, other: @Matrix) -> Matrix
```

Requirements:
- Matrices must have same dimensions
- Element-wise addition

## Step 3: Implement Tests

Write comprehensive tests for the Matrix implementation.

Ensure all tests pass with `snforge test`.

## Notes

Additional implementation notes here.
"""
        # Count steps
        assert count_steps(prompt) == 3

        # Extract preamble
        preamble = extract_preamble(prompt)
        assert "Cairo Matrix Algebra Library" in preamble
        assert "Requirements" in preamble
        assert "Step 1" not in preamble

        # Extract step 1
        step1 = extract_step_content(prompt, 1)
        assert step1 is not None
        assert "Matrix struct" in step1
        assert "rows: u32" in step1
        assert "constructor" in step1
        assert "add method" not in step1  # From step 2

        # Extract step 2
        step2 = extract_step_content(prompt, 2)
        assert step2 is not None
        assert "```cairo" in step2
        assert "fn add" in step2
        assert "Element-wise addition" in step2

        # Extract step 3
        step3 = extract_step_content(prompt, 3)
        assert step3 is not None
        assert "comprehensive tests" in step3
        assert "snforge test" in step3
        # Should not include ## Notes section
        assert "Additional implementation notes" not in step3

        # List all steps
        steps = list_steps(prompt)
        assert len(steps) == 3
        assert "Define Matrix Struct" in steps[0][1]
        assert "Implement Addition" in steps[1][1]
        assert "Implement Tests" in steps[2][1]
