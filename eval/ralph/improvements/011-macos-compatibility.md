# 011: macOS Compatibility Issues

## Problem

Several bash script features that work on Linux fail on macOS due to BSD vs GNU tooling differences.

## Issues Encountered

### 1. Missing `timeout` Command

```bash
# Linux: timeout is built-in
timeout 120 codex exec ...

# macOS: Command not found
# Error: timeout: command not found (exit 127)
```

**Solution:**
```bash
# Find available timeout command
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
  TIMEOUT_CMD="gtimeout"  # From coreutils via Homebrew
fi

run_with_timeout() {
  local timeout_secs="$1"
  shift
  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$timeout_secs" "$@"
  else
    # No timeout available, run without
    "$@"
  fi
}
```

### 2. BSD awk vs GNU awk

```bash
# GNU awk: match() with capture groups
awk 'match($0, /Step ([0-9]+)/, arr) { print arr[1] }'

# BSD awk: match() doesn't support capture groups
# Error: awk: syntax error
```

**Solution:**
```bash
# Use sed/grep for simple extraction
sed -n 's/^## Step \([0-9]*\).*/\1/p'

# Or use Python for complex parsing
python3 - "$file" "$step_num" <<'PYEOF'
import sys, re
# Python handles regex consistently across platforms
PYEOF
```

### 3. sed In-Place Editing

```bash
# GNU sed: -i without argument
sed -i 's/foo/bar/' file.txt

# BSD sed: -i requires argument (even empty string)
sed -i '' 's/foo/bar/' file.txt
```

**Solution:**
```bash
# Portable approach: use temp file
sed 's/foo/bar/' file.txt > file.txt.tmp && mv file.txt.tmp file.txt

# Or detect platform
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' 's/foo/bar/' file.txt
else
  sed -i 's/foo/bar/' file.txt
fi
```

### 4. grep -P (Perl Regex)

```bash
# GNU grep: -P for Perl regex
grep -P '\d+' file.txt

# BSD grep: -P not supported
# Error: grep: invalid option -- P
```

**Solution:**
```bash
# Use -E for extended regex (portable)
grep -E '[0-9]+' file.txt

# Or use ripgrep (rg) which is consistent
rg '\d+' file.txt
```

## Recommended Portable Patterns

### Step Extraction (Python)
```python
import re
step_pattern = re.compile(r'^## Step (\d+)', re.MULTILINE)
matches = list(step_pattern.finditer(content))
```

### File Operations
```bash
# Creating temp files
local tmpfile=$(mktemp)
# ... use tmpfile ...
rm -f "$tmpfile"

# Getting absolute paths
make_absolute() {
  local path="$1"
  local dir="$(dirname "$path")"
  mkdir -p "$dir"
  echo "$(cd "$dir" && pwd)/$(basename "$path")"
}
```

### Timeout Wrapper
```bash
run_with_timeout() {
  local timeout_secs="$1"
  shift
  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$timeout_secs" "$@"
  else
    "$@"
  fi
}
```

## Testing Compatibility

```bash
# Add to script header
if [[ "$(uname)" == "Darwin" ]]; then
  echo "Running on macOS - using BSD tools"
  # Check for Homebrew GNU tools
  if ! command -v gtimeout &> /dev/null; then
    echo "Warning: gtimeout not found. Install with: brew install coreutils"
  fi
fi
```

## Implementation Status

- [x] Added `run_with_timeout()` wrapper
- [x] Replaced GNU awk with Python for step extraction
- [x] Used portable sed patterns
- [x] Tested on macOS 14 (Darwin 24.3.0)
- [ ] Add CI testing on both Linux and macOS
- [ ] Document required Homebrew packages
