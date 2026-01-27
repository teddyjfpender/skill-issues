use cairo_numerical_minimization_01::{
    Fixed, FixedTrait, ONE, FRACTIONAL_BITS, PHI, RESPHI, fixed_from_ratio, interval_width,
    is_converged, Interval, IntervalTrait, MinimizationResult, ObjectiveFn, golden_section_search,
    MinimizerTrait, MinimizerImpl, DEFAULT_TOLERANCE, DEFAULT_MAX_ITERATIONS,
    QuadraticTest, QuadraticTestObjective, ShiftedParabola, ShiftedParabolaObjective,
    QuarticTest, QuarticTestObjective,
};

#[test]
fn test_from_int_and_to_int() {
    let f = FixedTrait::from_int(5);
    assert!(f.to_int() == 5);

    let f2 = FixedTrait::from_int(-3);
    assert!(f2.to_int() == -3);

    let f3 = FixedTrait::from_int(0);
    assert!(f3.to_int() == 0);
}

#[test]
fn test_one_constant() {
    assert!(ONE.to_int() == 1);
}

#[test]
fn test_addition() {
    let a = FixedTrait::from_int(3);
    let b = FixedTrait::from_int(4);
    let c = a + b;
    assert!(c.to_int() == 7);
}

#[test]
fn test_subtraction() {
    let a = FixedTrait::from_int(10);
    let b = FixedTrait::from_int(4);
    let c = a - b;
    assert!(c.to_int() == 6);
}

#[test]
fn test_multiplication() {
    let a = FixedTrait::from_int(3);
    let b = FixedTrait::from_int(4);
    let c = a * b;
    assert!(c.to_int() == 12);
}

#[test]
fn test_division() {
    let a = FixedTrait::from_int(12);
    let b = FixedTrait::from_int(4);
    let c = a / b;
    assert!(c.to_int() == 3);
}

#[test]
fn test_abs() {
    let pos = FixedTrait::from_int(5);
    assert!(pos.abs().to_int() == 5);

    let neg = FixedTrait::from_int(-5);
    assert!(neg.abs().to_int() == 5);
}

#[test]
fn test_comparison() {
    let a = FixedTrait::from_int(3);
    let b = FixedTrait::from_int(5);
    let c = FixedTrait::from_int(3);

    assert!(a < b);
    assert!(b > a);
    assert!(a <= c);
    assert!(a >= c);
    assert!(a == c);
    assert!(a != b);
}

#[test]
fn test_fractional_bits_constant() {
    assert!(FRACTIONAL_BITS == 64);
}

#[test]
fn test_phi_constant() {
    // PHI should be approximately 1.618
    assert!(PHI.to_int() == 1);
    // PHI should be greater than 1.5
    let one_and_half = FixedTrait::from_int(1) + fixed_from_ratio(1, 2);
    assert!(PHI > one_and_half);
    // PHI should be less than 2
    let two = FixedTrait::from_int(2);
    assert!(PHI < two);
}

#[test]
fn test_resphi_constant() {
    // RESPHI should be approximately 0.382
    assert!(RESPHI.to_int() == 0);
    // RESPHI should be greater than 0.3
    let point_three = fixed_from_ratio(3, 10);
    assert!(RESPHI > point_three);
    // RESPHI should be less than 0.5
    let point_five = fixed_from_ratio(1, 2);
    assert!(RESPHI < point_five);
}

#[test]
fn test_phi_plus_resphi() {
    // PHI + RESPHI should equal 2
    let sum = PHI + RESPHI;
    let two = FixedTrait::from_int(2);
    // Allow small tolerance for fixed-point rounding
    let diff = (sum - two).abs();
    let tolerance = FixedTrait::new(1000); // Very small tolerance
    assert!(diff < tolerance);
}

#[test]
fn test_fixed_from_ratio() {
    // 1/2 = 0.5
    let half = fixed_from_ratio(1, 2);
    let one = FixedTrait::from_int(1);
    let result = half + half;
    assert!(result.to_int() == one.to_int());

    // 3/4 = 0.75
    let three_quarters = fixed_from_ratio(3, 4);
    assert!(three_quarters.to_int() == 0);
    assert!(three_quarters > half);

    // 5/1 = 5
    let five = fixed_from_ratio(5, 1);
    assert!(five.to_int() == 5);
}

#[test]
fn test_interval_width() {
    let a = FixedTrait::from_int(3);
    let b = FixedTrait::from_int(7);
    let width = interval_width(a, b);
    assert!(width.to_int() == 4);

    // Test with reversed order (should still be positive)
    let width2 = interval_width(b, a);
    assert!(width2.to_int() == 4);
}

#[test]
fn test_interval_width_negative() {
    let a = FixedTrait::from_int(-5);
    let b = FixedTrait::from_int(5);
    let width = interval_width(a, b);
    assert!(width.to_int() == 10);
}

#[test]
fn test_is_converged() {
    let small_width = fixed_from_ratio(1, 1000);
    let large_tolerance = fixed_from_ratio(1, 100);
    assert!(is_converged(small_width, large_tolerance));

    let large_width = FixedTrait::from_int(1);
    let small_tolerance = fixed_from_ratio(1, 1000);
    assert!(!is_converged(large_width, small_tolerance));

    // Equal case
    let width = fixed_from_ratio(1, 100);
    let tolerance = fixed_from_ratio(1, 100);
    assert!(is_converged(width, tolerance));
}

#[test]
fn test_interval_new() {
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(10);
    let interval = IntervalTrait::new(low, high);
    assert!(interval.low.to_int() == 0);
    assert!(interval.high.to_int() == 10);
}

#[test]
fn test_interval_width_method() {
    let low = FixedTrait::from_int(2);
    let high = FixedTrait::from_int(8);
    let interval = IntervalTrait::new(low, high);
    assert!(interval.width().to_int() == 6);
}

#[test]
fn test_interval_midpoint() {
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(10);
    let interval = IntervalTrait::new(low, high);
    assert!(interval.midpoint().to_int() == 5);

    let low2 = FixedTrait::from_int(2);
    let high2 = FixedTrait::from_int(6);
    let interval2 = IntervalTrait::new(low2, high2);
    assert!(interval2.midpoint().to_int() == 4);
}

#[test]
fn test_interval_midpoint_negative() {
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    let interval = IntervalTrait::new(low, high);
    assert!(interval.midpoint().to_int() == 0);
}

#[test]
fn test_interval_contains() {
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(10);
    let interval = IntervalTrait::new(low, high);

    // Inside
    let mid = FixedTrait::from_int(5);
    assert!(interval.contains(mid));

    // At boundaries
    assert!(interval.contains(low));
    assert!(interval.contains(high));

    // Outside
    let below = FixedTrait::from_int(-1);
    let above = FixedTrait::from_int(11);
    assert!(!interval.contains(below));
    assert!(!interval.contains(above));
}

#[test]
fn test_minimization_result_struct() {
    let result = MinimizationResult {
        x_min: FixedTrait::from_int(3),
        f_min: FixedTrait::from_int(9),
        iterations: 10,
        converged: true,
    };
    assert!(result.x_min.to_int() == 3);
    assert!(result.f_min.to_int() == 9);
    assert!(result.iterations == 10);
    assert!(result.converged);
}

#[test]
fn test_minimization_result_not_converged() {
    let result = MinimizationResult {
        x_min: FixedTrait::from_int(5),
        f_min: FixedTrait::from_int(25),
        iterations: 100,
        converged: false,
    };
    assert!(result.iterations == 100);
    assert!(!result.converged);
}

// Test objective function: f(x) = x^2, minimum at x = 0
#[derive(Copy, Drop)]
struct QuadraticFn {}

impl QuadraticFnObjective of ObjectiveFn<QuadraticFn> {
    fn eval(self: @QuadraticFn, x: Fixed) -> Fixed {
        x * x
    }
}

// Test objective function: f(x) = (x - 3)^2, minimum at x = 3
#[derive(Copy, Drop)]
struct ShiftedQuadraticFn {}

impl ShiftedQuadraticFnObjective of ObjectiveFn<ShiftedQuadraticFn> {
    fn eval(self: @ShiftedQuadraticFn, x: Fixed) -> Fixed {
        let three = FixedTrait::from_int(3);
        let diff = x - three;
        diff * diff
    }
}

#[test]
fn test_objective_fn_trait() {
    let f = QuadraticFn {};
    let x = FixedTrait::from_int(3);
    let result = f.eval(x);
    assert!(result.to_int() == 9);

    let x2 = FixedTrait::from_int(0);
    let result2 = f.eval(x2);
    assert!(result2.to_int() == 0);
}

#[test]
fn test_golden_section_search_quadratic() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(-10), FixedTrait::from_int(10));
    let tolerance = fixed_from_ratio(1, 1000);
    let max_iterations: u32 = 100;

    let result = golden_section_search(@f, interval, tolerance, max_iterations);

    // Minimum should be near 0
    assert!(result.x_min.abs().to_int() == 0);
    assert!(result.f_min.to_int() == 0);
    assert!(result.converged);
    assert!(result.iterations > 0);
}

#[test]
fn test_golden_section_search_shifted() {
    let f = ShiftedQuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(0), FixedTrait::from_int(10));
    let tolerance = fixed_from_ratio(1, 100);
    let max_iterations: u32 = 100;

    let result = golden_section_search(@f, interval, tolerance, max_iterations);

    // Minimum should be near 3
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

#[test]
fn test_golden_section_search_already_converged() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(
        fixed_from_ratio(-1, 10000), fixed_from_ratio(1, 10000),
    );
    let tolerance = fixed_from_ratio(1, 100);
    let max_iterations: u32 = 100;

    let result = golden_section_search(@f, interval, tolerance, max_iterations);

    // Should converge immediately
    assert!(result.iterations == 0);
    assert!(result.converged);
}

#[test]
fn test_golden_section_search_max_iterations() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(-1000), FixedTrait::from_int(1000));
    let tolerance = FixedTrait::new(1); // Extremely tight tolerance
    let max_iterations: u32 = 5;

    let result = golden_section_search(@f, interval, tolerance, max_iterations);

    // Should hit max iterations
    assert!(result.iterations == max_iterations);
    // May or may not have converged depending on tolerance
}

#[test]
fn test_golden_section_convergence_rate() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(-10), FixedTrait::from_int(10));
    let tolerance = fixed_from_ratio(1, 1000);
    let max_iterations: u32 = 100;

    let result = golden_section_search(@f, interval, tolerance, max_iterations);

    // Golden section should converge in O(log(1/tolerance)) iterations
    // For interval width 20 and tolerance 0.001, should need roughly log_phi(20000) ≈ 21 iterations
    assert!(result.iterations < 30);
    assert!(result.converged);
}

// Tests for MinimizerTrait
#[test]
fn test_default_tolerance_constant() {
    // DEFAULT_TOLERANCE should be approximately 1e-10
    // It should be a very small positive value
    assert!(DEFAULT_TOLERANCE.value > 0);
    // It should be less than 1e-6 (as fixed-point)
    let one_millionth = fixed_from_ratio(1, 1000000);
    assert!(DEFAULT_TOLERANCE < one_millionth);
}

#[test]
fn test_default_max_iterations_constant() {
    assert!(DEFAULT_MAX_ITERATIONS == 1000);
}

#[test]
fn test_minimizer_minimize() {
    let f = QuadraticFn {};
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);

    let result = MinimizerImpl::minimize(@f, low, high);

    // Minimum should be near 0
    assert!(result.x_min.abs().to_int() == 0);
    assert!(result.f_min.to_int() == 0);
    assert!(result.converged);
}

#[test]
fn test_minimizer_minimize_with_tolerance() {
    let f = ShiftedQuadraticFn {};
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(10);
    let tolerance = fixed_from_ratio(1, 100);

    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);

    // Minimum should be near 3
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

#[test]
fn test_minimizer_minimize_with_options() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(-5), FixedTrait::from_int(5));
    let tolerance = fixed_from_ratio(1, 1000);
    let max_iter: u32 = 50;

    let result = MinimizerImpl::minimize_with_options(@f, interval, tolerance, max_iter);

    // Minimum should be near 0
    assert!(result.x_min.abs().to_int() == 0);
    assert!(result.converged);
    assert!(result.iterations <= max_iter);
}

#[test]
fn test_minimizer_methods_consistency() {
    let f = QuadraticFn {};
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    let tolerance = fixed_from_ratio(1, 1000);

    // All methods should find the same minimum (approximately)
    let result1 = MinimizerImpl::minimize(@f, low, high);
    let result2 = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);
    let interval = IntervalTrait::new(low, high);
    let result3 = MinimizerImpl::minimize_with_options(@f, interval, tolerance, 100);

    // All should converge
    assert!(result1.converged);
    assert!(result2.converged);
    assert!(result3.converged);

    // All should find minimum near 0
    assert!(result1.x_min.abs().to_int() == 0);
    assert!(result2.x_min.abs().to_int() == 0);
    assert!(result3.x_min.abs().to_int() == 0);
}

#[test]
fn test_minimizer_with_shifted_quadratic() {
    let f = ShiftedQuadraticFn {};
    let low = FixedTrait::from_int(-5);
    let high = FixedTrait::from_int(10);

    let result = MinimizerImpl::minimize(@f, low, high);

    // Minimum should be near 3
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    // With default tolerance (1e-10), should be very close
    let acceptable_error = fixed_from_ratio(1, 1000);
    assert!(diff < acceptable_error);
    assert!(result.converged);
}

#[test]
fn test_minimizer_tight_tolerance() {
    let f = QuadraticFn {};
    let low = FixedTrait::from_int(-1);
    let high = FixedTrait::from_int(1);
    let very_tight_tolerance = FixedTrait::new(100); // Very small

    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, very_tight_tolerance);

    // Should still converge with default max_iterations=1000
    assert!(result.converged);
    // Minimum should be very close to 0
    assert!(result.x_min.abs() < fixed_from_ratio(1, 1000000));
}

#[test]
fn test_minimizer_limited_iterations() {
    let f = QuadraticFn {};
    let interval = IntervalTrait::new(FixedTrait::from_int(-100), FixedTrait::from_int(100));
    let tolerance = FixedTrait::new(1); // Impossibly tight
    let max_iter: u32 = 10;

    let result = MinimizerImpl::minimize_with_options(@f, interval, tolerance, max_iter);

    // Should hit max iterations
    assert!(result.iterations == max_iter);
    // May not have converged due to tight tolerance
}

// Tests for QuadraticTest: f(x) = (x - 3)^2, minimum at x = 3
#[test]
fn test_quadratic_test_eval() {
    let f = QuadraticTest {};
    
    // At minimum x = 3, f(3) = 0
    let x_min = FixedTrait::from_int(3);
    let f_min = f.eval(x_min);
    assert!(f_min.to_int() == 0);
    
    // At x = 0, f(0) = 9
    let x_zero = FixedTrait::from_int(0);
    let f_zero = f.eval(x_zero);
    assert!(f_zero.to_int() == 9);
    
    // At x = 5, f(5) = 4
    let x_five = FixedTrait::from_int(5);
    let f_five = f.eval(x_five);
    assert!(f_five.to_int() == 4);
}

#[test]
fn test_quadratic_test_minimization() {
    let f = QuadraticTest {};
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(10);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    // Minimum should be near 3
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
    // f_min should be near 0
    assert!(result.f_min.to_int() == 0);
}

// Tests for ShiftedParabola: f(x) = (x + 1)^2, minimum at x = -1
#[test]
fn test_shifted_parabola_eval() {
    let f = ShiftedParabola {};
    
    // At minimum x = -1, f(-1) = 0
    let x_min = FixedTrait::from_int(-1);
    let f_min = f.eval(x_min);
    assert!(f_min.to_int() == 0);
    
    // At x = 0, f(0) = 1
    let x_zero = FixedTrait::from_int(0);
    let f_zero = f.eval(x_zero);
    assert!(f_zero.to_int() == 1);
    
    // At x = 1, f(1) = 4
    let x_one = FixedTrait::from_int(1);
    let f_one = f.eval(x_one);
    assert!(f_one.to_int() == 4);
}

#[test]
fn test_shifted_parabola_minimization() {
    let f = ShiftedParabola {};
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    // Minimum should be near -1
    let diff = (result.x_min - FixedTrait::from_int(-1)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
    // f_min should be near 0
    assert!(result.f_min.to_int() == 0);
}

// Tests for QuarticTest: f(x) = (x - 1)^4, minimum at x = 1
#[test]
fn test_quartic_test_eval() {
    let f = QuarticTest {};
    
    // At minimum x = 1, f(1) = 0
    let x_min = FixedTrait::from_int(1);
    let f_min = f.eval(x_min);
    assert!(f_min.to_int() == 0);
    
    // At x = 0, f(0) = 1
    let x_zero = FixedTrait::from_int(0);
    let f_zero = f.eval(x_zero);
    assert!(f_zero.to_int() == 1);
    
    // At x = 2, f(2) = 1
    let x_two = FixedTrait::from_int(2);
    let f_two = f.eval(x_two);
    assert!(f_two.to_int() == 1);
    
    // At x = 3, f(3) = 16
    let x_three = FixedTrait::from_int(3);
    let f_three = f.eval(x_three);
    assert!(f_three.to_int() == 16);
}

#[test]
fn test_quartic_test_minimization() {
    let f = QuarticTest {};
    let low = FixedTrait::from_int(-5);
    let high = FixedTrait::from_int(5);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    // Minimum should be near 1
    let diff = (result.x_min - FixedTrait::from_int(1)).abs();
    let tolerance = fixed_from_ratio(1, 100);
    assert!(diff < tolerance);
    assert!(result.converged);
    // f_min should be near 0
    assert!(result.f_min.to_int() == 0);
}

#[test]
fn test_quartic_flat_near_minimum() {
    // Quartic functions are flatter near the minimum than quadratics
    // This tests that the minimizer still converges correctly
    let f = QuarticTest {};
    let low = FixedTrait::from_int(0);
    let high = FixedTrait::from_int(2);
    let tolerance = fixed_from_ratio(1, 1000);
    
    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);
    
    // Should still find minimum near 1
    let diff = (result.x_min - FixedTrait::from_int(1)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

// ============================================================================
// Step 7: Exhaustive correctness and edge case tests
// ============================================================================

// Test QuadraticTest minimum is within tolerance of x=3
#[test]
fn test_quadratic_test_minimum_within_tolerance() {
    let f = QuadraticTest {};
    let tolerance = fixed_from_ratio(1, 1000000); // 1e-6
    let result = MinimizerImpl::minimize_with_tolerance(
        @f, 
        FixedTrait::from_int(0), 
        FixedTrait::from_int(10),
        tolerance
    );
    
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test ShiftedParabola minimum is within tolerance of x=-1
#[test]
fn test_shifted_parabola_minimum_within_tolerance() {
    let f = ShiftedParabola {};
    let tolerance = fixed_from_ratio(1, 1000000); // 1e-6
    let result = MinimizerImpl::minimize_with_tolerance(
        @f,
        FixedTrait::from_int(-10),
        FixedTrait::from_int(10),
        tolerance
    );
    
    let diff = (result.x_min - FixedTrait::from_int(-1)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test QuarticTest minimum is within tolerance of x=1 (harder due to flat region)
#[test]
fn test_quartic_test_minimum_within_tolerance() {
    let f = QuarticTest {};
    // Quartic is flatter, so use looser tolerance
    let tolerance = fixed_from_ratio(1, 10000); // 1e-4
    let result = MinimizerImpl::minimize_with_tolerance(
        @f,
        FixedTrait::from_int(-5),
        FixedTrait::from_int(5),
        tolerance
    );
    
    let diff = (result.x_min - FixedTrait::from_int(1)).abs();
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test convergence flag is true for all standard cases
#[test]
fn test_convergence_flag_standard_cases() {
    let f1 = QuadraticTest {};
    let f2 = ShiftedParabola {};
    let f3 = QuarticTest {};
    
    let result1 = MinimizerImpl::minimize(@f1, FixedTrait::from_int(0), FixedTrait::from_int(10));
    let result2 = MinimizerImpl::minimize(@f2, FixedTrait::from_int(-5), FixedTrait::from_int(5));
    let result3 = MinimizerImpl::minimize(@f3, FixedTrait::from_int(-3), FixedTrait::from_int(3));
    
    assert!(result1.converged);
    assert!(result2.converged);
    assert!(result3.converged);
}

// Test iteration count is reasonable (< 100 for tolerance 1e-6)
#[test]
fn test_iteration_count_reasonable() {
    let f = QuadraticTest {};
    let tolerance = fixed_from_ratio(1, 1000000); // 1e-6
    let result = MinimizerImpl::minimize_with_tolerance(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(10),
        tolerance
    );
    
    assert!(result.iterations < 100);
    assert!(result.converged);
}

// Test with very tight tolerance (1e-12) still converges
#[test]
fn test_very_tight_tolerance_converges() {
    let f = QuadraticFn {};
    // 1e-12 ≈ 2^-40, as Q64.64: 2^(64-40) = 2^24
    let very_tight_tolerance = FixedTrait::new(16777216); // 2^24
    
    let result = MinimizerImpl::minimize_with_tolerance(
        @f,
        FixedTrait::from_int(-1),
        FixedTrait::from_int(1),
        very_tight_tolerance
    );
    
    assert!(result.converged);
    // Should still find minimum near 0
    assert!(result.x_min.abs() < fixed_from_ratio(1, 1000000));
}

// Test with loose tolerance (1e-2) converges in few iterations
#[test]
fn test_loose_tolerance_few_iterations() {
    let f = QuadraticTest {};
    let loose_tolerance = fixed_from_ratio(1, 100); // 1e-2
    
    let result = MinimizerImpl::minimize_with_tolerance(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(10),
        loose_tolerance
    );
    
    assert!(result.converged);
    // With loose tolerance, should converge quickly
    assert!(result.iterations < 20);
}

// Test interval already at minimum (width < tolerance)
#[test]
fn test_interval_already_at_minimum() {
    let f = QuadraticTest {};
    // Create a very narrow interval around x=3
    let narrow_low = FixedTrait::from_int(3) - fixed_from_ratio(1, 10000);
    let narrow_high = FixedTrait::from_int(3) + fixed_from_ratio(1, 10000);
    let tolerance = fixed_from_ratio(1, 100);
    
    let result = MinimizerImpl::minimize_with_tolerance(@f, narrow_low, narrow_high, tolerance);
    
    // Should converge immediately with 0 iterations
    assert!(result.iterations == 0);
    assert!(result.converged);
}

// Test symmetric interval around minimum
#[test]
fn test_symmetric_interval_around_minimum() {
    let f = QuadraticTest {};
    // Symmetric interval: [0, 6] with minimum at 3
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(6)
    );
    
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test asymmetric interval (minimum near one boundary)
#[test]
fn test_asymmetric_interval_minimum_near_boundary() {
    let f = QuadraticTest {};
    // Interval [2.5, 10] with minimum at 3 (near left boundary)
    let low = FixedTrait::from_int(2) + fixed_from_ratio(1, 2);
    let high = FixedTrait::from_int(10);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test minimum at left boundary of interval
#[test]
fn test_minimum_at_left_boundary() {
    // Use f(x) = x^2 with interval [0, 10], minimum at x=0 (left boundary)
    let f = QuadraticFn {};
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(10)
    );
    
    // Minimum should be near 0 (left boundary)
    assert!(result.x_min.abs().to_int() == 0);
    assert!(result.converged);
}

// Test minimum at right boundary of interval
#[test]
fn test_minimum_at_right_boundary() {
    // Use f(x) = -x (decreasing), so minimum in [0, 10] is at x=10
    // Since we can't easily create decreasing function, test with shifted quadratic
    // f(x) = (x - 10)^2, minimum at x=10 (right boundary of [0, 10])
    #[derive(Copy, Drop)]
    struct RightBoundaryFn {}
    
    impl RightBoundaryFnObjective of ObjectiveFn<RightBoundaryFn> {
        fn eval(self: @RightBoundaryFn, x: Fixed) -> Fixed {
            let ten = FixedTrait::from_int(10);
            let diff = x - ten;
            diff * diff
        }
    }
    
    let f = RightBoundaryFn {};
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(10)
    );
    
    // Minimum should be near 10 (right boundary)
    let diff = (result.x_min - FixedTrait::from_int(10)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test that f_min value is correct (not just x_min location)
#[test]
fn test_f_min_value_correct() {
    let f = QuadraticTest {};
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(0),
        FixedTrait::from_int(10)
    );
    
    // f_min should be close to 0 (since minimum of (x-3)^2 is 0)
    assert!(result.f_min.abs().to_int() == 0);
    
    // Verify f_min matches f(x_min)
    let computed_f_min = f.eval(result.x_min);
    let diff = (result.f_min - computed_f_min).abs();
    let small_tolerance = FixedTrait::new(1000);
    assert!(diff < small_tolerance);
}

// Test f_min for shifted parabola
#[test]
fn test_f_min_shifted_parabola() {
    let f = ShiftedParabola {};
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(-5),
        FixedTrait::from_int(5)
    );
    
    // f_min should be close to 0 (since minimum of (x+1)^2 is 0)
    assert!(result.f_min.abs().to_int() == 0);
}

// Test f_min for quartic
#[test]
fn test_f_min_quartic() {
    let f = QuarticTest {};
    let result = MinimizerImpl::minimize(
        @f,
        FixedTrait::from_int(-3),
        FixedTrait::from_int(3)
    );
    
    // f_min should be close to 0 (since minimum of (x-1)^4 is 0)
    assert!(result.f_min.abs().to_int() == 0);
}

// Verify golden ratio convergence rate: iterations ≈ log(width/tolerance) / log(φ)
#[test]
fn test_golden_ratio_convergence_rate_verification() {
    let f = QuadraticFn {};
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    // Tolerance 1e-6
    let tolerance = fixed_from_ratio(1, 1000000);
    
    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);
    
    // width = 20, tolerance ≈ 1e-6
    // log_phi(20 / 1e-6) = log_phi(2e7) ≈ log(2e7) / log(1.618) ≈ 16.8 / 0.481 ≈ 35
    // Allow some margin for implementation details
    assert!(result.iterations > 20);
    assert!(result.iterations < 50);
    assert!(result.converged);
}

// Test convergence rate with different interval widths
#[test]
fn test_convergence_rate_small_interval() {
    let f = QuadraticFn {};
    // Small interval: width = 2
    let low = FixedTrait::from_int(-1);
    let high = FixedTrait::from_int(1);
    let tolerance = fixed_from_ratio(1, 1000);
    
    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);
    
    // width = 2, tolerance = 1e-3
    // log_phi(2000) ≈ 15.8
    assert!(result.iterations < 25);
    assert!(result.converged);
}

// Test convergence rate with large interval
#[test]
fn test_convergence_rate_large_interval() {
    let f = QuadraticFn {};
    // Large interval: width = 200
    let low = FixedTrait::from_int(-100);
    let high = FixedTrait::from_int(100);
    let tolerance = fixed_from_ratio(1, 1000);
    
    let result = MinimizerImpl::minimize_with_tolerance(@f, low, high, tolerance);
    
    // width = 200, tolerance = 1e-3
    // log_phi(200000) ≈ 25.4
    assert!(result.iterations < 40);
    assert!(result.converged);
}

// Test with negative interval
#[test]
fn test_negative_interval() {
    let f = ShiftedParabola {};
    // Interval [-10, -0.5] should still find minimum at -1
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(0) - fixed_from_ratio(1, 2);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    let diff = (result.x_min - FixedTrait::from_int(-1)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test with very narrow interval
#[test]
fn test_very_narrow_interval() {
    let f = QuadraticTest {};
    // Very narrow interval around minimum: [2.999, 3.001]
    let narrow_half = fixed_from_ratio(1, 1000);
    let three = FixedTrait::from_int(3);
    let low = three - narrow_half;
    let high = three + narrow_half;
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    let diff = (result.x_min - three).abs();
    assert!(diff < narrow_half);
    assert!(result.converged);
}

// Test with wide interval
#[test]
fn test_wide_interval() {
    let f = QuadraticTest {};
    // Wide interval: [-100, 100] with minimum at 3
    let low = FixedTrait::from_int(-100);
    let high = FixedTrait::from_int(100);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    let diff = (result.x_min - FixedTrait::from_int(3)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}

// Test that all three test functions find correct minimum with same tolerance
#[test]
fn test_all_functions_same_tolerance() {
    let f1 = QuadraticTest {};
    let f2 = ShiftedParabola {};
    let f3 = QuarticTest {};
    let tolerance = fixed_from_ratio(1, 10000); // 1e-4
    
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    
    let result1 = MinimizerImpl::minimize_with_tolerance(@f1, low, high, tolerance);
    let result2 = MinimizerImpl::minimize_with_tolerance(@f2, low, high, tolerance);
    let result3 = MinimizerImpl::minimize_with_tolerance(@f3, low, high, tolerance);
    
    // QuadraticTest: minimum at x=3
    let diff1 = (result1.x_min - FixedTrait::from_int(3)).abs();
    assert!(diff1 < tolerance);
    
    // ShiftedParabola: minimum at x=-1
    let diff2 = (result2.x_min - FixedTrait::from_int(-1)).abs();
    assert!(diff2 < tolerance);
    
    // QuarticTest: minimum at x=1
    let diff3 = (result3.x_min - FixedTrait::from_int(1)).abs();
    assert!(diff3 < tolerance);
    
    assert!(result1.converged);
    assert!(result2.converged);
    assert!(result3.converged);
}

// Test iteration count comparison between different tolerances
#[test]
fn test_iteration_count_vs_tolerance() {
    let f = QuadraticFn {};
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    
    let loose_tol = fixed_from_ratio(1, 10); // 0.1
    let tight_tol = fixed_from_ratio(1, 10000); // 1e-4
    
    let result_loose = MinimizerImpl::minimize_with_tolerance(@f, low, high, loose_tol);
    let result_tight = MinimizerImpl::minimize_with_tolerance(@f, low, high, tight_tol);
    
    // Tighter tolerance should require more iterations
    assert!(result_tight.iterations > result_loose.iterations);
    assert!(result_loose.converged);
    assert!(result_tight.converged);
}

// Test that f_min is always non-negative for these test functions
#[test]
fn test_f_min_non_negative() {
    let f1 = QuadraticTest {};
    let f2 = ShiftedParabola {};
    let f3 = QuarticTest {};
    
    let low = FixedTrait::from_int(-10);
    let high = FixedTrait::from_int(10);
    
    let result1 = MinimizerImpl::minimize(@f1, low, high);
    let result2 = MinimizerImpl::minimize(@f2, low, high);
    let result3 = MinimizerImpl::minimize(@f3, low, high);
    
    // All squared functions should have non-negative f_min
    assert!(result1.f_min.value >= 0);
    assert!(result2.f_min.value >= 0);
    assert!(result3.f_min.value >= 0);
}

// Test x_min is within the original interval bounds
#[test]
fn test_x_min_within_bounds() {
    let f = QuadraticTest {};
    let low = FixedTrait::from_int(1);
    let high = FixedTrait::from_int(5);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    // x_min should be within [1, 5]
    assert!(result.x_min >= low);
    assert!(result.x_min <= high);
    assert!(result.converged);
}

// Test with interval that doesn't contain the global minimum
#[test]
fn test_interval_without_global_minimum() {
    let f = QuadraticTest {};
    // Interval [5, 10] doesn't contain x=3 (minimum)
    // Should find minimum at left boundary
    let low = FixedTrait::from_int(5);
    let high = FixedTrait::from_int(10);
    
    let result = MinimizerImpl::minimize(@f, low, high);
    
    // Should find minimum near 5 (closest point to actual minimum)
    let diff = (result.x_min - FixedTrait::from_int(5)).abs();
    let tolerance = fixed_from_ratio(1, 1000);
    assert!(diff < tolerance);
    assert!(result.converged);
}
