# Rubric: <prompt-id>

## Evaluation Criteria

### Step 1: Imports and Helper Functions (Build)
- [ ] Imports required traits from core library
- [ ] Helper function `max(a: u32, b: u32) -> u32` exists
- [ ] Helper function `min(a: u32, b: u32) -> u32` exists
- [ ] Code compiles with `scarb build`

### Step 2: Core Algorithm (Build)
- [ ] Function `<name>(<params>) -> <return>` exists
- [ ] Handles empty input correctly (returns 0)
- [ ] Handles single element correctly
- [ ] Implements algorithm correctly
- [ ] Code compiles with `scarb build`

### Step 3: Optimized Algorithm (Build)
- [ ] Function `<name>_optimized(<params>) -> <return>` exists
- [ ] Uses <optimization technique>
- [ ] Achieves O(n) time complexity
- [ ] Achieves O(1) space complexity
- [ ] Produces same results as Step 2 implementation
- [ ] Code compiles with `scarb build`

### Step 4: Public Interface (Build)
- [ ] Trait `<Name>Trait` defined with required methods
- [ ] Impl `<Name>Impl` implements trait correctly
- [ ] `solve` method uses optimal implementation
- [ ] All algorithm variants accessible via trait
- [ ] Code compiles with `scarb build`

### Step 5: Tests (Test)
- [ ] Tests in `#[cfg(test)] mod tests` block
- [ ] Example 1 test passes: <input> -> <expected>
- [ ] Example 2 test passes: <input> -> <expected>
- [ ] Empty input test passes: [] -> 0
- [ ] Single element test passes: [x] -> <expected>
- [ ] Edge case test passes: <description> -> <expected>
- [ ] All algorithm variants produce identical results
- [ ] All tests pass with `snforge test`

## Scoring
- Step 1: Setup (5 points)
- Step 2: Core Algorithm (10 points)
- Step 3: Optimized Algorithm (10 points)
- Step 4: Public API (5 points)
- Step 5: Tests (10 points)
- Total: 40 points

### Grade Thresholds
- 36-40: Excellent
- 28-35: Good
- 20-27: Acceptable
- < 20: Needs improvement
