# Prompt ID: cairo-numerical-minimization-01

Task:
- Implement numerical function minimization using Golden Section Search in Cairo with proper fixed-point arithmetic and strong typing.

## Problem Description

Given a unimodal function f(x) and a bracketing interval [a, b], find the value x* that minimizes f(x) within the interval. A unimodal function has exactly one local minimum in the interval.

**Golden Section Search** is the optimal algorithm for minimizing a unimodal function without using derivatives. It achieves O(log(1/ε)) convergence where ε is the desired precision, using the golden ratio φ = (1 + √5) / 2 ≈ 1.618 to determine probe points.

**Fixed-Point Arithmetic**: Since Cairo has no native floating-point, use Q64.64 fixed-point representation where the value is stored as `i128` with 64 fractional bits. The actual value = stored_value / 2^64.

**Example 1:** Minimize f(x) = (x - 3)²
- Interval: [0, 5]
- Expected minimum: x* ≈ 3.0
- Minimum value: f(x*) ≈ 0.0

**Example 2:** Minimize f(x) = x² + 2x + 1 = (x + 1)²
- Interval: [-5, 5]
- Expected minimum: x* ≈ -1.0
- Minimum value: f(x*) ≈ 0.0

**Example 3:** Minimize f(x) = |x - 2| (V-shaped, still unimodal)
- Interval: [0, 4]
- Expected minimum: x* ≈ 2.0
- Minimum value: f(x*) ≈ 0.0

## Related Skills
- `cairo-quirks`
- `cairo-quality`

## Context

**CRITICAL - No Inherent Impls**: Cairo does NOT support `impl Type { }`. All methods must use traits.

**CRITICAL - No Fn Trait**: Cairo does NOT have Rust's `Fn`, `FnOnce`, or `FnMut` traits. You CANNOT use `+Fn<F, (T,), R>` bounds. Instead, define a custom trait (like `ObjectiveFn`) and pass structs implementing that trait.

**Fixed-Point Math**: Use i128 for Q64.64 representation. Multiplication requires shifting: `(a * b) >> 64`. Division requires pre-shifting: `(a << 64) / b`.

**No Floating Point**: Cairo has no f32/f64. All decimal values must use fixed-point.

**Generics with Traits**: Generic implementations need explicit trait bounds: `impl MyImpl<T, +Drop<T>, +Copy<T>> of MyTrait<T>`.

**Constants**: Define golden ratio and other constants as fixed-point values at compile time.

**Convergence**: Use absolute tolerance on interval width, not on function values.

---

## Step 1: Fixed-Point Type and Basic Operations

Create the Q64.64 fixed-point type with arithmetic operations.

**Requirements:**
- Define struct `Fixed` with field `value: i128` (the raw fixed-point representation)
- Implement `FixedTrait` with:
  - `fn new(value: i128) -> Fixed` - create from raw value
  - `fn from_int(n: i64) -> Fixed` - convert integer to fixed-point
  - `fn to_int(self: Fixed) -> i64` - truncate to integer
  - `fn abs(self: Fixed) -> Fixed` - absolute value
- Implement `Add`, `Sub`, `Mul`, `Div` for Fixed (use core::ops traits)
- Implement `PartialOrd` and `PartialEq` for Fixed
- Define constant `FRACTIONAL_BITS: u8 = 64`
- Define constant `ONE: Fixed` representing 1.0 in fixed-point

**Validation:** Code compiles with `scarb build`

---

## Step 2: Mathematical Constants and Helper Functions

Define golden ratio and convergence helpers.

**Requirements:**
- Define `PHI: Fixed` = golden ratio ≈ 1.618033988749895 (as fixed-point)
- Define `RESPHI: Fixed` = 2 - φ ≈ 0.381966011250105 (golden ratio complement)
- Create function `fn fixed_from_ratio(num: i64, denom: i64) -> Fixed` for precise constant creation
- Create function `fn interval_width(a: Fixed, b: Fixed) -> Fixed` returning |b - a|
- Create function `fn is_converged(width: Fixed, tolerance: Fixed) -> bool`

**Validation:** Code compiles with `scarb build`

---

## Step 3: Interval and Result Types

Create strong types for algorithm state and results.

**Requirements:**
- Define struct `Interval` with fields:
  - `low: Fixed` - lower bound
  - `high: Fixed` - upper bound
- Define struct `MinimizationResult` with fields:
  - `x_min: Fixed` - x value at minimum
  - `f_min: Fixed` - function value at minimum
  - `iterations: u32` - number of iterations used
  - `converged: bool` - whether tolerance was achieved
- Implement `IntervalTrait` with:
  - `fn new(low: Fixed, high: Fixed) -> Interval`
  - `fn width(self: @Interval) -> Fixed`
  - `fn midpoint(self: @Interval) -> Fixed`
  - `fn contains(self: @Interval, x: Fixed) -> bool`

**Validation:** Code compiles with `scarb build`

---

## Step 4: Objective Function Trait and Golden Section Search

Implement the core minimization algorithm using a trait-based approach.

**IMPORTANT - Cairo does NOT have Rust's Fn trait. Use a custom trait instead:**

**Requirements:**
- Define trait `ObjectiveFn` with:
  - `fn eval(self: @Self, x: Fixed) -> Fixed` - evaluate function at x
- Create function `golden_section_search<T, +ObjectiveFn<T>, +Drop<T>, +Copy<T>>(f: @T, interval: Interval, tolerance: Fixed, max_iterations: u32) -> MinimizationResult`
- Algorithm:
  1. Initialize: a = low, b = high
  2. Compute probe points: c = b - RESPHI * (b - a), d = a + RESPHI * (b - a)
  3. Evaluate f.eval(c) and f.eval(d)
  4. If f.eval(c) < f.eval(d): new interval is [a, d], reuse c as new d
  5. If f.eval(c) >= f.eval(d): new interval is [c, b], reuse d as new c
  6. Repeat until |b - a| < tolerance or max_iterations reached
  7. Return midpoint of final interval as x_min
- Must achieve O(log(1/tolerance)) convergence (golden ratio reduction per iteration)
- Handle edge case: interval width already below tolerance

**Validation:** Code compiles with `scarb build`

---

## Step 5: Public Interface and Minimizer Trait

Create clean API using the ObjectiveFn trait pattern.

**Requirements:**
- Define trait `MinimizerTrait<T>` with:
  - `fn minimize(f: @T, low: Fixed, high: Fixed) -> MinimizationResult` - default tolerance
  - `fn minimize_with_tolerance(f: @T, low: Fixed, high: Fixed, tolerance: Fixed) -> MinimizationResult`
  - `fn minimize_with_options(f: @T, interval: Interval, tolerance: Fixed, max_iter: u32) -> MinimizationResult`
- Implement `MinimizerImpl<T, +ObjectiveFn<T>, +Drop<T>, +Copy<T>>` using golden section search
- Default tolerance: 1e-10 (as fixed-point, approximately 2^-33)
- Default max_iterations: 1000
- Ensure all methods return consistent results

**Validation:** Code compiles with `scarb build`

---

## Step 6: Test Objective Functions

Create test objective functions as structs implementing ObjectiveFn.

**Requirements:**
- Create struct `QuadraticTest` (unit struct) implementing `ObjectiveFn`:
  - `eval(x) = (x - 3)²` with minimum at x=3
- Create struct `ShiftedParabola` implementing `ObjectiveFn`:
  - `eval(x) = x² + 2x + 1 = (x + 1)²` with minimum at x=-1
- Create struct `QuarticTest` implementing `ObjectiveFn`:
  - `eval(x) = (x - 1)⁴` with minimum at x=1 (flat near minimum)
- Each struct should have `#[derive(Drop, Copy)]`
- Each function should be verifiable: known minimum location and value

**Example pattern:**
```cairo
#[derive(Drop, Copy)]
struct QuadraticTest {}

impl QuadraticTestObjective of ObjectiveFn<QuadraticTest> {
    fn eval(self: @QuadraticTest, x: Fixed) -> Fixed {
        let diff = x - FixedTrait::from_int(3);
        diff * diff
    }
}
```

**Validation:** Code compiles with `scarb build`

---

## Step 7: Comprehensive Test Suite

Create exhaustive tests for correctness and edge cases.

**Requirements:**
- Test QuadraticTest minimum is within tolerance of x=3
- Test ShiftedParabola minimum is within tolerance of x=-1
- Test QuarticTest minimum is within tolerance of x=1 (harder due to flat region)
- Test convergence flag is true for all standard cases
- Test iteration count is reasonable (< 100 for tolerance 1e-6)
- Test with very tight tolerance (1e-12) still converges
- Test with loose tolerance (1e-2) converges in few iterations
- Test interval already at minimum (width < tolerance)
- Test symmetric interval around minimum
- Test asymmetric interval (minimum near one boundary)
- Test minimum at left boundary of interval
- Test minimum at right boundary of interval
- Test that f_min value is correct (not just x_min location)
- Verify golden ratio convergence rate: iterations ≈ log(width/tolerance) / log(φ)

**Example test pattern:**
```cairo
#[test]
fn test_quadratic_minimum() {
    let f = QuadraticTest {};
    let result = MinimizerImpl::minimize(@f, FixedTrait::from_int(0), FixedTrait::from_int(5));
    // x_min should be close to 3
    assert!(result.converged);
}
```

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use i128 for fixed-point representation (Q64.64)
- No floating-point types allowed
- Algorithm must be O(log(1/ε)) - no linear search
- All edge cases must be handled gracefully
- Strong typing required (no raw i128 in public API)

## Deliverable

Complete implementation with:
1. `Fixed` type with full arithmetic operations
2. `Interval` and `MinimizationResult` types
3. Golden section search with optimal convergence
4. Clean `MinimizerTrait` public interface
5. Multiple test functions with known minima
6. Comprehensive test suite (15+ test cases)
