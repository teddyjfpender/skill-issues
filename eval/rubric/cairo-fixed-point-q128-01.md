# Rubric for cairo-fixed-point-q128-01

## Build & Test Requirements

Pass if:
- The file compiles with `scarb build`
- All tests pass with `snforge test`

Fail if:
- Code does not compile
- Any test fails

## Type Definition

Pass if:
- `SQ128x128` struct exists with an `i256` (or equivalent 256-bit signed) raw field
- The type correctly represents Q128.128 fixed-point (128 integer + 128 fractional bits)

Fail if:
- Uses wrong bit width (e.g., u256 unsigned instead of signed, or wrong total bits)
- Missing raw field accessor

## Constants

Pass if:
- `ZERO` has raw = 0
- `ONE` has raw = 2^128
- `NEG_ONE` has raw = -2^128
- `MIN` has raw = -2^255
- `MAX` has raw = 2^255 - 1
- Constants are correctly typed as SQ128x128

Fail if:
- Any constant has incorrect raw value
- Constants missing

## Construction & Conversion

Pass if:
- `from_raw(i256) -> SQ128x128` correctly wraps value
- `to_raw() -> i256` correctly extracts value
- `from_int(i128) -> SQ128x128` correctly scales by 2^128 with overflow check

Fail if:
- Conversion loses precision
- `from_int` doesn't overflow-check

## Comparison

Pass if:
- Equality comparison works on raw values
- Ordering comparison works correctly for signed values
- Handles negative vs positive correctly

Fail if:
- Comparison treats raw as unsigned
- Missing PartialEq or PartialOrd implementation

## Addition & Subtraction

Pass if:
- Results are mathematically exact (no rounding)
- Overflow detection works for signed arithmetic
- `add(a, b)` where `a + b` exceeds MAX or goes below MIN triggers overflow
- `sub(a, b)` with overflow triggers correctly

Fail if:
- Arithmetic is incorrect
- Missing overflow checks
- Treats values as unsigned

## Delta Operation

Pass if:
- `delta(a, b)` returns `b - a`
- `delta(a, a) == ZERO` for any a
- `a + delta(a, b) == b` property holds (when no overflow)

Fail if:
- Delta computed incorrectly (e.g., a - b instead of b - a)
- Missing or incorrect implementation

## Multiplication (Critical)

Pass if:
- Uses 512-bit intermediate precision for `a.raw * b.raw`
- Correctly divides by 2^128 (shifts right by 128 bits)
- `mul_down` implements floor rounding (toward -∞)
- `mul_up` implements ceiling rounding (toward +∞)
- `mul_*(x, ONE) == x` for all x
- `mul_*(x, ZERO) == ZERO` for all x
- `mul_down(a, b) <= exact <= mul_up(a, b)` (bounding property)
- `mul_up.raw - mul_down.raw ∈ {0, 1}` (at most 1 ULP difference)
- Overflow checked on final result

Fail if:
- Uses only 256-bit intermediate (loses precision, incorrect results)
- Rounding is incorrect for negative products
- Multiplication identities don't hold
- Missing overflow check on result
- Bounding property violated

## 512-bit Arithmetic Implementation

Pass if:
- Correctly implements wide multiplication (256×256 → 512-bit)
- Handles signed multiplication correctly (sign extension or abs+sign)
- 128-bit right shift preserves sign for arithmetic shift
- Remainder detection for rounding works correctly

Fail if:
- Truncates to 256-bit before division (loses precision)
- Sign handling incorrect for negative operands
- Shift doesn't preserve sign (logical vs arithmetic)

## Test Coverage

Pass if:
- Tests for all constants
- Tests for add/sub overflow edge cases
- Tests for delta properties
- Tests for multiplication identities
- Tests for rounding behavior (values with non-zero remainders)
- Tests for negative × negative, negative × positive cases

Fail if:
- Missing tests for overflow conditions
- Missing tests for rounding correctness
- No negative number test cases

## Code Quality

Pass if:
- Uses appropriate traits (Add, Sub, Mul, PartialEq, PartialOrd)
- Clear separation of concerns
- Deterministic behavior (no undefined behavior on any input)

Fail if:
- Undefined behavior possible
- Non-deterministic (different results for same inputs)

## Scoring Summary

| Category | Weight | Pass Criteria |
|----------|--------|---------------|
| Compiles | Required | `scarb build` succeeds |
| Tests Pass | Required | `snforge test` all pass |
| Type Definition | 10% | Correct struct with i256 raw |
| Constants | 10% | All 5 constants correct |
| Add/Sub | 15% | Exact arithmetic, overflow checked |
| Delta | 10% | Correct signed difference |
| Multiplication | 35% | 512-bit precision, correct rounding |
| Test Coverage | 20% | Edge cases covered |

**Minimum passing score**: All required + 70% weighted score
