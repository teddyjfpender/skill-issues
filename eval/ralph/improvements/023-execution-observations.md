# 023: Execution Observations - Cairo Step-Loop

## Run Details
- Date: 2026-01-26
- Primary Analysis: cairo-matrix-algebra-01
- Pending: cairo-trapping-rain-water-01
- Backend: claude
- Project Type: library

## Observations from cairo-matrix-algebra-01

### Issue 1: Output Format Violation on First Attempt
**Step:** 3 (Attempt 1), 5 (Attempt 1)
**Description:** The model output explanatory text instead of a code block, despite format instructions. Step-003 attempt-001 contained:
```
I need permission to edit the Cairo file to implement Step 3. The code implements:
1. **Construction methods**: ...
```
Step-005 attempt-001 contained:
```
I've successfully implemented all four arithmetic operations for Step 5:
1. **add**: Element-wise addition with dimension checking...
```
**Impact:** Wasted iteration; recovery required second attempt
**Suggested Fix:**
1. Even stronger output format enforcement at start of prompt
2. Add format validation before extraction that logs violations
3. Consider prepending "```cairo" to prime the model

### Issue 2: Test Logic Bugs Persist Across Retries
**Step:** 12 (All 3 attempts)
**Description:** Tests failed with `Option::unwrap failed` across all attempts, but with DIFFERENT failing tests each time:
- Attempt 1: `test_mul_dimension_validation`, `test_add_dimension_mismatch` (29 passed, 2 failed)
- Attempt 2: `test_matrix_vector_mul_known_result` (30 passed, 1 failed)
- Attempt 3: `test_transpose_twice_returns_original`, `test_mul_dimension_validation` (29 passed, 2 failed)
**Impact:** Step 12 failed after max retries (run stuck at step 12)
**Root Cause:** Tests use helper functions that create matrices with wrong data. The test `test_transpose_twice_returns_original` uses `array_vector_3()` which only has 3 elements, but tries to create a 2x3 matrix (needs 6 elements).
**Suggested Fix:**
1. Error feedback should highlight the SPECIFIC test code that failed, not just the test name
2. Include the test source code in retry prompts for test failures
3. Add static analysis to catch obvious test bugs (array size mismatches)

### Issue 3: Lint Warnings Not Causing Step Failure
**Step:** 12 (Attempt 3)
**Description:** Compiler warnings about unused variables:
```
warn[E0001]: Unused variable. Consider ignoring by prefixing with `_`.
 --> lib.cairo:559:13
        let matrix = make_matrix(2_u32, 3_u32, array_vector_3().clone());
            ^^^^^^
```
**Impact:** Warnings indicate code quality issues that could signal bugs
**Suggested Fix:**
1. Consider treating warnings as hints in error feedback
2. Option to treat specific warnings as errors (--deny-warnings mode)
3. Log warnings to separate metrics for analysis

### Issue 4: Run Did Not Complete (Stuck at Step 12)
**Step:** 12
**Description:** `step-state.json` shows `current_step: 12` with accumulated code from step 11. No `final.cairo` or `metrics.json` found.
**Impact:** Run could not complete all 12 steps; no final metrics available
**Suggested Fix:**
1. Consider partial success modes (accept N of M tests passing)
2. Add "best effort" mode that saves partial progress even on failure
3. Increase max_retries for test steps specifically

### Issue 5: File Lock Blocking During Tests
**Step:** All test steps
**Description:** Test output shows:
```
Blocking waiting for file lock on package cache
Blocking waiting for file lock on package cache
```
**Impact:** Adds latency to test runs; indicates potential concurrency issues
**Suggested Fix:**
1. Use dedicated cache directories per run
2. Add `--offline` flag after initial dependency fetch
3. Investigate parallel execution conflicts

### Issue 6: No Metrics File Generated
**Step:** N/A (Run-level)
**Description:** Expected `metrics.json` file not found in state directory
**Impact:** Cannot analyze run statistics for improvement
**Suggested Fix:**
1. Verify `metrics.py` is being called correctly
2. Check if metrics are only written on successful completion
3. Consider writing partial metrics on failure

### Issue 7: Scaffolding Package Name Mismatch (FIXED)
**Step:** Project setup
**Description:** `scarb new` created a directory called `cairo_project` instead of using the work-dir basename. This happened because `scarb new` was called without specifying the package name.
**Impact:** Project created in wrong location; subsequent operations failed
**Fix Applied:**
```bash
local dir_name=$(basename "$project_dir")
local package_name=$(echo "$dir_name" | tr '-' '_')
(cd "$parent_dir" && scarb new "$package_name" --no-vcs --test-runner=starknet-foundry)
```
**Status:** ✅ Fixed in step-loop.sh

### Issue 8: Sample Integration Test References Non-Existent Contract (FIXED)
**Step:** Project setup (library projects)
**Description:** `scarb new --test-runner=starknet-foundry` creates `tests/test_contract.cairo` with:
```cairo
use cairo_trapping_rain_water_01::HelloStarknet;
```
This references a `HelloStarknet` contract that doesn't exist for library projects.
**Impact:** Tests fail immediately for library-type projects
**Fix Applied:** For library projects, remove `test_contract.cairo` and create `test_lib.cairo` with proper imports:
```bash
if [[ "$project_type" == "library" ]]; then
  rm -f "$project_dir/tests/test_contract.cairo"
  cat > "$project_dir/tests/test_lib.cairo" << TESTEOF
use ${package_name}::*;
// Integration tests will be generated here
TESTEOF
fi
```
**Status:** ✅ Fixed in step-loop.sh

### Issue 9: Bash Variable Declaration Outside Function (FIXED)
**Step:** Main loop execution
**Description:** Line 953 had `local escaped_feedback=...` in the main loop, but `local` keyword is only valid inside functions.
**Impact:** Bash syntax error causing script failure
**Fix Applied:** Removed `local` keyword from the variable declaration.
**Status:** ✅ Fixed in step-loop.sh

## What Worked Well

1. **Scaffolding**: The `scarb new --test-runner=starknet-foundry` scaffolding worked correctly (after fixes)
2. **Recovery on Retry**: When first attempt produced no code block, retry with error feedback succeeded (step 3, 5)
3. **Build Validation**: Build-only steps (1-11) passed reliably
4. **Code Accumulation**: Previously verified code was correctly preserved across steps
5. **Trait Bounds**: Model correctly added complex trait bounds (`+Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>`)
6. **Step Ordering**: Steps processed in correct order with proper state management
7. **Anti-Research Directives**: Model generated code immediately without exploring codebase
8. **Skill Embedding**: cairo-quirks content correctly embedded in prompts
9. **Import Guidance**: Model followed prelude vs explicit import rules correctly

## Recommendations

### Priority 1: Test Step Improvements
1. **Include test source in retry feedback**: When a test fails, show the failing test code
2. **Pre-validate test data**: Check that helper function return values match usage
3. **Consider partial pass thresholds**: e.g., 90% tests pass = step success for final steps

### Priority 2: Output Format Hardening
1. **Add validation before extraction**: Log when format requirements are violated
2. **Metrics for format compliance**: Track how often first attempt has correct format
3. **Model-specific prompts**: Some models may need different format instructions

### Priority 3: Run Resilience
1. **Save partial metrics on failure**: Even if run fails, capture what completed
2. **Best-effort final output**: If step N fails, save step N-1 as best result
3. **Retry escalation**: Increase context/detail on each retry attempt

### Priority 4: Observability
1. **Log file lock events**: Track if this is consistent issue
2. **Track attempt durations**: Identify which steps take longest
3. **Create run summary even on failure**: Include steps completed, tests passed, etc.

## Implementation Status

### Completed This Session
- [x] Fix scaffolding to use correct package name from work-dir basename
- [x] Add `--project-type` flag (library vs contract)
- [x] Remove sample contract test for library projects
- [x] Create proper test_lib.cairo template for library projects
- [x] Fix bash variable declaration outside function
- [x] Add metrics tracking system (metrics.py, metrics.schema.json, metrics-report.py)
- [x] Add scarb lint/fmt integration (cairo-tooling skill)
- [x] Create prompt template generator (generate-prompt.py)
- [x] Add output format recovery strategies (recover-output.sh)
- [x] Add prompt linter/validator (lint-prompt.py)
- [x] Create step extraction module with tests (step_extractor.py)
- [x] Update cairo-quirks skill with felt252 limits, import cheat sheet, trait bounds

### Completed (Session 2)
- [x] Include test source code in retry prompts for test failures
  - Added `extract_failing_test_source()` function using Python to parse Cairo test functions
  - Integrates failing test source code into error feedback for retries
- [x] Add format validation logging before code extraction
  - Added `validate_output_format()`, `log_format_violation()`, `print_format_violations_summary()`
  - Logs violations to `format-violations.log` with timestamps and context
- [x] Implement partial metrics save on failure
  - Updated `finalize_metrics()` to accept `steps_completed` and `best_code_path`
  - Saves best code achieved even when run fails
- [x] Add lint warning tracking to metrics
  - Added `count_lint_warnings()`, `record_lint_metrics()` functions
  - Added `lint` command to metrics.py CLI
  - Tracks total warnings, warnings fixed, per-step breakdown
- [x] Investigate and fix file lock contention
  - Added `setup_isolated_environment()` with per-run SCARB_CACHE
  - Added `--offline` flag support after initial dependency fetch
  - Added `--cleanup-cache` CLI flag for optional cache cleanup
- [x] Add scarb lint --fix before validation
  - Added `auto_format()` and `auto_fix_lint()` functions
  - Runs `scarb fmt` and `scarb lint --fix` before validation

### Pending
- [ ] Add pre-validation for test helper functions
- [ ] Partial pass thresholds for test steps (e.g., 90% pass = success)
- [ ] Retry escalation with increased context on each attempt

## Summary

This session made significant progress on the ralph step-loop system:

**Infrastructure Improvements:**
- Metrics tracking for runs (time, iterations, steps, correctness)
- Tooling integration (scarb fmt, scarb lint)
- Prompt generation templates (3 templates: library, contract, algorithm)
- Output recovery strategies for malformed responses
- Step extraction with comprehensive test coverage (43 tests)

**Scaffolding Fixes:**
- Proper package naming from directory basename
- Library vs contract project type support
- Clean test structure for library projects

**Skill Enhancements:**
- felt252 string limits documentation
- Import cheat sheet (what's in prelude vs needs import)
- Trait bounds cheat sheet for generics

**Observations from Execution:**
- 11/12 steps completed successfully for cairo-matrix-algebra-01
- Build validation highly reliable
- Test steps need more robust error feedback
- Output format violations recoverable on retry

The main remaining challenge is test step failures where the generated tests themselves have bugs that persist across retries.
