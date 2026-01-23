# Prompt ID: cairo-fixed-point-q128-01

Task:
- Implement a Q128.128 signed fixed-point number type in Cairo for deterministic on-chain arithmetic.

## Related Skills
- `cairo-numeric-types`: Invariant enforcement, checked/unchecked APIs, trait implementations
- `cairo-operator-overloading`: Add, Sub, Mul, Neg trait implementations
- `cairo-quirks`: Language-specific gotchas (no bit shifts, array indexing, etc.)
- `cairo-testing`: Test attributes, assertions, panic testing

## Overview

Q128.128 is a binary fixed-point representation where:
- **128 integer bits** (signed, using sign-magnitude representation)
- **128 fractional bits**
- Stored as an `I256` (sign-magnitude: `mag: U256`, `neg: bool`)
- Real value = `raw.mag / 2^128` with sign from `raw.neg`
- ULP (unit in last place) = `2^-128`

This format is ideal for DeFi applications requiring exact arithmetic without floating-point non-determinism.

## Type Definitions

### Recommended Structure (Sign-Magnitude)

```cairo
#[derive(Copy, Drop, Serde, Debug)]
pub struct U256 {
    pub limb0: u64, pub limb1: u64, pub limb2: u64, pub limb3: u64,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct I256 {
    pub mag: U256,
    pub neg: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct SQ128x128 {
    pub raw: I256,
}
```

### Critical Invariant: No Negative Zero

Use a constructor function that enforces the invariant:

```cairo
fn i256_new(mag: U256, neg: bool) -> I256 {
    I256 { mag, neg: neg && !u256_is_zero(mag) }
}
```

ALL code that creates I256 values should use this constructor.

## Value Range

For the sign-magnitude representation:
- **Minimum**: `-2^127` (mag = `0x8000...0000`, neg = true)
- **Maximum**: `2^127 - 2^-128` (mag = `0x7FFF...FFFF`, neg = false)

Note: The positive and negative ranges are asymmetric (MIN has no positive counterpart).

## Required Constants

```cairo
pub const ZERO: SQ128x128     // raw.mag = 0, raw.neg = false
pub const ONE: SQ128x128      // raw.mag = 2^128, raw.neg = false
pub const NEG_ONE: SQ128x128  // raw.mag = 2^128, raw.neg = true
pub const MIN: SQ128x128      // raw.mag = 2^255, raw.neg = true (minimum)
pub const MAX: SQ128x128      // raw.mag = 2^255 - 1, raw.neg = false (maximum)
pub const ONE_ULP: SQ128x128  // raw.mag = 1, raw.neg = false (smallest positive)
```

## Required Operations

### Construction & Conversion

- `from_raw_unchecked(raw: I256) -> SQ128x128` - wrap with normalization, no range check
- `from_raw_checked(raw: I256) -> Option<SQ128x128>` - validate range, return None if invalid
- `to_raw(value: SQ128x128) -> I256` - extract raw value
- `from_int(n: i128) -> SQ128x128` - convert integer (raw.mag = |n| * 2^128), overflow-checked

**API Safety**: Name unchecked functions explicitly (`_unchecked` suffix) to prevent misuse.

### Comparison (with Defensive Normalization)

Implement `PartialEq` and `PartialOrd`. In the underlying comparison functions, defensively normalize to handle potential negative zero:

```cairo
fn i256_eq(a: I256, b: I256) -> bool {
    let a_neg = a.neg && !u256_is_zero(a.mag);  // Defensive normalization
    let b_neg = b.neg && !u256_is_zero(b.mag);
    a_neg == b_neg && u256_eq(a.mag, b.mag)
}
```

### Checked vs Panicking Arithmetic

Implement checked versions first (return `Option<T>`), then panicking wrappers:

```cairo
fn i256_checked_add(a: I256, b: I256) -> Option<I256> { /* core logic */ }
fn i256_add_internal(a: I256, b: I256) -> I256 {
    i256_checked_add(a, b).expect('i256 add overflow')
}
```

Public API:
- `add(a, b)`, `sub(a, b)` - panic on overflow
- `checked_add(a, b)`, `checked_sub(a, b)` - return Option
- `delta(a, b)` - returns `b - a`

### Negation (Handle MIN Overflow)

Negating MIN produces a value outside the representable range:

```cairo
pub fn checked_neg(a: SQ128x128) -> Option<SQ128x128> {
    if a.raw.neg && u256_eq(a.raw.mag, U256_MAX_NEG_MAG) {
        return Option::None;  // Cannot negate MIN
    }
    Option::Some(SQ128x128 { raw: i256_new(a.raw.mag, !a.raw.neg) })
}
```

### Multiplication (512-bit Precision)

Multiplication requires 512-bit intermediate precision:

```
exact_product_mag = (a.raw.mag * b.raw.mag) / 2^128
result_neg = a.raw.neg != b.raw.neg
```

Steps:
1. Compute full 512-bit unsigned product of magnitudes
2. Check for overflow in upper bits (limbs 6-7 must be zero after shift)
3. Shift right by 128 bits (extract limbs 2-5 as result magnitude)
4. Apply rounding based on remainder (lower 128 bits)
5. Validate result magnitude is in range

Implement two rounding modes:
- `mul_down(a, b)` - round toward -infinity (floor)
- `mul_up(a, b)` - round toward +infinity (ceiling)

**Floor rounding rules**:
- Positive result: truncate
- Negative result with remainder: add 1 to magnitude (more negative)

**Ceiling rounding rules**:
- Positive result with remainder: add 1 to magnitude
- Negative result: truncate

## Standard Trait Implementations

Implement these traits for `SQ128x128`:
- `PartialEq` - note: parameters are `@Self` (snapshots)
- `PartialOrd` - implement `lt`, `le`, `gt`, `ge`
- `Add`, `Sub`, `Mul` - panic on overflow
- `Neg` - panic if negating MIN
- `Zero`, `One` - from `core::num::traits`
- `Default` - return ZERO
- `Hash` - must normalize before hashing for consistency with Eq
- `Into<i128, SQ128x128>`, `Into<u128, SQ128x128>` - conversions

Document the `Mul` trait's rounding behavior (uses floor by default).

## Cairo-Specific Implementation Notes

- **No bit shifts**: Use `value / TWO_POW_64` instead of `value >> 64`
- **Limb helpers**: Create `u512_get_limb`/`u512_set_limb` functions instead of copy-pasting
- **Loop-based operations**: Prefer loops over unrolled branches to reduce code size
- **Array indexing**: Use `.span().at(i)` for runtime index access

## Required Tests

### Core Functionality
- Constants have correct raw values
- `from_int` works for positive, negative, zero
- `from_raw_checked` rejects out-of-range values

### Arithmetic Edge Cases
- `MAX + ONE_ULP` overflows
- `MIN - ONE_ULP` overflows
- `MAX + (-MAX) == ZERO`
- `MIN + MIN` overflows

### Negation
- `checked_neg(MIN)` returns None
- `checked_neg(MAX)` succeeds
- `-(-x) == x` for valid values

### Multiplication Identities
- `ONE * x == x` for x in {MIN, NEG_ONE, ZERO, ONE, MAX}
- `NEG_ONE * x == -x` for valid values
- `ZERO * x == ZERO`
- Test rounding with values that produce non-zero remainders

### Invariant Tests
- Negative zero normalizes to positive zero
- Hash is consistent with Eq for negative zero

### Comparison
- Ordering: MIN < NEG_ONE < ZERO < ONE < MAX

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use generics/traits where appropriate
- No external dependencies beyond core Cairo

## Deliverable

- Only the code for `src/lib.cairo`
