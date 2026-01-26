# Feature Improvement: Inline Test Detection

**ID**: 006
**Status**: Fixed
**Priority**: Critical
**Created**: 2026-01-26

## Problem

The `verify.sh` script only detected tests in separate `tests/*.cairo` directories, not inline tests using `#[cfg(test)] mod tests { ... }` in source files.

This caused the ralph-loop to report **SUCCESS** for code that actually had **failing tests**, because the test step was skipped with "no tests found".

## Impact

- **False positives**: Code passed verification even though tests fail
- **Wasted iterations**: Driver wasn't getting feedback about test failures
- **Broken output**: `final.cairo` contained code that doesn't actually work

## Root Cause

```bash
# OLD - only checked for tests directory
has_tests() {
  find "$project_dir" -type f -path "*/tests/*.cairo" -print -quit 2>/dev/null | grep -q .
}
```

Cairo supports two test patterns:
1. **Separate directory**: `tests/*.cairo` files
2. **Inline tests**: `#[cfg(test)] mod tests { ... }` in source files

The driver generated inline tests (which is valid and common in Cairo), but `has_tests()` only looked for pattern 1.

## Fix Applied

```bash
# NEW - checks both patterns
has_tests() {
  # Check for tests directory OR inline #[test] attributes in source files
  find "$project_dir" -type f -path "*/tests/*.cairo" -print -quit 2>/dev/null | grep -q . && return 0
  grep -rq '#\[test\]' "$project_dir/src" 2>/dev/null && return 0
  return 1
}
```

## Verification

Before fix:
```json
{
  "step": "test",
  "status": "skipped",
  "message": "no tests found"
}
```

After fix:
```json
{
  "step": "test",
  "status": "fail",
  "exit_code": 2
}
```

## Lessons Learned

1. **False success is worse than failure**: A skipped step that should have run masks real issues
2. **Test both patterns**: Cairo code can have tests in either location
3. **Verify verification**: The verification system itself needs testing

## Related Files

- `eval/verify.sh`
