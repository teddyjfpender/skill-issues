# Rubric for cairo-trapping-rain-water-01

## Pass Criteria

### Compilation (Required)
- [ ] Code compiles with `scarb build` without errors
- [ ] Code passes `scarb fmt --check` without changes

### Helper Functions (Required)
- [ ] `max(a: u32, b: u32) -> u32` function exists and works correctly
- [ ] `min(a: u32, b: u32) -> u32` function exists and works correctly

### Algorithm Implementations (Required - at least 2 of 3)
- [ ] `trap_brute_force` - O(n²) brute force solution exists
- [ ] `trap_dp` - O(n) time, O(n) space DP solution exists
- [ ] `trap` - O(n) time, O(1) space two-pointer solution exists

### Correctness (Required)
- [ ] Example 1: `[0,1,0,2,1,0,1,3,2,1,2,1]` returns `6`
- [ ] Example 2: `[4,2,0,3,2,5]` returns `9`
- [ ] Empty array returns `0`
- [ ] Single element returns `0`
- [ ] All implementations return identical results for same input

### Edge Cases (Required - at least 3 of 5)
- [ ] Handles empty array without panic
- [ ] Handles single element array
- [ ] Handles flat array (no water) - e.g., `[3,3,3,3]` -> `0`
- [ ] Handles strictly descending - e.g., `[5,4,3,2,1]` -> `0`
- [ ] Handles strictly ascending - e.g., `[1,2,3,4,5]` -> `0`

### Trait Interface (Bonus)
- [ ] `RainWaterTrait` trait defined with method signatures
- [ ] `RainWaterImpl` implements the trait
- [ ] `solve` method uses optimal (two-pointer) solution

### Tests (Required)
- [ ] Tests exist and run with `snforge test`
- [ ] At least 5 test functions
- [ ] Tests cover both LeetCode examples
- [ ] Tests cover edge cases (empty, single, flat)
- [ ] Tests verify multiple algorithms give same results

## Fail Criteria

Fail if ANY of these are true:
- Code does not compile with `scarb build`
- No working algorithm implementation exists
- Example 1 or Example 2 returns wrong result
- Empty array causes panic instead of returning 0
- No tests exist
- Tests fail

## Scoring Guide

| Score | Description |
|-------|-------------|
| 100% | All 3 algorithms + trait interface + comprehensive tests |
| 90% | All required criteria met, 2+ algorithms |
| 80% | Compiles, 1 correct algorithm, tests pass |
| 70% | Compiles, algorithm works for basic cases |
| 60% | Compiles, partial implementation |
| 0% | Does not compile or no working algorithm |

## Algorithm Complexity Reference

| Algorithm | Time | Space |
|-----------|------|-------|
| Brute Force | O(n²) | O(1) |
| Dynamic Programming | O(n) | O(n) |
| Two Pointer (Optimal) | O(n) | O(1) |
