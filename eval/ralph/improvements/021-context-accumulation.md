# 021: Context Accumulation and Prompt Size

## Problem

As steps progress, the accumulated code grows large:
- Step 1: ~50 lines
- Step 6: ~400 lines
- Step 12: ~800+ lines

This causes:
- Large prompt tokens (cost and latency)
- Risk of context window limits
- Potential for model confusion with too much context

## Current Approach

```markdown
## Previously Verified Code (Steps 1-N)

This code has already been validated. Build on it, do not modify it.

\`\`\`cairo
// All 800 lines of accumulated code
\`\`\`
```

## Strategies for Large Codebases

### Strategy 1: Full Context (Current)
Include all accumulated code in every step prompt.

**Pros:**
- Model sees complete picture
- Can reference any previous code
- No risk of inconsistency

**Cons:**
- Token usage grows linearly
- May hit context limits
- Slower generation

### Strategy 2: Summary + Relevant Sections
```markdown
## Code Summary

- `Matrix<T>` struct: rows, cols, data fields
- `MatrixTrait`: 15 methods defined
- `MatrixImpl`: fully implemented
- `VectorTrait/VectorImpl`: implemented
- Current line count: 500

## Relevant Code (for this step)

\`\`\`cairo
// Only show trait signatures being implemented
pub trait MatrixTrait<T> {
    fn add(...) -> ...;
    fn mul(...) -> ...;
}
\`\`\`
```

**Pros:**
- Smaller prompts
- Focused context

**Cons:**
- May miss important details
- Requires smart summarization

### Strategy 3: Incremental Diffs
```markdown
## Base Code Hash
SHA256: abc123...

## Your Task
Add the following to the existing code:

\`\`\`cairo
// Only new code for this step
impl MatrixAdd of Add<Matrix<T>> {
    // ...
}
\`\`\`
```

**Pros:**
- Minimal token usage
- Clear what to add

**Cons:**
- Model can't verify integration
- Risk of conflicts

### Strategy 4: Chunked Context
```markdown
## Code Sections

### Section 1: Imports and Types (lines 1-50)
[Shown in full]

### Section 2: MatrixTrait (lines 51-100)
[Shown in full]

### Section 3: MatrixImpl (lines 101-400)
[Summarized - "implements all 15 MatrixTrait methods"]

### Section 4: Tests (lines 401-500)
[Not shown - not relevant to this step]
```

## Context Size Guidelines

| Context Size | Recommended Strategy |
|--------------|---------------------|
| < 200 lines | Full context |
| 200-500 lines | Full context with truncation warning |
| 500-1000 lines | Summary + relevant sections |
| > 1000 lines | Chunked or incremental |

## Implementation

### Token Estimation
```bash
estimate_tokens() {
  local content="$1"
  # Rough estimate: ~4 chars per token for code
  local chars=$(echo "$content" | wc -c)
  echo $((chars / 4))
}

# Usage
tokens=$(estimate_tokens "$accumulated_code")
if [[ $tokens -gt 10000 ]]; then
  log_warn "Large context: ~$tokens tokens"
fi
```

### Context Truncation
```bash
truncate_context() {
  local code="$1"
  local max_lines="$2"

  local total_lines=$(echo "$code" | wc -l)
  if [[ $total_lines -gt $max_lines ]]; then
    echo "// ... (${total_lines} total lines, showing last ${max_lines})"
    echo "$code" | tail -n "$max_lines"
  else
    echo "$code"
  fi
}
```

### Smart Section Extraction
```python
def extract_relevant_sections(code, step_requirements):
    """Extract code sections relevant to current step."""
    sections = parse_code_sections(code)
    relevant = []

    for section in sections:
        if section_is_relevant(section, step_requirements):
            relevant.append(section)

    return "\n".join(relevant)
```

## Consistency Preservation

When using partial context, ensure:

1. **Type definitions always included**: Structs, enums, traits
2. **Import statements preserved**: Don't duplicate imports
3. **Trait signatures available**: If implementing, show trait
4. **No orphan implementations**: Show what's being implemented

## State File Enhancement

```json
{
  "current_step": 8,
  "accumulated_code": "...",
  "code_summary": {
    "structs": ["Matrix<T>", "Vector<T>"],
    "traits": ["MatrixTrait", "VectorTrait"],
    "impls": ["MatrixImpl", "VectorImpl", "MatrixPartialEq"],
    "functions": ["to_usize", "index", "matrix_vector_mul"],
    "line_count": 450
  }
}
```

## Implementation Status

- [x] Documented accumulation strategies
- [x] Added token estimation
- [x] Added truncation function
- [ ] Implement smart section extraction
- [ ] Add context size warnings
- [ ] Benchmark different strategies
- [ ] Add context caching
