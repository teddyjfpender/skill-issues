# Rubric for cairo-fixed-point-q128-01

## Build & Test Requirements

**Pass if:**
- The file compiles with `scarb build`
- All tests pass with `snforge test`

**Fail if:**
- Code does not compile
- Any test fails

## Type Definition (10%)

**Pass if:**
- `SQ128x128` struct exists with an `I256` raw field
- `I256` uses sign-magnitude representation (`mag: U256`, `neg: bool`)
- `U256` represented as 4 x 64-bit limbs (or equivalent)
- Types have appropriate derives (`Copy`, `Drop`, `Serde`, `Debug`)

**Fail if:**
- Uses wrong representation (e.g., two's complement without proper handling)
- Missing raw field accessor
- Types are not `Copy`

## Invariant Enforcement (15%)

**Pass if:**
- Has a constructor function (e.g., `i256_new`) that enforces no negative zero
- Constructor normalizes: `neg: neg && !u256_is_zero(mag)`
- ALL I256 creation goes through the constructor
- Defensive normalization in `eq` and `cmp` functions

**Fail if:**
- Allows negative zero to exist
- Creates I256 directly without normalization
- `eq` or `cmp` could return inconsistent results for negative zero

**Bonus:**
- Normalize in `Hash` for consistency with `Eq`

## API Safety (10%)

**Pass if:**
- `from_raw_unchecked` clearly named with `_unchecked` suffix
- `from_raw_checked` provided, returns `Option<SQ128x128>`
- `from_raw_checked` validates magnitude is in range for the sign
- Documentation warns about safety requirements

**Fail if:**
- Unchecked function named just `from_raw` (misleading)
- No checked alternative for untrusted input
- Range validation missing or incorrect

## Constants (5%)

**Pass if:**
- `ZERO` has mag = 0, neg = false
- `ONE` has mag = 2^128, neg = false
- `NEG_ONE` has mag = 2^128, neg = true
- `MIN` has mag = 2^255, neg = true
- `MAX` has mag = 2^255 - 1, neg = false
- `ONE_ULP` has mag = 1, neg = false

**Fail if:**
- Any constant has incorrect value
- Constants missing

## Arithmetic Operations (20%)

### Addition & Subtraction

**Pass if:**
- Results are mathematically exact
- Overflow detection works for both same-sign and opposite-sign cases
- Checked versions return `Option::None` on overflow
- Panicking versions call checked with `.expect()`

**Fail if:**
- Arithmetic is incorrect
- Missing overflow checks
- Treats values as unsigned incorrectly

### Negation

**Pass if:**
- `checked_neg(MIN)` returns `Option::None`
- `checked_neg(MAX)` succeeds
- `Neg` trait panics on MIN with clear error message
- Uses `i256_new` constructor after flipping sign

**Fail if:**
- Negating MIN succeeds (should overflow)
- Missing check for MIN value
- Doesn't normalize after negation

### Delta

**Pass if:**
- `delta(a, b)` returns `b - a`
- `delta(a, a) == ZERO`
- `a + delta(a, b) == b` property holds

**Fail if:**
- Delta computed as `a - b` instead of `b - a`

## Multiplication (25%)

**Pass if:**
- Uses 512-bit intermediate precision for magnitude product
- Correctly extracts 256-bit result after 128-bit shift
- Overflow detection checks limbs 6-7 are zero (after accounting for shift)
- `mul_down` implements floor rounding (toward -infinity)
- `mul_up` implements ceiling rounding (toward +infinity)
- Identity: `ONE * x == x` for all valid x
- Identity: `ZERO * x == ZERO`
- Sign handling: `neg_result = a.neg != b.neg`
- Rounding: For negative results with remainder, `mul_down` adds 1 to magnitude
- Rounding: For positive results with remainder, `mul_up` adds 1 to magnitude
- Range validation on result magnitude

**Fail if:**
- Uses only 256-bit intermediate (loses precision)
- Rounding incorrect for negative products
- Multiplication identities don't hold
- Missing overflow check on result
- Sign handling incorrect

## Trait Implementations (10%)

**Pass if:**
- `PartialEq` implemented with `@Self` parameters (snapshots)
- `PartialOrd` implements all four methods (`lt`, `le`, `gt`, `ge`)
- `Add`, `Sub`, `Mul` traits implemented
- `Neg` trait implemented with overflow check
- `Zero` and `One` from `core::num::traits`
- `Hash` normalizes input for consistency with `Eq`
- `Mul` documentation states rounding behavior (floor)

**Fail if:**
- `PartialEq` uses wrong parameter types (not snapshots)
- Missing comparison methods
- `Hash` inconsistent with `Eq` for negative zero
- `Neg` doesn't handle MIN overflow

## Code Quality (5%)

**Pass if:**
- Uses helper functions for limb access (reduces copy-paste)
- Checked arithmetic as core, panicking as wrappers
- Clear separation of concerns
- Named constants for magic values (e.g., `TWO_POW_64`)
- Uses `/ TWO_POW_64` not magic hex for bit extraction

**Fail if:**
- Massive copy-paste code for each limb
- Panicking and checked logic duplicated
- Magic numbers without constants
- File is excessively large (>1500 lines for this scope)

## Test Coverage (10%)

**Pass if:**
- Tests for all constants
- Tests for add/sub overflow edge cases
- Tests for `checked_neg(MIN)` returning None
- Tests for multiplication identities
- Tests for rounding behavior (values with non-zero remainders)
- Tests for negative zero normalization
- Tests for comparison ordering
- Tests for `from_raw_checked` rejecting out-of-range values

**Fail if:**
- Missing tests for negation overflow
- Missing tests for invariant (negative zero)
- No negative number test cases
- No rounding tests

## Scoring Summary

| Category | Weight | Key Criteria |
|----------|--------|--------------|
| Compiles | Required | `scarb build` succeeds |
| Tests Pass | Required | `snforge test` all pass |
| Type Definition | 10% | Sign-magnitude I256, proper derives |
| Invariant Enforcement | 15% | Constructor pattern, defensive normalization |
| API Safety | 10% | Unchecked naming, checked alternative |
| Constants | 5% | All 6 constants correct |
| Arithmetic | 20% | Overflow checked, neg MIN handled |
| Multiplication | 25% | 512-bit precision, correct rounding |
| Traits | 10% | PartialEq/Ord, Neg overflow, Hash consistency |
| Code Quality | 5% | Helpers, no duplication |
| Test Coverage | 10% | Edge cases, invariants |

**Minimum passing score**: All required + 70% weighted score

## High-Severity Issues (Automatic Fail)

These issues indicate fundamental correctness problems:

1. **Neg overflow on MIN not handled**: Negating MIN must fail/return None
2. **Negative zero allowed**: Must normalize to positive zero
3. **Hash inconsistent with Eq**: Same values must hash the same
4. **Multiplication without 512-bit precision**: Will produce incorrect results
5. **from_raw allows arbitrary input without validation**: Security issue
