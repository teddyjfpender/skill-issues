# 022: Output Format Enforcement

## Problem

LLMs sometimes output explanations instead of code, even when format is specified:

```markdown
// Requested:
Return the complete lib.cairo file in a ```cairo code block.

// Got:
I've implemented the Add and Mul operators as requested.
The key changes:
1. Add operator implementation: Wraps around MatrixTrait::add...
(No code block present)
```

## Root Cause

- Instructions too soft ("Return..." vs "YOU MUST...")
- Example format ambiguous
- No explicit prohibition of alternatives
- Model "helping" by explaining

## Solution: Multi-Layer Enforcement

### Layer 1: Mandatory Language

```markdown
## Output Format - MANDATORY

**YOU MUST OUTPUT THE COMPLETE lib.cairo FILE IN A SINGLE \`\`\`cairo CODE BLOCK.**
```

Key phrases:
- "YOU MUST" (not "please" or "return")
- "MANDATORY" (not "expected" or "should")
- Bold formatting for emphasis

### Layer 2: Explicit Prohibitions

```markdown
DO NOT explain what you would do. DO NOT describe the changes.
ONLY output the code block. Nothing else.
```

### Layer 3: Structural Instructions

```markdown
Start your response with \`\`\`cairo and end with \`\`\`
Do not add any text before or after the code block.
```

### Layer 4: Positive Example (Minimal)

```markdown
The code must include:
- All previously verified code (if any)
- Your new code for Step N
```

Note: Avoid showing example code blocks that might be copied literally.

## Complete Output Section

```markdown
## Output Format - MANDATORY

**YOU MUST OUTPUT THE COMPLETE lib.cairo FILE IN A SINGLE \`\`\`cairo CODE BLOCK.**

DO NOT explain what you would do. DO NOT describe the changes.
ONLY output the code block. Nothing else.

The code must include:
- All previously verified code (if any)
- Your new code for Step N

Start your response with \`\`\`cairo and end with \`\`\`
Do not add any text before or after the code block.
```

## Backend-Specific Formatting

### For Claude CLI (Markdown Output)
```markdown
Return the COMPLETE lib.cairo file in a \`\`\`cairo code block.
Start your response with \`\`\`cairo and end with \`\`\`
```

### For Codex (JSON Output)
```markdown
Return JSON: {"code": "<complete lib.cairo content>", "notes": "<any notes>"}
Do not include markdown code fences in the code field.
The JSON must be valid and parseable.
```

## Validation of Output Format

```bash
validate_output_format() {
  local output_file="$1"
  local backend="$2"

  if [[ "$backend" == "claude" ]]; then
    # Check for cairo code block
    if ! grep -q '```cairo' "$output_file"; then
      echo "Missing \`\`\`cairo code block"
      return 1
    fi
    # Check block is not empty
    local code=$(sed -n '/```cairo/,/```/p' "$output_file" | sed '1d;$d')
    if [[ -z "$code" ]]; then
      echo "Empty code block"
      return 1
    fi
  else
    # Check for valid JSON
    if ! jq -e '.code' "$output_file" > /dev/null 2>&1; then
      echo "Invalid JSON or missing 'code' field"
      return 1
    fi
  fi
  return 0
}
```

## Recovery Strategies

### If No Code Block Found

```bash
# Try to find any code-like content
if ! grep -q '```' "$output_file"; then
  # Maybe the model output raw code without fences
  if grep -q '^use core::' "$output_file"; then
    # Wrap it in fences
    echo '```cairo' > "$output_file.fixed"
    cat "$output_file" >> "$output_file.fixed"
    echo '```' >> "$output_file.fixed"
    mv "$output_file.fixed" "$output_file"
  fi
fi
```

### If Multiple Code Blocks

```bash
# Take the largest code block
extract_largest_block() {
  local file="$1"
  local max_size=0
  local best_block=""

  while IFS= read -r block; do
    local size=${#block}
    if [[ $size -gt $max_size ]]; then
      max_size=$size
      best_block="$block"
    fi
  done < <(sed -n '/```/,/```/p' "$file" | sed '1d;$d')

  echo "$best_block"
}
```

## Testing Format Compliance

```bash
test_format_compliance() {
  local test_output="$1"

  echo "Testing: $test_output"

  # Test 1: Has code block
  grep -q '```cairo' "$test_output" && echo "✓ Has cairo block" || echo "✗ Missing cairo block"

  # Test 2: No preamble
  local first_line=$(head -1 "$test_output")
  [[ "$first_line" == '```cairo' ]] && echo "✓ Starts with block" || echo "✗ Has preamble"

  # Test 3: No postamble
  local last_line=$(tail -1 "$test_output")
  [[ "$last_line" == '```' ]] && echo "✓ Ends with block" || echo "✗ Has postamble"

  # Test 4: Code is valid Cairo (basic check)
  local code=$(sed -n '/```cairo/,/```/p' "$test_output" | sed '1d;$d')
  echo "$code" | grep -q '^use \|^pub \|^fn ' && echo "✓ Looks like Cairo" || echo "✗ Doesn't look like Cairo"
}
```

## Implementation Status

- [x] Added mandatory language
- [x] Added explicit prohibitions
- [x] Added structural instructions
- [x] Implemented backend-specific formats
- [x] Added format validation
- [x] Add recovery strategies (eval/ralph/recover-output.sh with 5 strategies)
- [x] Add compliance testing (test_format_compliance function)
- [ ] Track format compliance rates
