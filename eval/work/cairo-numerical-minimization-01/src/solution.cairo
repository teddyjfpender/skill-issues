// Q64.64 fixed-point type implementation
use core::num::traits::WideMul;

pub const FRACTIONAL_BITS: u8 = 64;

#[derive(Copy, Drop, Debug)]
pub struct Fixed {
    pub value: i128,
}

pub const ONE: Fixed = Fixed { value: 0x10000000000000000 }; // 1 << 64
const SHIFT_U256: u256 = 0x10000000000000000; // 2^64

// Golden ratio φ = (1+√5)/2 ≈ 1.6180339887498948482
// As Q64.64: φ * 2^64 ≈ 29852077638435892953
pub const PHI: Fixed = Fixed { value: 29852077638435892953 };

// 2 - φ ≈ 0.3819660112501051518
// As Q64.64: (2-φ) * 2^64 ≈ 7046029254386351047
pub const RESPHI: Fixed = Fixed { value: 7046029254386351047 };

// Default tolerance: approximately 1e-10 ≈ 2^-33
// As Q64.64: 2^(64-33) = 2^31 = 2147483648
pub const DEFAULT_TOLERANCE: Fixed = Fixed { value: 2147483648 };

// Default max iterations
pub const DEFAULT_MAX_ITERATIONS: u32 = 1000;

#[generate_trait]
pub impl FixedImpl of FixedTrait {
    fn new(value: i128) -> Fixed {
        Fixed { value }
    }

    fn from_int(n: i64) -> Fixed {
        let shift: i128 = 0x10000000000000000; // 1 << 64
        Fixed { value: n.into() * shift }
    }

    fn to_int(self: Fixed) -> i64 {
        let shift: i128 = 0x10000000000000000; // 1 << 64
        let result = self.value / shift;
        result.try_into().unwrap()
    }

    fn abs(self: Fixed) -> Fixed {
        if self.value < 0 {
            Fixed { value: 0 - self.value }
        } else {
            self
        }
    }
}

impl FixedAdd of core::traits::Add<Fixed> {
    fn add(lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed { value: lhs.value + rhs.value }
    }
}

impl FixedSub of core::traits::Sub<Fixed> {
    fn sub(lhs: Fixed, rhs: Fixed) -> Fixed {
        Fixed { value: lhs.value - rhs.value }
    }
}

impl FixedMul of core::traits::Mul<Fixed> {
    fn mul(lhs: Fixed, rhs: Fixed) -> Fixed {
        // Handle signs separately
        let a_neg = lhs.value < 0;
        let b_neg = rhs.value < 0;
        let result_neg = a_neg != b_neg;

        // Get absolute values as u128
        let a_abs: u128 = if a_neg {
            let neg_val: i128 = -lhs.value;
            neg_val.try_into().unwrap()
        } else {
            lhs.value.try_into().unwrap()
        };
        let b_abs: u128 = if b_neg {
            let neg_val: i128 = -rhs.value;
            neg_val.try_into().unwrap()
        } else {
            rhs.value.try_into().unwrap()
        };

        // Wide multiply: u128 * u128 -> u256
        let wide_product: u256 = a_abs.wide_mul(b_abs);

        // Divide by 2^64 (shift right by 64 bits)
        let result_u256 = wide_product / SHIFT_U256;

        // Convert back to i128
        let result_u128: u128 = result_u256.try_into().unwrap();
        let result_i128: i128 = result_u128.try_into().unwrap();

        // Apply sign
        if result_neg {
            Fixed { value: -result_i128 }
        } else {
            Fixed { value: result_i128 }
        }
    }
}

impl FixedDiv of core::traits::Div<Fixed> {
    fn div(lhs: Fixed, rhs: Fixed) -> Fixed {
        // Handle signs separately
        let a_neg = lhs.value < 0;
        let b_neg = rhs.value < 0;
        let result_neg = a_neg != b_neg;

        // Get absolute values as u128
        let a_abs: u128 = if a_neg {
            let neg_val: i128 = -lhs.value;
            neg_val.try_into().unwrap()
        } else {
            lhs.value.try_into().unwrap()
        };
        let b_abs: u128 = if b_neg {
            let neg_val: i128 = -rhs.value;
            neg_val.try_into().unwrap()
        } else {
            rhs.value.try_into().unwrap()
        };

        // For Q64.64 division: (a / b) = (a * 2^64) / b
        // Compute a * 2^64 as u256
        let a_u256: u256 = a_abs.into();
        let a_shifted: u256 = a_u256 * SHIFT_U256;

        // Divide by b
        let b_u256: u256 = b_abs.into();
        let result_u256 = a_shifted / b_u256;

        // Convert back to i128
        let result_u128: u128 = result_u256.try_into().unwrap();
        let result_i128: i128 = result_u128.try_into().unwrap();

        // Apply sign
        if result_neg {
            Fixed { value: -result_i128 }
        } else {
            Fixed { value: result_i128 }
        }
    }
}

impl FixedPartialEq of PartialEq<Fixed> {
    fn eq(lhs: @Fixed, rhs: @Fixed) -> bool {
        *lhs.value == *rhs.value
    }

    fn ne(lhs: @Fixed, rhs: @Fixed) -> bool {
        *lhs.value != *rhs.value
    }
}

impl FixedPartialOrd of PartialOrd<Fixed> {
    fn lt(lhs: Fixed, rhs: Fixed) -> bool {
        lhs.value < rhs.value
    }

    fn le(lhs: Fixed, rhs: Fixed) -> bool {
        lhs.value <= rhs.value
    }

    fn gt(lhs: Fixed, rhs: Fixed) -> bool {
        lhs.value > rhs.value
    }

    fn ge(lhs: Fixed, rhs: Fixed) -> bool {
        lhs.value >= rhs.value
    }
}

pub fn fixed_from_ratio(num: i64, denom: i64) -> Fixed {
    let shift: i128 = 0x10000000000000000; // 1 << 64
    let num_i128: i128 = num.into();
    let denom_i128: i128 = denom.into();
    Fixed { value: (num_i128 * shift) / denom_i128 }
}

pub fn interval_width(a: Fixed, b: Fixed) -> Fixed {
    (b - a).abs()
}

pub fn is_converged(width: Fixed, tolerance: Fixed) -> bool {
    width <= tolerance
}

// Interval struct for golden section search
#[derive(Copy, Drop, Debug)]
pub struct Interval {
    pub low: Fixed,
    pub high: Fixed,
}

// Minimization result struct
#[derive(Copy, Drop, Debug)]
pub struct MinimizationResult {
    pub x_min: Fixed,
    pub f_min: Fixed,
    pub iterations: u32,
    pub converged: bool,
}

#[generate_trait]
pub impl IntervalImpl of IntervalTrait {
    fn new(low: Fixed, high: Fixed) -> Interval {
        Interval { low, high }
    }

    fn width(self: @Interval) -> Fixed {
        (*self.high - *self.low).abs()
    }

    fn midpoint(self: @Interval) -> Fixed {
        let two = FixedTrait::from_int(2);
        (*self.low + *self.high) / two
    }

    fn contains(self: @Interval, x: Fixed) -> bool {
        x >= *self.low && x <= *self.high
    }
}

// Trait for objective functions to be minimized
pub trait ObjectiveFn<T> {
    fn eval(self: @T, x: Fixed) -> Fixed;
}

// Golden section search algorithm
pub fn golden_section_search<T, +ObjectiveFn<T>, +Drop<T>, +Copy<T>>(
    f: @T, interval: Interval, tolerance: Fixed, max_iterations: u32,
) -> MinimizationResult {
    let mut a = interval.low;
    let mut b = interval.high;

    // Check if already converged
    let initial_width = (b - a).abs();
    if is_converged(initial_width, tolerance) {
        let x_min = IntervalTrait::new(a, b).midpoint();
        let f_min = ObjectiveFn::eval(f, x_min);
        return MinimizationResult { x_min, f_min, iterations: 0, converged: true };
    }

    // Initial probe points
    let mut c = b - RESPHI * (b - a);
    let mut d = a + RESPHI * (b - a);
    let mut fc = ObjectiveFn::eval(f, c);
    let mut fd = ObjectiveFn::eval(f, d);

    let mut iterations: u32 = 0;
    let mut converged = false;

    while iterations < max_iterations {
        iterations += 1;

        // c is the RIGHT probe (closer to b), d is the LEFT probe (closer to a)
        // fc < fd means minimum is to the right (closer to c), so narrow to [d, b]
        // fd < fc means minimum is to the left (closer to d), so narrow to [a, c]
        if fc < fd {
            // Minimum is in [d, b] - move left boundary up
            a = d;
            d = c;
            fd = fc;
            c = b - RESPHI * (b - a);
            fc = ObjectiveFn::eval(f, c);
        } else {
            // Minimum is in [a, c] - move right boundary down
            b = c;
            c = d;
            fc = fd;
            d = a + RESPHI * (b - a);
            fd = ObjectiveFn::eval(f, d);
        }

        let width = (b - a).abs();
        if is_converged(width, tolerance) {
            converged = true;
            break;
        }
    };

    let x_min = IntervalTrait::new(a, b).midpoint();
    let f_min = ObjectiveFn::eval(f, x_min);

    MinimizationResult { x_min, f_min, iterations, converged }
}

// Minimizer trait for clean API
pub trait MinimizerTrait<T> {
    fn minimize(f: @T, low: Fixed, high: Fixed) -> MinimizationResult;
    fn minimize_with_tolerance(f: @T, low: Fixed, high: Fixed, tolerance: Fixed) -> MinimizationResult;
    fn minimize_with_options(f: @T, interval: Interval, tolerance: Fixed, max_iter: u32) -> MinimizationResult;
}

// Implementation of MinimizerTrait using golden section search
pub impl MinimizerImpl<T, +ObjectiveFn<T>, +Drop<T>, +Copy<T>> of MinimizerTrait<T> {
    fn minimize(f: @T, low: Fixed, high: Fixed) -> MinimizationResult {
        let interval = IntervalTrait::new(low, high);
        golden_section_search(f, interval, DEFAULT_TOLERANCE, DEFAULT_MAX_ITERATIONS)
    }

    fn minimize_with_tolerance(f: @T, low: Fixed, high: Fixed, tolerance: Fixed) -> MinimizationResult {
        let interval = IntervalTrait::new(low, high);
        golden_section_search(f, interval, tolerance, DEFAULT_MAX_ITERATIONS)
    }

    fn minimize_with_options(f: @T, interval: Interval, tolerance: Fixed, max_iter: u32) -> MinimizationResult {
        golden_section_search(f, interval, tolerance, max_iter)
    }
}

// Test objective function: f(x) = (x - 3)^2, minimum at x = 3
#[derive(Drop, Copy)]
pub struct QuadraticTest {}

pub impl QuadraticTestObjective of ObjectiveFn<QuadraticTest> {
    fn eval(self: @QuadraticTest, x: Fixed) -> Fixed {
        let diff = x - FixedTrait::from_int(3);
        diff * diff
    }
}

// Test objective function: f(x) = x^2 + 2x + 1 = (x + 1)^2, minimum at x = -1
#[derive(Drop, Copy)]
pub struct ShiftedParabola {}

pub impl ShiftedParabolaObjective of ObjectiveFn<ShiftedParabola> {
    fn eval(self: @ShiftedParabola, x: Fixed) -> Fixed {
        let one = FixedTrait::from_int(1);
        let diff = x + one;
        diff * diff
    }
}

// Test objective function: f(x) = (x - 1)^4, minimum at x = 1 (flat near minimum)
#[derive(Drop, Copy)]
pub struct QuarticTest {}

pub impl QuarticTestObjective of ObjectiveFn<QuarticTest> {
    fn eval(self: @QuarticTest, x: Fixed) -> Fixed {
        let one = FixedTrait::from_int(1);
        let diff = x - one;
        let diff_sq = diff * diff;
        diff_sq * diff_sq
    }
}
