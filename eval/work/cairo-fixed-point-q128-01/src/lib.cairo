//! # SQ128x128 Fixed-Point Arithmetic Library
//!
//! This module provides a signed Q128.128 fixed-point number type for precise
//! decimal arithmetic on Starknet. The representation uses sign-magnitude format
//! with 128 integer bits and 128 fractional bits.
//!
//! ## Features
//! - Full signed arithmetic: add, sub, mul with configurable rounding
//! - Overflow-checked variants for safe arithmetic
//! - Standard trait implementations: PartialEq, PartialOrd, Add, Sub, Mul, Neg
//! - Serialization support via Serde
//!
//! ## Example
//! ```cairo
//! use cairo_fixed_point_q128_01::{SQ128x128, ONE, ZERO, from_int, add, mul_down};
//!
//! let a = from_int(5_i128);
//! let b = from_int(3_i128);
//! let sum = a + b;  // 8.0
//! let product = a * b;  // 15.0
//! ```

use core::hash::{Hash, HashStateTrait};

const TWO_POW_64: u128 = 0x1_0000_0000_0000_0000_u128;

/// A 256-bit unsigned integer represented as four 64-bit limbs in little-endian order.
/// Used internally to represent the magnitude of signed values.
#[derive(Copy, Drop, Serde, Debug)]
pub struct U256 {
    pub limb0: u64,
    pub limb1: u64,
    pub limb2: u64,
    pub limb3: u64,
}

/// A 256-bit signed integer using sign-magnitude representation.
/// The magnitude is stored in `mag` and the sign in `neg` (true = negative).
/// Invariant: When mag is zero, neg must be false (no negative zero).
#[derive(Copy, Drop, Serde, Debug)]
pub struct I256 {
    pub mag: U256,
    pub neg: bool,
}

/// Type alias for I256 providing a more conventional name.
pub type i256 = I256;

/// A signed Q128.128 fixed-point number.
///
/// This type represents decimal values with 128 bits of integer precision
/// and 128 bits of fractional precision, using sign-magnitude representation.
///
/// The raw value is scaled by 2^128, so:
/// - `ONE` has raw magnitude of 2^128
/// - `ONE_ULP` (unit in last place) has raw magnitude of 1
///
/// ## Range
/// - Minimum: approximately -1.7e38
/// - Maximum: approximately 1.7e38
/// - Precision: approximately 2.9e-39
#[derive(Copy, Drop, Serde, Debug)]
pub struct SQ128x128 {
    pub raw: i256,
}

const U256_ZERO: U256 = U256 { limb0: 0_u64, limb1: 0_u64, limb2: 0_u64, limb3: 0_u64 };
const U256_ONE: U256 = U256 { limb0: 1_u64, limb1: 0_u64, limb2: 0_u64, limb3: 0_u64 };
const U256_SCALE: U256 = U256 { limb0: 0_u64, limb1: 0_u64, limb2: 1_u64, limb3: 0_u64 };
const U256_MAX_POS_MAG: U256 = U256 {
    limb0: 0xffff_ffff_ffff_ffff_u64,
    limb1: 0xffff_ffff_ffff_ffff_u64,
    limb2: 0xffff_ffff_ffff_ffff_u64,
    limb3: 0x7fff_ffff_ffff_ffff_u64,
};
const U256_MAX_NEG_MAG: U256 = U256 {
    limb0: 0_u64, limb1: 0_u64, limb2: 0_u64, limb3: 0x8000_0000_0000_0000_u64,
};

const I256_ZERO: I256 = I256 { mag: U256_ZERO, neg: false };
const I256_RAW_ONE: I256 = I256 { mag: U256_ONE, neg: false };
const I256_RAW_NEG_ONE: I256 = I256 { mag: U256_ONE, neg: true };
const I256_SCALE: I256 = I256 { mag: U256_SCALE, neg: false };
const I256_NEG_SCALE: I256 = I256 { mag: U256_SCALE, neg: true };
const I256_MIN: I256 = I256 { mag: U256_MAX_NEG_MAG, neg: true };
const I256_MAX: I256 = I256 { mag: U256_MAX_POS_MAG, neg: false };

/// The zero value (0.0)
pub const ZERO: SQ128x128 = SQ128x128 { raw: I256_ZERO };

/// The value one (1.0)
pub const ONE: SQ128x128 = SQ128x128 { raw: I256_SCALE };

/// The value negative one (-1.0)
pub const NEG_ONE: SQ128x128 = SQ128x128 { raw: I256_NEG_SCALE };

/// The minimum representable value (approximately -1.7e38)
pub const MIN: SQ128x128 = SQ128x128 { raw: I256_MIN };

/// The maximum representable value (approximately 1.7e38)
pub const MAX: SQ128x128 = SQ128x128 { raw: I256_MAX };

/// One unit in the last place (ULP) - the smallest positive value (2^-128)
pub const ONE_ULP: SQ128x128 = SQ128x128 { raw: I256_RAW_ONE };

#[derive(Copy, Drop)]
struct U512 {
    limb0: u64,
    limb1: u64,
    limb2: u64,
    limb3: u64,
    limb4: u64,
    limb5: u64,
    limb6: u64,
    limb7: u64,
}

fn u256_zero() -> U256 {
    U256_ZERO
}

fn u256_is_zero(value: U256) -> bool {
    value.limb0 == 0_u64 && value.limb1 == 0_u64 && value.limb2 == 0_u64 && value.limb3 == 0_u64
}

fn u256_cmp(a: U256, b: U256) -> i32 {
    if a.limb3 < b.limb3 {
        return -1_i32;
    }
    if a.limb3 > b.limb3 {
        return 1_i32;
    }
    if a.limb2 < b.limb2 {
        return -1_i32;
    }
    if a.limb2 > b.limb2 {
        return 1_i32;
    }
    if a.limb1 < b.limb1 {
        return -1_i32;
    }
    if a.limb1 > b.limb1 {
        return 1_i32;
    }
    if a.limb0 < b.limb0 {
        return -1_i32;
    }
    if a.limb0 > b.limb0 {
        return 1_i32;
    }
    0_i32
}

fn u256_eq(a: U256, b: U256) -> bool {
    a.limb0 == b.limb0 && a.limb1 == b.limb1 && a.limb2 == b.limb2 && a.limb3 == b.limb3
}

fn u128_from_u64(value: u64) -> u128 {
    value.into()
}

fn u64_from_u128(value: u128) -> u64 {
    value.try_into().unwrap()
}

fn add_u64_with_carry(a: u64, b: u64, carry: u64) -> (u64, u64) {
    let sum: u128 = u128_from_u64(a) + u128_from_u64(b) + u128_from_u64(carry);
    let low: u128 = sum & 0xFFFFFFFFFFFFFFFF_u128;
    let high: u128 = sum / 0x1_0000_0000_0000_0000_u128;
    (u64_from_u128(low), u64_from_u128(high))
}

fn sub_u64_with_borrow(a: u64, b: u64, borrow: u64) -> (u64, u64) {
    let a128: u128 = u128_from_u64(a);
    let b128: u128 = u128_from_u64(b) + u128_from_u64(borrow);
    if a128 >= b128 {
        let diff: u128 = a128 - b128;
        return (u64_from_u128(diff), 0_u64);
    }
    let diff: u128 = (TWO_POW_64 + a128) - b128;
    (u64_from_u128(diff), 1_u64)
}

fn u256_add(a: U256, b: U256) -> (U256, bool) {
    let (l0, c0) = add_u64_with_carry(a.limb0, b.limb0, 0_u64);
    let (l1, c1) = add_u64_with_carry(a.limb1, b.limb1, c0);
    let (l2, c2) = add_u64_with_carry(a.limb2, b.limb2, c1);
    let (l3, c3) = add_u64_with_carry(a.limb3, b.limb3, c2);
    (U256 { limb0: l0, limb1: l1, limb2: l2, limb3: l3 }, c3 != 0_u64)
}

fn u256_add_u64(a: U256, value: u64) -> (U256, bool) {
    let (l0, c0) = add_u64_with_carry(a.limb0, value, 0_u64);
    let (l1, c1) = add_u64_with_carry(a.limb1, 0_u64, c0);
    let (l2, c2) = add_u64_with_carry(a.limb2, 0_u64, c1);
    let (l3, c3) = add_u64_with_carry(a.limb3, 0_u64, c2);
    (U256 { limb0: l0, limb1: l1, limb2: l2, limb3: l3 }, c3 != 0_u64)
}

fn u256_sub(a: U256, b: U256) -> (U256, bool) {
    let (l0, b0) = sub_u64_with_borrow(a.limb0, b.limb0, 0_u64);
    let (l1, b1) = sub_u64_with_borrow(a.limb1, b.limb1, b0);
    let (l2, b2) = sub_u64_with_borrow(a.limb2, b.limb2, b1);
    let (l3, b3) = sub_u64_with_borrow(a.limb3, b.limb3, b2);
    (U256 { limb0: l0, limb1: l1, limb2: l2, limb3: l3 }, b3 != 0_u64)
}

fn u128_split_to_u64(value: u128) -> (u64, u64) {
    let low: u128 = value & 0xFFFFFFFFFFFFFFFF_u128;
    let high: u128 = value / 0x1_0000_0000_0000_0000_u128;
    (u64_from_u128(low), u64_from_u128(high))
}

fn u512_zero() -> U512 {
    U512 {
        limb0: 0_u64,
        limb1: 0_u64,
        limb2: 0_u64,
        limb3: 0_u64,
        limb4: 0_u64,
        limb5: 0_u64,
        limb6: 0_u64,
        limb7: 0_u64,
    }
}

fn u512_add_one_from(mut acc: U512, start: u8) -> U512 {
    if start == 0_u8 {
        let (l0, c0) = add_u64_with_carry(acc.limb0, 0_u64, 1_u64);
        acc.limb0 = l0;
        if c0 == 0_u64 {
            return acc;
        }
        let (l1, c1) = add_u64_with_carry(acc.limb1, 0_u64, 1_u64);
        acc.limb1 = l1;
        if c1 == 0_u64 {
            return acc;
        }
        let (l2, c2) = add_u64_with_carry(acc.limb2, 0_u64, 1_u64);
        acc.limb2 = l2;
        if c2 == 0_u64 {
            return acc;
        }
        let (l3, c3) = add_u64_with_carry(acc.limb3, 0_u64, 1_u64);
        acc.limb3 = l3;
        if c3 == 0_u64 {
            return acc;
        }
        let (l4, c4) = add_u64_with_carry(acc.limb4, 0_u64, 1_u64);
        acc.limb4 = l4;
        if c4 == 0_u64 {
            return acc;
        }
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 1_u8 {
        let (l1, c1) = add_u64_with_carry(acc.limb1, 0_u64, 1_u64);
        acc.limb1 = l1;
        if c1 == 0_u64 {
            return acc;
        }
        let (l2, c2) = add_u64_with_carry(acc.limb2, 0_u64, 1_u64);
        acc.limb2 = l2;
        if c2 == 0_u64 {
            return acc;
        }
        let (l3, c3) = add_u64_with_carry(acc.limb3, 0_u64, 1_u64);
        acc.limb3 = l3;
        if c3 == 0_u64 {
            return acc;
        }
        let (l4, c4) = add_u64_with_carry(acc.limb4, 0_u64, 1_u64);
        acc.limb4 = l4;
        if c4 == 0_u64 {
            return acc;
        }
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 2_u8 {
        let (l2, c2) = add_u64_with_carry(acc.limb2, 0_u64, 1_u64);
        acc.limb2 = l2;
        if c2 == 0_u64 {
            return acc;
        }
        let (l3, c3) = add_u64_with_carry(acc.limb3, 0_u64, 1_u64);
        acc.limb3 = l3;
        if c3 == 0_u64 {
            return acc;
        }
        let (l4, c4) = add_u64_with_carry(acc.limb4, 0_u64, 1_u64);
        acc.limb4 = l4;
        if c4 == 0_u64 {
            return acc;
        }
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 3_u8 {
        let (l3, c3) = add_u64_with_carry(acc.limb3, 0_u64, 1_u64);
        acc.limb3 = l3;
        if c3 == 0_u64 {
            return acc;
        }
        let (l4, c4) = add_u64_with_carry(acc.limb4, 0_u64, 1_u64);
        acc.limb4 = l4;
        if c4 == 0_u64 {
            return acc;
        }
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 4_u8 {
        let (l4, c4) = add_u64_with_carry(acc.limb4, 0_u64, 1_u64);
        acc.limb4 = l4;
        if c4 == 0_u64 {
            return acc;
        }
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 5_u8 {
        let (l5, c5) = add_u64_with_carry(acc.limb5, 0_u64, 1_u64);
        acc.limb5 = l5;
        if c5 == 0_u64 {
            return acc;
        }
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 6_u8 {
        let (l6, c6) = add_u64_with_carry(acc.limb6, 0_u64, 1_u64);
        acc.limb6 = l6;
        if c6 == 0_u64 {
            return acc;
        }
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    if start == 7_u8 {
        let (l7, c7) = add_u64_with_carry(acc.limb7, 0_u64, 1_u64);
        acc.limb7 = l7;
        assert!(c7 == 0_u64, "u512 overflow");
        return acc;
    }
    assert!(false, "u512 overflow");
    acc
}

fn u512_add_product(acc: U512, a: u64, b: u64, idx: u8) -> U512 {
    let prod: u128 = u128_from_u64(a) * u128_from_u64(b);
    let (low, high) = u128_split_to_u64(prod);
    let mut acc = acc;
    if idx == 0_u8 {
        let (l0, c0) = add_u64_with_carry(acc.limb0, low, 0_u64);
        acc.limb0 = l0;
        let (l1, c1) = add_u64_with_carry(acc.limb1, high, c0);
        acc.limb1 = l1;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 2_u8);
        }
        return acc;
    }
    if idx == 1_u8 {
        let (l1, c0) = add_u64_with_carry(acc.limb1, low, 0_u64);
        acc.limb1 = l1;
        let (l2, c1) = add_u64_with_carry(acc.limb2, high, c0);
        acc.limb2 = l2;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 3_u8);
        }
        return acc;
    }
    if idx == 2_u8 {
        let (l2, c0) = add_u64_with_carry(acc.limb2, low, 0_u64);
        acc.limb2 = l2;
        let (l3, c1) = add_u64_with_carry(acc.limb3, high, c0);
        acc.limb3 = l3;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 4_u8);
        }
        return acc;
    }
    if idx == 3_u8 {
        let (l3, c0) = add_u64_with_carry(acc.limb3, low, 0_u64);
        acc.limb3 = l3;
        let (l4, c1) = add_u64_with_carry(acc.limb4, high, c0);
        acc.limb4 = l4;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 5_u8);
        }
        return acc;
    }
    if idx == 4_u8 {
        let (l4, c0) = add_u64_with_carry(acc.limb4, low, 0_u64);
        acc.limb4 = l4;
        let (l5, c1) = add_u64_with_carry(acc.limb5, high, c0);
        acc.limb5 = l5;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 6_u8);
        }
        return acc;
    }
    if idx == 5_u8 {
        let (l5, c0) = add_u64_with_carry(acc.limb5, low, 0_u64);
        acc.limb5 = l5;
        let (l6, c1) = add_u64_with_carry(acc.limb6, high, c0);
        acc.limb6 = l6;
        if c1 == 1_u64 {
            acc = u512_add_one_from(acc, 7_u8);
        }
        return acc;
    }
    if idx == 6_u8 {
        let (l6, c0) = add_u64_with_carry(acc.limb6, low, 0_u64);
        acc.limb6 = l6;
        let (l7, c1) = add_u64_with_carry(acc.limb7, high, c0);
        acc.limb7 = l7;
        assert!(c1 == 0_u64, "u512 overflow");
        return acc;
    }
    assert!(false, "u512 overflow");
    acc
}

fn u256_mul(a: U256, b: U256) -> U512 {
    let mut acc = u512_zero();
    acc = u512_add_product(acc, a.limb0, b.limb0, 0_u8);
    acc = u512_add_product(acc, a.limb0, b.limb1, 1_u8);
    acc = u512_add_product(acc, a.limb0, b.limb2, 2_u8);
    acc = u512_add_product(acc, a.limb0, b.limb3, 3_u8);

    acc = u512_add_product(acc, a.limb1, b.limb0, 1_u8);
    acc = u512_add_product(acc, a.limb1, b.limb1, 2_u8);
    acc = u512_add_product(acc, a.limb1, b.limb2, 3_u8);
    acc = u512_add_product(acc, a.limb1, b.limb3, 4_u8);

    acc = u512_add_product(acc, a.limb2, b.limb0, 2_u8);
    acc = u512_add_product(acc, a.limb2, b.limb1, 3_u8);
    acc = u512_add_product(acc, a.limb2, b.limb2, 4_u8);
    acc = u512_add_product(acc, a.limb2, b.limb3, 5_u8);

    acc = u512_add_product(acc, a.limb3, b.limb0, 3_u8);
    acc = u512_add_product(acc, a.limb3, b.limb1, 4_u8);
    acc = u512_add_product(acc, a.limb3, b.limb2, 5_u8);
    acc = u512_add_product(acc, a.limb3, b.limb3, 6_u8);
    acc
}

fn u512_high_overflow(value: U512) -> bool {
    value.limb6 != 0_u64 || value.limb7 != 0_u64
}

fn u512_remainder_nonzero(value: U512) -> bool {
    value.limb0 != 0_u64 || value.limb1 != 0_u64
}

fn u512_shr_128(value: U512) -> U256 {
    U256 { limb0: value.limb2, limb1: value.limb3, limb2: value.limb4, limb3: value.limb5 }
}

/// Internal constructor that enforces the invariant: neg flag is cleared when magnitude is zero.
/// This follows Ekubo's i129_new pattern: `i129_new(mag, sign) -> i129 { mag, sign: sign & (mag != 0) }`
fn i256_new(mag: U256, neg: bool) -> I256 {
    I256 { mag, neg: neg && !u256_is_zero(mag) }
}

fn i256_normalize(value: I256) -> I256 {
    i256_new(value.mag, value.neg)
}

fn i256_is_zero(value: I256) -> bool {
    u256_is_zero(value.mag)
}

fn i256_eq(a: I256, b: I256) -> bool {
    a.neg == b.neg && u256_eq(a.mag, b.mag)
}

fn i256_cmp(a: I256, b: I256) -> i32 {
    if a.neg != b.neg {
        if a.neg {
            return -1_i32;
        }
        return 1_i32;
    }
    if !a.neg {
        return u256_cmp(a.mag, b.mag);
    }
    0_i32 - u256_cmp(a.mag, b.mag)
}

fn i128_abs_to_u128(value: i128) -> (u128, bool) {
    if value >= 0_i128 {
        let magnitude: u128 = value.try_into().unwrap();
        return (magnitude, false);
    }
    let plus_one: i128 = value + 1_i128;
    let mag_minus_one: u128 = (-plus_one).try_into().unwrap();
    (mag_minus_one + 1_u128, true)
}

fn u256_from_u128_shifted_128(value: u128) -> U256 {
    let (low, high) = u128_split_to_u64(value);
    U256 { limb0: 0_u64, limb1: 0_u64, limb2: low, limb3: high }
}

fn i256_add_internal(a: I256, b: I256) -> I256 {
    if a.neg == b.neg {
        let (sum, overflow) = u256_add(a.mag, b.mag);
        assert!(!overflow, "i256 add overflow");
        if a.neg {
            assert!(u256_cmp(sum, U256_MAX_NEG_MAG) <= 0_i32, "i256 add overflow");
        } else {
            assert!(u256_cmp(sum, U256_MAX_POS_MAG) <= 0_i32, "i256 add overflow");
        }
        return i256_new(sum, a.neg);
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return I256_ZERO;
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        assert!(!underflow, "i256 add underflow");
        return i256_new(diff, a.neg);
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    assert!(!underflow, "i256 add underflow");
    i256_new(diff, b.neg)
}

fn i256_sub_internal(a: I256, b: I256) -> I256 {
    if b.neg {
        if a.neg {
            let cmp = u256_cmp(a.mag, b.mag);
            if cmp == 0_i32 {
                return I256_ZERO;
            }
            if cmp > 0_i32 {
                let (diff, underflow) = u256_sub(a.mag, b.mag);
                assert!(!underflow, "i256 sub underflow");
                return i256_new(diff, true);
            }
            let (diff, underflow) = u256_sub(b.mag, a.mag);
            assert!(!underflow, "i256 sub underflow");
            return i256_new(diff, false);
        }

        let (sum, overflow) = u256_add(a.mag, b.mag);
        assert!(!overflow, "i256 sub overflow");
        assert!(u256_cmp(sum, U256_MAX_POS_MAG) <= 0_i32, "i256 sub overflow");
        return i256_new(sum, false);
    }

    if a.neg {
        let (sum, overflow) = u256_add(a.mag, b.mag);
        assert!(!overflow, "i256 sub overflow");
        assert!(u256_cmp(sum, U256_MAX_NEG_MAG) <= 0_i32, "i256 sub overflow");
        return i256_new(sum, true);
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return I256_ZERO;
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        assert!(!underflow, "i256 sub underflow");
        return i256_new(diff, false);
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    assert!(!underflow, "i256 sub underflow");
    i256_new(diff, true)
}

/// Creates an SQ128x128 from a raw I256 value.
/// The raw value is normalized to ensure no negative zero.
pub fn from_raw(raw: i256) -> SQ128x128 {
    SQ128x128 { raw: i256_normalize(raw) }
}

/// Extracts the raw I256 value from an SQ128x128.
pub fn to_raw(value: SQ128x128) -> i256 {
    value.raw
}

/// Creates an SQ128x128 from an i128 integer.
///
/// # Panics
/// Panics if the value is outside the representable range.
pub fn from_int(value: i128) -> SQ128x128 {
    let (mag128, neg) = i128_abs_to_u128(value);
    let mag = u256_from_u128_shifted_128(mag128);
    let raw = i256_new(mag, neg);
    if neg {
        assert!(u256_cmp(raw.mag, U256_MAX_NEG_MAG) <= 0_i32, "from_int overflow");
    } else {
        assert!(u256_cmp(raw.mag, U256_MAX_POS_MAG) <= 0_i32, "from_int overflow");
    }
    SQ128x128 { raw }
}

fn add_internal(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    SQ128x128 { raw: i256_add_internal(a.raw, b.raw) }
}

fn sub_internal(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    SQ128x128 { raw: i256_sub_internal(a.raw, b.raw) }
}

/// Adds two SQ128x128 values.
///
/// # Panics
/// Panics on overflow.
pub fn add(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    add_internal(a, b)
}

/// Subtracts b from a.
///
/// # Panics
/// Panics on overflow.
pub fn sub(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    sub_internal(a, b)
}

/// Computes b - a (the delta from a to b).
///
/// # Panics
/// Panics on overflow.
pub fn delta(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    sub_internal(b, a)
}

fn mul_internal(a: SQ128x128, b: SQ128x128, round_up: bool) -> SQ128x128 {
    if i256_is_zero(a.raw) || i256_is_zero(b.raw) {
        return ZERO;
    }
    let neg = a.raw.neg != b.raw.neg;
    let product = u256_mul(a.raw.mag, b.raw.mag);
    assert!(!u512_high_overflow(product), "mul overflow");
    let mut mag = u512_shr_128(product);
    let rem_nonzero = u512_remainder_nonzero(product);

    if neg {
        if !round_up && rem_nonzero {
            let (inc, overflow) = u256_add_u64(mag, 1_u64);
            assert!(!overflow, "mul overflow");
            mag = inc;
        }
        assert!(u256_cmp(mag, U256_MAX_NEG_MAG) <= 0_i32, "mul overflow");
        return SQ128x128 { raw: i256_new(mag, true) };
    }

    if round_up && rem_nonzero {
        let (inc, overflow) = u256_add_u64(mag, 1_u64);
        assert!(!overflow, "mul overflow");
        mag = inc;
    }
    assert!(u256_cmp(mag, U256_MAX_POS_MAG) <= 0_i32, "mul overflow");
    SQ128x128 { raw: i256_new(mag, false) }
}

/// Multiplies two values, rounding toward negative infinity (floor).
///
/// For positive results, this truncates. For negative results with a remainder,
/// this rounds away from zero (more negative).
///
/// # Panics
/// Panics on overflow.
pub fn mul_down(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    mul_internal(a, b, false)
}

/// Multiplies two values, rounding toward positive infinity (ceiling).
///
/// For positive results with a remainder, this rounds up.
/// For negative results, this truncates (toward zero).
///
/// # Panics
/// Panics on overflow.
pub fn mul_up(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    mul_internal(a, b, true)
}

/// Checked i256 addition. Returns None on overflow instead of panicking.
fn i256_checked_add(a: I256, b: I256) -> Option<I256> {
    if a.neg == b.neg {
        let (sum, overflow) = u256_add(a.mag, b.mag);
        if overflow {
            return Option::None;
        }
        if a.neg {
            if u256_cmp(sum, U256_MAX_NEG_MAG) > 0_i32 {
                return Option::None;
            }
        } else {
            if u256_cmp(sum, U256_MAX_POS_MAG) > 0_i32 {
                return Option::None;
            }
        }
        return Option::Some(i256_new(sum, a.neg));
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return Option::Some(I256_ZERO);
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        if underflow {
            return Option::None;
        }
        return Option::Some(i256_new(diff, a.neg));
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    if underflow {
        return Option::None;
    }
    Option::Some(i256_new(diff, b.neg))
}

/// Checked i256 subtraction. Returns None on overflow instead of panicking.
fn i256_checked_sub(a: I256, b: I256) -> Option<I256> {
    if b.neg {
        if a.neg {
            let cmp = u256_cmp(a.mag, b.mag);
            if cmp == 0_i32 {
                return Option::Some(I256_ZERO);
            }
            if cmp > 0_i32 {
                let (diff, underflow) = u256_sub(a.mag, b.mag);
                if underflow {
                    return Option::None;
                }
                return Option::Some(i256_new(diff, true));
            }
            let (diff, underflow) = u256_sub(b.mag, a.mag);
            if underflow {
                return Option::None;
            }
            return Option::Some(i256_new(diff, false));
        }

        let (sum, overflow) = u256_add(a.mag, b.mag);
        if overflow {
            return Option::None;
        }
        if u256_cmp(sum, U256_MAX_POS_MAG) > 0_i32 {
            return Option::None;
        }
        return Option::Some(i256_new(sum, false));
    }

    if a.neg {
        let (sum, overflow) = u256_add(a.mag, b.mag);
        if overflow {
            return Option::None;
        }
        if u256_cmp(sum, U256_MAX_NEG_MAG) > 0_i32 {
            return Option::None;
        }
        return Option::Some(i256_new(sum, true));
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return Option::Some(I256_ZERO);
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        if underflow {
            return Option::None;
        }
        return Option::Some(i256_new(diff, false));
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    if underflow {
        return Option::None;
    }
    Option::Some(i256_new(diff, true))
}

/// Checked multiplication internal. Returns None on overflow instead of panicking.
fn checked_mul_internal(a: SQ128x128, b: SQ128x128, round_up: bool) -> Option<SQ128x128> {
    if i256_is_zero(a.raw) || i256_is_zero(b.raw) {
        return Option::Some(ZERO);
    }
    let neg = a.raw.neg != b.raw.neg;
    let product = u256_mul(a.raw.mag, b.raw.mag);
    if u512_high_overflow(product) {
        return Option::None;
    }
    let mut mag = u512_shr_128(product);
    let rem_nonzero = u512_remainder_nonzero(product);

    if neg {
        if !round_up && rem_nonzero {
            let (inc, overflow) = u256_add_u64(mag, 1_u64);
            if overflow {
                return Option::None;
            }
            mag = inc;
        }
        if u256_cmp(mag, U256_MAX_NEG_MAG) > 0_i32 {
            return Option::None;
        }
        return Option::Some(SQ128x128 { raw: i256_new(mag, true) });
    }

    if round_up && rem_nonzero {
        let (inc, overflow) = u256_add_u64(mag, 1_u64);
        if overflow {
            return Option::None;
        }
        mag = inc;
    }
    if u256_cmp(mag, U256_MAX_POS_MAG) > 0_i32 {
        return Option::None;
    }
    Option::Some(SQ128x128 { raw: i256_new(mag, false) })
}

/// Checked addition. Returns None on overflow instead of panicking.
pub fn checked_add(a: SQ128x128, b: SQ128x128) -> Option<SQ128x128> {
    match i256_checked_add(a.raw, b.raw) {
        Option::Some(raw) => Option::Some(SQ128x128 { raw }),
        Option::None => Option::None,
    }
}

/// Checked subtraction. Returns None on overflow instead of panicking.
pub fn checked_sub(a: SQ128x128, b: SQ128x128) -> Option<SQ128x128> {
    match i256_checked_sub(a.raw, b.raw) {
        Option::Some(raw) => Option::Some(SQ128x128 { raw }),
        Option::None => Option::None,
    }
}

/// Checked multiplication (rounds down). Returns None on overflow.
pub fn checked_mul_down(a: SQ128x128, b: SQ128x128) -> Option<SQ128x128> {
    checked_mul_internal(a, b, false)
}

/// Checked multiplication (rounds up). Returns None on overflow.
pub fn checked_mul_up(a: SQ128x128, b: SQ128x128) -> Option<SQ128x128> {
    checked_mul_internal(a, b, true)
}

pub impl SQ128x128PartialEq of PartialEq<SQ128x128> {
    fn eq(lhs: @SQ128x128, rhs: @SQ128x128) -> bool {
        i256_eq(*lhs.raw, *rhs.raw)
    }
}

pub impl SQ128x128PartialOrd of PartialOrd<SQ128x128> {
    fn lt(lhs: SQ128x128, rhs: SQ128x128) -> bool {
        i256_cmp(lhs.raw, rhs.raw) < 0_i32
    }

    fn le(lhs: SQ128x128, rhs: SQ128x128) -> bool {
        i256_cmp(lhs.raw, rhs.raw) <= 0_i32
    }

    fn gt(lhs: SQ128x128, rhs: SQ128x128) -> bool {
        i256_cmp(lhs.raw, rhs.raw) > 0_i32
    }

    fn ge(lhs: SQ128x128, rhs: SQ128x128) -> bool {
        i256_cmp(lhs.raw, rhs.raw) >= 0_i32
    }
}

pub impl SQ128x128Add of Add<SQ128x128> {
    fn add(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        add_internal(lhs, rhs)
    }
}

pub impl SQ128x128Sub of Sub<SQ128x128> {
    fn sub(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        sub_internal(lhs, rhs)
    }
}

pub impl SQ128x128Mul of Mul<SQ128x128> {
    fn mul(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        mul_internal(lhs, rhs, false)
    }
}

pub impl SQ128x128Neg of Neg<SQ128x128> {
    fn neg(a: SQ128x128) -> SQ128x128 {
        // Flip the sign, normalize to handle zero case
        SQ128x128 { raw: i256_new(a.raw.mag, !a.raw.neg) }
    }
}

pub impl SQ128x128Zero of core::num::traits::Zero<SQ128x128> {
    fn zero() -> SQ128x128 {
        ZERO
    }

    fn is_zero(self: @SQ128x128) -> bool {
        u256_is_zero(*self.raw.mag)
    }

    fn is_non_zero(self: @SQ128x128) -> bool {
        !u256_is_zero(*self.raw.mag)
    }
}

pub impl SQ128x128One of core::num::traits::One<SQ128x128> {
    fn one() -> SQ128x128 {
        ONE
    }

    fn is_one(self: @SQ128x128) -> bool {
        !(*self.raw.neg) && u256_eq(*self.raw.mag, U256_SCALE)
    }

    fn is_non_one(self: @SQ128x128) -> bool {
        (*self.raw.neg) || !u256_eq(*self.raw.mag, U256_SCALE)
    }
}

pub impl SQ128x128Default of Default<SQ128x128> {
    fn default() -> SQ128x128 {
        ZERO
    }
}

pub impl I128IntoSQ128x128 of Into<i128, SQ128x128> {
    fn into(self: i128) -> SQ128x128 {
        from_int(self)
    }
}

pub impl U128IntoSQ128x128 of Into<u128, SQ128x128> {
    fn into(self: u128) -> SQ128x128 {
        let mag = u256_from_u128_shifted_128(self);
        assert!(u256_cmp(mag, U256_MAX_POS_MAG) <= 0_i32, "from_u128 overflow");
        SQ128x128 { raw: i256_new(mag, false) }
    }
}

impl SQ128x128Display of core::fmt::Display<SQ128x128> {
    fn fmt(self: @SQ128x128, ref f: core::fmt::Formatter) -> Result<(), core::fmt::Error> {
        if (*self.raw.neg) {
            write!(f, "-")?;
        }
        // Write the magnitude - can be simple hex representation
        write!(f, "SQ128x128({:?})", self.raw.mag)
    }
}

impl SQ128x128Hash<S, +HashStateTrait<S>, +Drop<S>> of Hash<SQ128x128, S> {
    fn update_state(state: S, value: SQ128x128) -> S {
        // Hash the magnitude limbs and sign
        let state = state.update(value.raw.mag.limb0.into());
        let state = state.update(value.raw.mag.limb1.into());
        let state = state.update(value.raw.mag.limb2.into());
        let state = state.update(value.raw.mag.limb3.into());
        // For sign, add offset for negative values (like Ekubo)
        if value.raw.neg {
            state.update(1)
        } else {
            state.update(0)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{
        I256, MAX, MIN, NEG_ONE, ONE, ONE_ULP, SQ128x128, ZERO, add, delta, from_int, from_raw,
        mul_down, mul_up, sub, checked_add, checked_sub, checked_mul_down, checked_mul_up,
    };
    use core::num::traits::{Zero, One};
    use core::option::OptionTrait;

    fn raw_from_limbs(l0: u64, l1: u64, l2: u64, l3: u64, neg: bool) -> I256 {
        I256 { mag: super::U256 { limb0: l0, limb1: l1, limb2: l2, limb3: l3 }, neg }
    }

    #[test]
    fn constants_raw_values() {
        let zero = ZERO;
        assert!(super::i256_eq(zero.raw, super::I256_ZERO), "ZERO raw");

        let one = ONE;
        let expected_one = raw_from_limbs(0_u64, 0_u64, 1_u64, 0_u64, false);
        assert!(super::i256_eq(one.raw, expected_one), "ONE raw");

        let neg_one = super::NEG_ONE;
        let expected_neg_one = raw_from_limbs(0_u64, 0_u64, 1_u64, 0_u64, true);
        assert!(super::i256_eq(neg_one.raw, expected_neg_one), "NEG_ONE raw");

        let min = MIN;
        let expected_min = raw_from_limbs(0_u64, 0_u64, 0_u64, 0x8000_0000_0000_0000_u64, true);
        assert!(super::i256_eq(min.raw, expected_min), "MIN raw");

        let max = MAX;
        let expected_max = raw_from_limbs(
            0xffff_ffff_ffff_ffff_u64,
            0xffff_ffff_ffff_ffff_u64,
            0xffff_ffff_ffff_ffff_u64,
            0x7fff_ffff_ffff_ffff_u64,
            false,
        );
        assert!(super::i256_eq(max.raw, expected_max), "MAX raw");
    }

    #[test]
    #[should_panic]
    fn add_overflow_max_plus_one_ulp() {
        let _ = add(MAX, ONE_ULP);
    }

    #[test]
    #[should_panic]
    fn sub_overflow_min_minus_one_ulp() {
        let _ = sub(MIN, ONE_ULP);
    }

    #[test]
    fn add_max_plus_neg_max_is_zero() {
        let neg_max = SQ128x128 { raw: I256 { mag: MAX.raw.mag, neg: true } };
        let sum = add(MAX, neg_max);
        assert!(sum == ZERO, "max + neg_max == zero");
    }

    #[test]
    #[should_panic]
    fn add_min_plus_min_overflows() {
        let _ = add(MIN, MIN);
    }

    #[test]
    fn delta_zero_when_same() {
        let value = from_int(7_i128);
        let d = delta(value, value);
        assert!(d == ZERO, "delta(a,a) == zero");
    }

    #[test]
    fn delta_round_trip() {
        let a = from_int(-3_i128);
        let b = from_int(5_i128);
        let d = delta(a, b);
        let sum = add(a, d);
        assert!(sum == b, "a + delta(a,b) == b");
    }

    #[test]
    fn mul_one_identities() {
        let values: Span<SQ128x128> = [MIN, NEG_ONE, ZERO, ONE, MAX].span();
        let mut i: usize = 0;
        while i < 5 {
            let v = *values[i];
            assert!(mul_down(ONE, v) == v, "one * v mul_down");
            assert!(mul_down(v, ONE) == v, "v * one mul_down");
            assert!(mul_up(ONE, v) == v, "one * v mul_up");
            assert!(mul_up(v, ONE) == v, "v * one mul_up");
            i += 1;
        }
    }

    #[test]
    fn mul_neg_one_identities() {
        assert!(mul_down(NEG_ONE, NEG_ONE) == ONE, "neg_one * neg_one down");
        assert!(mul_up(NEG_ONE, NEG_ONE) == ONE, "neg_one * neg_one up");
        assert!(mul_down(NEG_ONE, ONE) == NEG_ONE, "neg_one * one down");
        assert!(mul_up(NEG_ONE, ONE) == NEG_ONE, "neg_one * one up");
    }

    #[test]
    fn mul_rounding_positive_remainder() {
        let a = from_raw(raw_from_limbs(3_u64, 0_u64, 0_u64, 0_u64, false));
        let b = from_raw(raw_from_limbs(1_u64, 0_u64, 0_u64, 0_u64, false));
        let down = mul_down(a, b);
        let up = mul_up(a, b);
        assert!(down == ZERO, "mul_down truncates");
        assert!(up == ONE_ULP, "mul_up rounds");
        let diff = sub(up, down);
        assert!(diff == ZERO || diff == ONE_ULP, "diff is 0 or 1");
    }

    #[test]
    fn mul_rounding_negative_remainder() {
        let a = from_raw(raw_from_limbs(3_u64, 0_u64, 0_u64, 0_u64, true));
        let b = from_raw(raw_from_limbs(1_u64, 0_u64, 0_u64, 0_u64, false));
        let down = mul_down(a, b);
        let up = mul_up(a, b);
        let expected_down = from_raw(raw_from_limbs(1_u64, 0_u64, 0_u64, 0_u64, true));
        assert!(down == expected_down, "mul_down floors negative");
        assert!(up == ZERO, "mul_up ceilings negative");
        let diff = sub(up, down);
        assert!(diff == ONE_ULP, "diff is 1");
    }

    // 1. Multiplication overflow tests
    #[test]
    #[should_panic]
    fn mul_max_max_overflows() {
        let _ = mul_down(MAX, MAX);
    }

    #[test]
    #[should_panic]
    fn mul_min_min_overflows() {
        let _ = mul_down(MIN, MIN);
    }

    #[test]
    #[should_panic]
    fn mul_min_neg_one_overflows() {
        // MIN * NEG_ONE = +2^127 which is out of range
        let _ = mul_down(MIN, NEG_ONE);
    }

    // 2. Comparison ordering tests
    #[test]
    fn comparison_ordering() {
        assert!(MIN < NEG_ONE, "MIN < NEG_ONE");
        assert!(NEG_ONE < ZERO, "NEG_ONE < ZERO");
        assert!(ZERO < ONE, "ZERO < ONE");
        assert!(ONE < MAX, "ONE < MAX");

        // Transitivity
        assert!(MIN < ZERO, "MIN < ZERO");
        assert!(MIN < MAX, "MIN < MAX");
        assert!(NEG_ONE < ONE, "NEG_ONE < ONE");
    }

    // 3. Normalization tests
    #[test]
    fn negative_zero_normalizes() {
        // Construct a "negative zero" raw value
        let neg_zero_raw = I256 { mag: super::U256_ZERO, neg: true };
        let normalized = from_raw(neg_zero_raw);
        assert!(normalized == ZERO, "negative zero becomes ZERO");
        assert!(!normalized.raw.neg, "sign is cleared for zero");
    }

    // 4. Cross-limb multiplication tests
    #[test]
    fn mul_cross_limb_values() {
        // Values that exercise limb1/limb2 interactions
        let a = from_raw(raw_from_limbs(0_u64, 1_u64, 1_u64, 0_u64, false)); // has limb1 and limb2
        let b = from_raw(raw_from_limbs(0_u64, 0_u64, 1_u64, 0_u64, false)); // ONE
        let result = mul_down(a, b);
        assert!(result == a, "multiplying by ONE preserves value");
    }

    // 5. Rounding bound property test
    #[test]
    fn mul_rounding_bounds() {
        // For any multiplication with remainder, mul_down <= mul_up
        // and the difference is at most ONE_ULP
        let a = from_raw(raw_from_limbs(7_u64, 0_u64, 0_u64, 0_u64, false));
        let b = from_raw(raw_from_limbs(3_u64, 0_u64, 0_u64, 0_u64, false));
        let down = mul_down(a, b);
        let up = mul_up(a, b);
        assert!(down <= up, "mul_down <= mul_up");
        let diff = sub(up, down);
        assert!(diff == ZERO || diff == ONE_ULP, "difference is 0 or 1 ULP");
    }

    // 6. Neg trait tests
    #[test]
    fn neg_trait_works() {
        assert!(-ONE == NEG_ONE, "-ONE == NEG_ONE");
        assert!(-NEG_ONE == ONE, "-NEG_ONE == ONE");
        assert!(-ZERO == ZERO, "-ZERO == ZERO");
        assert!(-(-ONE) == ONE, "double negation");
    }

    // 7. Zero trait tests
    #[test]
    fn zero_trait_works() {
        let z: SQ128x128 = Zero::zero();
        assert!(z == ZERO, "Zero::zero() == ZERO");
        assert!(ZERO.is_zero(), "ZERO.is_zero()");
        assert!(!ONE.is_zero(), "!ONE.is_zero()");
        assert!(ONE.is_non_zero(), "ONE.is_non_zero()");
    }

    // 8. One trait tests
    #[test]
    fn one_trait_works() {
        let o: SQ128x128 = One::one();
        assert!(o == ONE, "One::one() == ONE");
        assert!(ONE.is_one(), "ONE.is_one()");
        assert!(!ZERO.is_one(), "!ZERO.is_one()");
        assert!(ZERO.is_non_one(), "ZERO.is_non_one()");
    }

    // 9. Into trait tests
    #[test]
    fn into_trait_works() {
        let from_i128: SQ128x128 = 5_i128.into();
        let from_fn = from_int(5_i128);
        assert!(from_i128 == from_fn, "i128.into() works");

        let neg_from_i128: SQ128x128 = (-3_i128).into();
        let neg_from_fn = from_int(-3_i128);
        assert!(neg_from_i128 == neg_from_fn, "negative i128.into() works");

        let from_u128: SQ128x128 = 7_u128.into();
        assert!(from_u128 == from_int(7_i128), "u128.into() works");
    }

    // 10. Operator syntax tests
    #[test]
    fn operator_syntax_works() {
        let a = from_int(3_i128);
        let b = from_int(2_i128);

        // Test + operator
        assert!(a + b == from_int(5_i128), "a + b works");

        // Test - operator
        assert!(a - b == from_int(1_i128), "a - b works");

        // Test * operator (mul_down semantics)
        assert!(ONE * a == a, "ONE * a == a");
        assert!(a * ONE == a, "a * ONE == a");
    }

    // 11. Checked arithmetic tests
    #[test]
    fn checked_add_success() {
        let a = from_int(3_i128);
        let b = from_int(2_i128);
        let result = checked_add(a, b);
        assert!(result.is_some(), "checked_add should succeed");
        assert!(OptionTrait::unwrap(result) == from_int(5_i128), "checked_add result");
    }

    #[test]
    fn checked_add_overflow_returns_none() {
        let result = checked_add(MAX, ONE_ULP);
        assert!(result.is_none(), "checked_add overflow returns None");
    }

    #[test]
    fn checked_sub_success() {
        let a = from_int(5_i128);
        let b = from_int(3_i128);
        let result = checked_sub(a, b);
        assert!(result.is_some(), "checked_sub should succeed");
        assert!(OptionTrait::unwrap(result) == from_int(2_i128), "checked_sub result");
    }

    #[test]
    fn checked_sub_overflow_returns_none() {
        let result = checked_sub(MIN, ONE_ULP);
        assert!(result.is_none(), "checked_sub overflow returns None");
    }

    #[test]
    fn checked_mul_success() {
        let a = from_int(3_i128);
        let b = from_int(2_i128);

        let down = checked_mul_down(a, b);
        assert!(down.is_some(), "checked_mul_down should succeed");
        assert!(OptionTrait::unwrap(down) == from_int(6_i128), "checked_mul_down result");

        let up = checked_mul_up(a, b);
        assert!(up.is_some(), "checked_mul_up should succeed");
        assert!(OptionTrait::unwrap(up) == from_int(6_i128), "checked_mul_up result");
    }

    #[test]
    fn checked_mul_overflow_returns_none() {
        let result = checked_mul_down(MAX, MAX);
        assert!(result.is_none(), "checked_mul overflow returns None");
    }
}
