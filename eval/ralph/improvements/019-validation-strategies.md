# 019: Validation Strategies

## Problem

Validation had several issues:
- Build success didn't guarantee correct code
- Test validation triggered too early
- Error feedback wasn't actionable
- Validation type detection was unreliable

## Validation Phases

### Phase 1: Syntax Check (Fast)
```bash
# Quick syntax validation without full build
scarb check 2>&1
```

**Use for:** Rapid feedback during development
**Catches:** Syntax errors, missing imports, type mismatches

### Phase 2: Build Validation (Medium)
```bash
# Full compilation
scarb build 2>&1
```

**Use for:** Steps that add code without tests
**Catches:** All compile-time errors, trait bound issues

### Phase 3: Test Validation (Complete)
```bash
# Build + run tests
snforge test 2>&1
```

**Use for:** Steps that add or modify tests
**Catches:** Runtime errors, logic bugs, assertion failures

## Validation Type Detection

### Current Approach (Content-Based)
```bash
if echo "$step_content" | grep -qi "snforge test\|tests pass"; then
  validation_type="test"
else
  validation_type="build"
fi
```

### Improved Approach (Explicit Markers)
```markdown
**Validation:** `scarb build`
```

```bash
validation_type="build"
if echo "$step_content" | grep -q '`snforge test`'; then
  validation_type="test"
elif echo "$step_content" | grep -q '`scarb build`'; then
  validation_type="build"
fi
```

## Error Feedback Extraction

### Build Errors
```bash
# Extract relevant error lines
grep -E "^error|^Error|error\[E[0-9]+\]" "$error_file" | head -20
```

### Test Failures
```bash
# Extract test names and failure data
grep -E "^\[FAIL\]|^Failure data:" "$error_file"
```

### Actionable Feedback Format
```
Error: Method `get_unchecked` could not be called on type `@Matrix<T>`
File: src/lib.cairo:318
Fix: Add missing trait bounds to function signature
```

## Validation Workflow

```
┌─────────────┐
│ Generate    │
│ Code        │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│ Syntax      │────▶│ Feedback    │
│ Check       │ ✗   │ + Retry     │
└──────┬──────┘     └─────────────┘
       │ ✓
       ▼
┌─────────────┐     ┌─────────────┐
│ Build       │────▶│ Feedback    │
│ Validation  │ ✗   │ + Retry     │
└──────┬──────┘     └─────────────┘
       │ ✓
       ▼
┌─────────────┐     ┌─────────────┐
│ Test        │────▶│ Feedback    │
│ Validation  │ ✗   │ + Retry     │
│ (if needed) │     └─────────────┘
└──────┬──────┘
       │ ✓
       ▼
┌─────────────┐
│ Success!    │
│ Save Code   │
└─────────────┘
```

## Validation Function Implementation

```bash
validate_step() {
  local work_dir="$1"
  local code_content="$2"
  local error_file="$3"
  local validation_type="$4"

  # Write code
  echo "$code_content" > "$work_dir/src/lib.cairo"

  # Run validation
  case "$validation_type" in
    "check")
      (cd "$work_dir" && scarb check 2>&1) > "$error_file"
      ;;
    "build")
      (cd "$work_dir" && scarb build 2>&1) > "$error_file"
      ;;
    "test")
      # Build first, then test
      if (cd "$work_dir" && scarb build 2>&1) > "$error_file"; then
        (cd "$work_dir" && snforge test 2>&1) >> "$error_file"
      fi
      ;;
  esac

  return $?
}
```

## Partial Test Success

When some tests pass but others fail:

```bash
# Extract pass/fail counts
passed=$(grep -c "^\[PASS\]" "$error_file")
failed=$(grep -c "^\[FAIL\]" "$error_file")

if [[ $failed -gt 0 ]]; then
  log_warn "$passed passed, $failed failed"
  # Include specific failures in feedback
  grep "^\[FAIL\]" "$error_file" >> feedback.txt
fi
```

## Timeout Handling

```bash
validate_with_timeout() {
  local timeout_secs=60

  if ! run_with_timeout "$timeout_secs" validate_step "$@"; then
    if [[ $? -eq 124 ]]; then  # timeout exit code
      echo "Validation timed out after ${timeout_secs}s" > "$error_file"
      echo "Possible infinite loop in code" >> "$error_file"
    fi
    return 1
  fi
}
```

## Implementation Status

- [x] Implemented build validation
- [x] Implemented test validation
- [x] Added validation type detection
- [x] Added error feedback extraction
- [x] Added timeout handling
- [ ] Add syntax check phase
- [ ] Add partial test success handling
- [ ] Add validation caching for unchanged code
