# 013: Step Marker Parsing Improvements

## Problem

The original step extraction regex didn't correctly parse step markers with descriptions:

```markdown
## Step 1: Imports and Core Structs    <!-- Actual format -->
## Step 1                              <!-- Expected by regex -->
```

This caused all step content to be concatenated instead of extracting individual steps.

## Root Cause

The sed/awk-based extraction used:
```bash
sed -n "/^## Step ${step_num}[^0-9]/,/^## Step [0-9]\|^---$/p"
```

This pattern has issues:
1. `[^0-9]` after step number is too restrictive
2. Doesn't handle "## Step 10" vs "## Step 1" correctly (prefix matching)
3. BSD sed/awk behave differently than GNU versions

## Solution: Python-Based Extraction

```python
def extract_step_content(prompt_file, step_num):
    with open(prompt_file, 'r') as f:
        content = f.read()

    # Find all step markers
    step_pattern = re.compile(r'^## Step (\d+)', re.MULTILINE)
    matches = list(step_pattern.finditer(content))

    # Find our step
    start_pos = None
    end_pos = len(content)

    for i, m in enumerate(matches):
        if int(m.group(1)) == step_num:
            # Start after the header line
            start_pos = content.find('\n', m.start()) + 1
            # End at next step or section boundary
            if i + 1 < len(matches):
                end_pos = matches[i + 1].start()
            else:
                # Look for next ## section that's not a Step
                next_section = re.search(r'^## [A-Z]', content[m.end():], re.MULTILINE)
                if next_section:
                    end_pos = m.end() + next_section.start()
            break

    if start_pos is not None:
        extracted = content[start_pos:end_pos].strip()
        # Remove trailing --- if present
        extracted = re.sub(r'\n---\s*$', '', extracted)
        return extracted
    return ""
```

## Bash Integration

```bash
extract_step_content() {
  local prompt_file="$1"
  local step_num="$2"

  python3 - "$prompt_file" "$step_num" <<'PYEOF'
import sys
import re

prompt_file = sys.argv[1]
step_num = int(sys.argv[2])

# ... Python extraction code ...

print(extracted)
PYEOF
}
```

## Step Marker Format Standards

### Recommended Format
```markdown
## Step 1: Short Title

Brief description of what this step accomplishes.

**Requirements:**
- Bullet point 1
- Bullet point 2

**Validation:** `scarb build` or `snforge test`
```

### Counting Steps
```bash
count_steps() {
  grep -c "^## Step [0-9]" "$1" || echo "0"
}
```

## Edge Cases Handled

| Case | Pattern | Handling |
|------|---------|----------|
| `## Step 1: Title` | With description | Supported |
| `## Step 1` | No description | Supported |
| `## Step 10` vs `## Step 1` | Multi-digit | Exact match via `int()` |
| Last step before `## Constraints` | Section boundary | Detected via `^## [A-Z]` |
| Step followed by `---` | Separator | Stripped from content |

## Testing Extraction

```bash
# Test script
for step in 1 2 3 12; do
  echo "=== Step $step ==="
  extract_step_content "prompt.md" "$step" | head -5
  echo ""
done
```

## Implementation Status

- [x] Implemented Python-based extraction
- [x] Handles multi-digit step numbers
- [x] Handles descriptions after step numbers
- [x] Detects section boundaries
- [x] Tested with 12-step prompt
- [ ] Add extraction unit tests
- [ ] Support alternative markers (### Step, - Step)
