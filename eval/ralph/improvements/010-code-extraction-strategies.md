# 010: Code Extraction Strategies

## Problem

Code extraction from LLM output was fragile. The JSON output schema approach with Codex sometimes failed silently, and Claude would sometimes explain changes instead of outputting code blocks.

## Failure Modes

### 1. JSON Schema Failures
```json
// Expected:
{"code": "use core::array...", "notes": "..."}

// Actual (malformed):
{"code": "use core::array...  // Missing closing quote
```

### 2. Explanation Instead of Code
```
I've implemented the Add and Mul operators as requested.
The key changes:
1. Add operator implementation: Wraps around MatrixTrait::add...
```
(No code block present)

### 3. Wrong Fence Type
```rust
// LLM used ```rust instead of ```cairo
fn main() { ... }
```

## Solutions

### 1. Prefer Markdown Fences Over JSON

```bash
# JSON extraction (fragile):
extract_code_from_json() {
  jq -r '.code // empty' "$1" 2>/dev/null
}

# Markdown extraction (robust):
extract_code_from_markdown() {
  local file="$1"
  # Try cairo-specific fence first
  local code=$(sed -n '/^```cairo/,/^```$/p' "$file" | sed '1d;$d')
  if [[ -n "$code" ]]; then
    echo "$code"
    return
  fi
  # Fallback to any code block
  sed -n '/^```/,/^```$/p' "$file" | sed '1d;$d'
}
```

### 2. Strong Output Format Instructions

```markdown
## Output Format - MANDATORY

**YOU MUST OUTPUT THE COMPLETE lib.cairo FILE IN A SINGLE \`\`\`cairo CODE BLOCK.**

DO NOT explain what you would do. DO NOT describe the changes.
ONLY output the code block. Nothing else.

Start your response with \`\`\`cairo and end with \`\`\`
Do not add any text before or after the code block.
```

### 3. Backend-Specific Extraction

```bash
extract_code() {
  local output_file="$1"

  if [[ "$backend" == "claude" ]]; then
    extract_code_from_markdown "$output_file"
  else
    # Codex with JSON schema
    extract_code_from_json "$output_file"
  fi
}
```

### 4. Validation Before Use

```bash
new_code=$(extract_code "$output_file")
if [[ -z "$new_code" ]]; then
  log_warn "No code in output"
  error_feedback="Output did not contain code (check for \`\`\`cairo blocks)"
  ((retry++))
  continue
fi

# Additional validation
if ! echo "$new_code" | grep -q "^use \|^pub \|^fn \|^struct \|^trait \|^impl "; then
  log_warn "Code doesn't look like valid Cairo"
  error_feedback="Extracted content doesn't appear to be Cairo code"
  ((retry++))
  continue
fi
```

## Fence Extraction Patterns

| Pattern | Matches |
|---------|---------|
| `/^```cairo/,/^```$/` | Cairo-specific blocks |
| `/^```$/,/^```$/` | Generic code blocks |
| `/^```[a-z]*/,/^```$/` | Any language block |

## Recommendations

1. **Use markdown fences** for Claude CLI backend
2. **Use JSON schema** only when structured metadata is needed
3. **Always validate** extracted code before use
4. **Provide clear examples** in prompt of expected format
5. **Log raw output** for debugging failed extractions

## Implementation Status

- [x] Added markdown extraction function
- [x] Added fallback extraction logic
- [x] Strengthened output format instructions
- [x] Added empty code validation
- [x] Add Cairo syntax validation (via scarb check in validation phase)
- [x] Add Cairo linting validation (via scarb lint in validation phase)
- [ ] Add extraction success metrics
