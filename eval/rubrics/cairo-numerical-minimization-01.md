# Rubric: cairo-numerical-minimization-01

## Evaluation Criteria

### Step 1: Fixed-Point Type and Basic Operations (Build)
- [ ] Struct `Fixed` exists with `value: i128` field
- [ ] `FixedTrait` trait defined with required methods
- [ ] `new(value: i128) -> Fixed` constructor exists
- [ ] `from_int(n: i64) -> Fixed` converts integer correctly (shifts left by 64)
- [ ] `to_int(self: Fixed) -> i64` truncates correctly (shifts right by 64)
- [ ] `abs(self: Fixed) -> Fixed` handles negative values
- [ ] `Add<Fixed>` implemented with correct i128 addition
- [ ] `Sub<Fixed>` implemented with correct i128 subtraction
- [ ] `Mul<Fixed>` implemented with shift: `(a * b) >> 64`
- [ ] `Div<Fixed>` implemented with pre-shift: `(a << 64) / b`
- [ ] `PartialOrd<Fixed>` implemented for comparisons
- [ ] `PartialEq<Fixed>` implemented for equality
- [ ] Constant `FRACTIONAL_BITS` = 64 defined
- [ ] Constant `ONE` represents 1.0 correctly (value = 2^64)
- [ ] Code compiles with `scarb build`

### Step 2: Mathematical Constants and Helper Functions (Build)
- [ ] `PHI: Fixed` defined as golden ratio ≈ 1.618033988749895
- [ ] `RESPHI: Fixed` defined as ≈ 0.381966011250105 (2 - φ)
- [ ] PHI and RESPHI are mathematically consistent: PHI + RESPHI ≈ 2.0
- [ ] `fixed_from_ratio(num: i64, denom: i64) -> Fixed` exists
- [ ] `interval_width(a: Fixed, b: Fixed) -> Fixed` returns |b - a|
- [ ] `is_converged(width: Fixed, tolerance: Fixed) -> bool` compares correctly
- [ ] Constants are compile-time or efficiently computed
- [ ] Code compiles with `scarb build`

### Step 3: Interval and Result Types (Build)
- [ ] Struct `Interval` exists with `low: Fixed` and `high: Fixed` fields
- [ ] Struct `MinimizationResult` exists with all required fields:
  - `x_min: Fixed`
  - `f_min: Fixed`
  - `iterations: u32`
  - `converged: bool`
- [ ] `IntervalTrait` defined with required methods
- [ ] `Interval::new(low, high)` constructor exists
- [ ] `Interval::width()` returns high - low correctly
- [ ] `Interval::midpoint()` returns (low + high) / 2 correctly
- [ ] `Interval::contains(x)` checks low <= x <= high
- [ ] Types have appropriate derives (#[derive(Drop, Copy, ...)])
- [ ] Code compiles with `scarb build`

### Step 4: Golden Section Search Algorithm (Build)
- [ ] Function `golden_section_search` exists with correct signature
- [ ] Accepts a function/closure parameter for objective function
- [ ] Correctly initializes probe points using RESPHI
- [ ] Probe point c = b - RESPHI * (b - a) calculated correctly
- [ ] Probe point d = a + RESPHI * (b - a) calculated correctly
- [ ] Correctly compares f(c) vs f(d) to choose new interval
- [ ] Reuses function evaluations (only 1 new eval per iteration)
- [ ] Terminates when interval width < tolerance
- [ ] Terminates when max_iterations reached
- [ ] Returns midpoint of final interval as x_min
- [ ] Correctly computes f_min at the returned x_min
- [ ] Sets converged=true only when tolerance achieved
- [ ] Sets correct iteration count
- [ ] Handles edge case: initial width < tolerance
- [ ] Algorithm achieves O(log(1/tolerance)) convergence
- [ ] Code compiles with `scarb build`

### Step 5: Public Interface and Minimizer Trait (Build)
- [ ] Trait `MinimizerTrait` defined
- [ ] Method `minimize` with default parameters exists
- [ ] Method `minimize_with_tolerance` exists
- [ ] Method `minimize_with_options` exists with full control
- [ ] `MinimizerImpl` implements trait using golden section search
- [ ] Default tolerance is approximately 1e-10 in fixed-point
- [ ] Default max_iterations is 1000 or similar reasonable value
- [ ] All methods return `MinimizationResult`
- [ ] Public API uses strong types (Fixed, Interval) not raw i128
- [ ] Code compiles with `scarb build`

### Step 6: Test Functions (Build)
- [ ] `quadratic_test(x) = (x - 3)²` implemented correctly
- [ ] `shifted_parabola(x) = x² + 2x + 1` implemented correctly
- [ ] `quartic_test(x) = (x - 1)⁴` implemented correctly
- [ ] `asymmetric_test(x)` or similar non-symmetric function exists
- [ ] All functions use Fixed-point arithmetic correctly
- [ ] Functions are mathematically correct (verifiable minima)
- [ ] No integer overflow in test function calculations
- [ ] Code compiles with `scarb build`

### Step 7: Comprehensive Test Suite (Test)
- [ ] Test: quadratic_test minimum ≈ 3.0 (within tolerance)
- [ ] Test: shifted_parabola minimum ≈ -1.0 (within tolerance)
- [ ] Test: quartic_test minimum ≈ 1.0 (within tolerance)
- [ ] Test: convergence flag is true for standard cases
- [ ] Test: iteration count < 100 for tolerance 1e-6
- [ ] Test: tight tolerance (1e-12) still converges
- [ ] Test: loose tolerance (1e-2) converges quickly (< 20 iterations)
- [ ] Test: interval already below tolerance returns immediately
- [ ] Test: symmetric interval around minimum
- [ ] Test: asymmetric interval (minimum near boundary)
- [ ] Test: minimum at/near left boundary
- [ ] Test: minimum at/near right boundary
- [ ] Test: f_min value is correct (close to 0 for test functions)
- [ ] Test: convergence rate matches theory (iterations ≈ log(width/tol)/log(φ))
- [ ] At least 15 distinct test cases
- [ ] All tests pass with `snforge test`

## Scoring

### Per-Step Points
- Step 1: Fixed-Point Type (15 points)
  - Struct and basic operations: 5 points
  - Arithmetic operators: 5 points
  - Comparison operators: 3 points
  - Constants: 2 points

- Step 2: Constants and Helpers (10 points)
  - Golden ratio constants: 5 points
  - Helper functions: 5 points

- Step 3: Interval and Result Types (10 points)
  - Struct definitions: 5 points
  - Trait methods: 5 points

- Step 4: Golden Section Search (20 points)
  - Correct algorithm structure: 8 points
  - Proper convergence logic: 6 points
  - Edge case handling: 3 points
  - Optimal complexity: 3 points

- Step 5: Public Interface (10 points)
  - Trait definition: 4 points
  - Implementation: 4 points
  - Sensible defaults: 2 points

- Step 6: Test Functions (10 points)
  - Correct implementations: 6 points
  - Variety of shapes: 4 points

- Step 7: Test Suite (25 points)
  - Basic correctness tests: 10 points
  - Edge case tests: 8 points
  - Convergence verification: 4 points
  - Coverage breadth (15+ tests): 3 points

### Total: 100 points

### Grade Thresholds
- 90-100: Excellent - Production ready
- 75-89: Good - Minor issues
- 60-74: Acceptable - Functional but needs work
- 40-59: Partial - Core algorithm works, missing pieces
- < 40: Incomplete - Significant gaps

## Quality Criteria (Bonus/Deductions)

### Bonus (+5 each, max +10)
- [ ] No unused imports or lint warnings
- [ ] Comprehensive documentation with complexity analysis
- [ ] Additional algorithm variant (e.g., Brent's method)

### Deductions (-5 each)
- [ ] Uses linear search instead of golden section
- [ ] Incorrect fixed-point arithmetic (overflow, wrong shifts)
- [ ] Algorithm doesn't achieve logarithmic convergence
- [ ] Public API exposes raw i128 instead of Fixed type
- [ ] Test functions have wrong minima locations
