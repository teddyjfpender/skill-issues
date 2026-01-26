# Rubric: cairo-trapping-rain-water-01

## Evaluation Criteria

### Step 1: Imports and Helper Functions (Build)
- [ ] Imports core traits as needed
- [ ] `max(a: u32, b: u32) -> u32` function exists
- [ ] `min(a: u32, b: u32) -> u32` function exists
- [ ] Code compiles with `scarb build`

### Step 2: Brute Force Solution (Build)
- [ ] `trap_brute_force(height: @Array<u32>) -> u32` function exists
- [ ] Handles empty array (returns 0)
- [ ] Implements O(n^2) approach correctly
- [ ] Code compiles with `scarb build`

### Step 3: Dynamic Programming Solution (Build)
- [ ] `trap_dp(height: @Array<u32>) -> u32` function exists
- [ ] Pre-computes left_max array
- [ ] Pre-computes right_max array
- [ ] Handles empty array (returns 0)
- [ ] Code compiles with `scarb build`

### Step 4: Two Pointer Solution (Build)
- [ ] `trap(height: @Array<u32>) -> u32` function exists
- [ ] Uses two pointer technique
- [ ] O(n) time, O(1) space complexity
- [ ] Handles empty array (returns 0)
- [ ] Code compiles with `scarb build`

### Step 5: Public Interface (Build)
- [ ] `RainWaterTrait` trait defined
- [ ] `RainWaterImpl` impl exists
- [ ] All three solutions accessible via trait
- [ ] `solve` method uses optimal solution
- [ ] Code compiles with `scarb build`

### Step 6: Tests (Test)
- [ ] Tests in `#[cfg(test)] mod tests`
- [ ] Example 1 test passes: [0,1,0,2,1,0,1,3,2,1,2,1] -> 6
- [ ] Example 2 test passes: [4,2,0,3,2,5] -> 9
- [ ] Empty array test passes -> 0
- [ ] Single element test passes -> 0
- [ ] Two elements test passes -> 0
- [ ] Flat array test passes [3,3,3,3] -> 0
- [ ] Descending test passes [5,4,3,2,1] -> 0
- [ ] Ascending test passes [1,2,3,4,5] -> 0
- [ ] V-shape test passes [5,0,5] -> 5
- [ ] All three solutions produce same results
- [ ] All tests pass with `snforge test`

## Scoring
- Steps 1-5: Build validation (5 points each)
- Step 6: Test validation (10 points)
- Total: 35 points
