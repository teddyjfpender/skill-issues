const TWO_POW_64: u128 = 0x1_0000_0000_0000_0000_u128;

#[derive(Copy, Drop)]
pub struct U256 {
    limb0: u64,
    limb1: u64,
    limb2: u64,
    limb3: u64,
}

#[derive(Copy, Drop)]
pub struct I256 {
    mag: U256,
    neg: bool,
}

pub type i256 = I256;

#[derive(Copy, Drop)]
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
const I256_ONE: I256 = I256 { mag: U256_ONE, neg: false };
const I256_NEG_ONE: I256 = I256 { mag: U256_ONE, neg: true };
const I256_SCALE: I256 = I256 { mag: U256_SCALE, neg: false };
const I256_NEG_SCALE: I256 = I256 { mag: U256_SCALE, neg: true };
const I256_MIN: I256 = I256 { mag: U256_MAX_NEG_MAG, neg: true };
const I256_MAX: I256 = I256 { mag: U256_MAX_POS_MAG, neg: false };

pub const ZERO: SQ128x128 = SQ128x128 { raw: I256_ZERO };
pub const ONE: SQ128x128 = SQ128x128 { raw: I256_SCALE };
pub const NEG_ONE: SQ128x128 = SQ128x128 { raw: I256_NEG_SCALE };
pub const MIN: SQ128x128 = SQ128x128 { raw: I256_MIN };
pub const MAX: SQ128x128 = SQ128x128 { raw: I256_MAX };
pub const ONE_ULP: SQ128x128 = SQ128x128 { raw: I256_ONE };

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
    let low: u128 = sum % TWO_POW_64;
    let high: u128 = sum / TWO_POW_64;
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
    let low: u128 = value % TWO_POW_64;
    let high: u128 = value / TWO_POW_64;
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

fn i256_normalize(value: I256) -> I256 {
    if u256_is_zero(value.mag) {
        return I256 { mag: value.mag, neg: false };
    }
    value
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
        return i256_normalize(I256 { mag: sum, neg: a.neg });
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return I256_ZERO;
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        assert!(!underflow, "i256 add underflow");
        return i256_normalize(I256 { mag: diff, neg: a.neg });
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    assert!(!underflow, "i256 add underflow");
    i256_normalize(I256 { mag: diff, neg: b.neg })
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
                return i256_normalize(I256 { mag: diff, neg: true });
            }
            let (diff, underflow) = u256_sub(b.mag, a.mag);
            assert!(!underflow, "i256 sub underflow");
            return i256_normalize(I256 { mag: diff, neg: false });
        }

        let (sum, overflow) = u256_add(a.mag, b.mag);
        assert!(!overflow, "i256 sub overflow");
        assert!(u256_cmp(sum, U256_MAX_POS_MAG) <= 0_i32, "i256 sub overflow");
        return i256_normalize(I256 { mag: sum, neg: false });
    }

    if a.neg {
        let (sum, overflow) = u256_add(a.mag, b.mag);
        assert!(!overflow, "i256 sub overflow");
        assert!(u256_cmp(sum, U256_MAX_NEG_MAG) <= 0_i32, "i256 sub overflow");
        return i256_normalize(I256 { mag: sum, neg: true });
    }

    let cmp = u256_cmp(a.mag, b.mag);
    if cmp == 0_i32 {
        return I256_ZERO;
    }
    if cmp > 0_i32 {
        let (diff, underflow) = u256_sub(a.mag, b.mag);
        assert!(!underflow, "i256 sub underflow");
        return i256_normalize(I256 { mag: diff, neg: false });
    }
    let (diff, underflow) = u256_sub(b.mag, a.mag);
    assert!(!underflow, "i256 sub underflow");
    i256_normalize(I256 { mag: diff, neg: true })
}

pub fn from_raw(raw: i256) -> SQ128x128 {
    SQ128x128 { raw: i256_normalize(raw) }
}

pub fn to_raw(value: SQ128x128) -> i256 {
    value.raw
}

pub fn from_int(value: i128) -> SQ128x128 {
    let (mag128, neg) = i128_abs_to_u128(value);
    let mag = u256_from_u128_shifted_128(mag128);
    let raw = i256_normalize(I256 { mag, neg });
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

pub fn add(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    add_internal(a, b)
}

pub fn sub(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    sub_internal(a, b)
}

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
        return SQ128x128 { raw: i256_normalize(I256 { mag, neg: true }) };
    }

    if round_up && rem_nonzero {
        let (inc, overflow) = u256_add_u64(mag, 1_u64);
        assert!(!overflow, "mul overflow");
        mag = inc;
    }
    assert!(u256_cmp(mag, U256_MAX_POS_MAG) <= 0_i32, "mul overflow");
    SQ128x128 { raw: i256_normalize(I256 { mag, neg: false }) }
}

pub fn mul_down(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    mul_internal(a, b, false)
}

pub fn mul_up(a: SQ128x128, b: SQ128x128) -> SQ128x128 {
    mul_internal(a, b, true)
}

impl SQ128x128PartialEq of PartialEq<SQ128x128> {
    fn eq(lhs: @SQ128x128, rhs: @SQ128x128) -> bool {
        i256_eq(*lhs.raw, *rhs.raw)
    }
}

impl SQ128x128PartialOrd of PartialOrd<SQ128x128> {
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

impl SQ128x128Add of Add<SQ128x128> {
    fn add(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        add_internal(lhs, rhs)
    }
}

impl SQ128x128Sub of Sub<SQ128x128> {
    fn sub(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        sub_internal(lhs, rhs)
    }
}

impl SQ128x128Mul of Mul<SQ128x128> {
    fn mul(lhs: SQ128x128, rhs: SQ128x128) -> SQ128x128 {
        mul_internal(lhs, rhs, false)
    }
}

#[cfg(test)]
mod tests {
    use super::{
        I256, MAX, MIN, NEG_ONE, ONE, ONE_ULP, SQ128x128, ZERO, add, delta, from_int, from_raw,
        mul_down, mul_up, sub,
    };

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
}
