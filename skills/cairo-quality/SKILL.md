# Cairo Code Quality Guidelines

This skill defines quality standards for production-ready Cairo code. Follow these guidelines to produce clean, efficient, maintainable, and auditable code.

---

## CRITICAL: No Unused Imports

**This is the #1 linter warning. Fix it BEFORE submitting code.**

Every `use` statement MUST be used in the code. If you import something, USE IT. If you don't need it, DON'T IMPORT IT.

### Decision Tree

```
Do you need max/min for u32 comparison?
├── YES: Use core::cmp functions directly (they work with any PartialOrd type)
│        use core::cmp::{max, min};
│        let bigger = max(a, b);  // MUST actually call max()
│        let smaller = min(a, b); // MUST actually call min()
│
└── NO:  Don't import them at all
         // No use statement needed
         fn max_u32(a: u32, b: u32) -> u32 { if a > b { a } else { b } }
```

### Common Mistake

```cairo
// ❌ BAD: Imports core::cmp but uses custom helpers - LINTER ERROR
use core::cmp::{max, min};  // WARNING: Unused import!

fn max_u32(a: u32, b: u32) -> u32 { if a > b { a } else { b } }
fn min_u32(a: u32, b: u32) -> u32 { if a < b { a } else { b } }

pub fn solve(arr: @Array<u32>) -> u32 {
    let bigger = max_u32(x, y);  // Uses custom helper, not core::cmp::max
}
```

```cairo
// ✅ GOOD Option 1: Use the imports you declared
use core::cmp::{max, min};

pub fn solve(arr: @Array<u32>) -> u32 {
    let bigger = max(x, y);   // Actually uses core::cmp::max
    let smaller = min(x, y);  // Actually uses core::cmp::min
}
```

```cairo
// ✅ GOOD Option 2: Don't import if using custom helpers
// NO use statement for core::cmp

fn max_u32(a: u32, b: u32) -> u32 { if a > b { a } else { b } }
fn min_u32(a: u32, b: u32) -> u32 { if a < b { a } else { b } }

pub fn solve(arr: @Array<u32>) -> u32 {
    let bigger = max_u32(x, y);  // Uses custom helper
}
```

### Before Every Submission

1. Look at ALL `use` statements at the top of the file
2. For EACH import, search the file for where it's used
3. If an import is NOT used anywhere, REMOVE the `use` line
4. If you want to use `core::cmp::max`, call `max()` not `max_u32()`

---

## 1. Algorithm Documentation

Every public function MUST include a doc comment with:
- **Purpose**: One-line description of what it does
- **Time complexity**: Big-O notation
- **Space complexity**: Big-O notation
- **Algorithm**: Brief description of approach (for non-trivial functions)

```cairo
/// Calculates trapped rainwater using two-pointer technique.
/// 
/// Time: O(n) - single pass through array
/// Space: O(1) - only uses fixed number of variables
/// 
/// Algorithm: Maintain left/right pointers and track max heights seen
/// from each direction. Water at each position is bounded by the
/// smaller of the two maxes.
pub fn trap_two_pointers(height: @Array<u32>) -> u32 {
    // ...
}
```

---

## 2. DRY (Don't Repeat Yourself)

### Extract Common Edge Cases
```cairo
// BAD: Repeated in every function
pub fn solution_a(arr: @Array<u32>) -> u32 {
    if arr.len() <= 2 { return 0; }
    // ...
}
pub fn solution_b(arr: @Array<u32>) -> u32 {
    if arr.len() <= 2 { return 0; }
    // ...
}

// GOOD: Extract to helper
fn is_trivial_input(arr: @Array<u32>) -> bool {
    arr.len() <= 2
}

pub fn solution_a(arr: @Array<u32>) -> u32 {
    if is_trivial_input(arr) { return 0; }
    // ...
}
```

### Prefer Core Library Over Custom Helpers
```cairo
// BAD: Type-specific helpers when core library works
fn max_u32(a: u32, b: u32) -> u32 { if a > b { a } else { b } }
fn max_u64(a: u64, b: u64) -> u64 { if a > b { a } else { b } }

// GOOD: Use core::cmp (works with any PartialOrd type)
use core::cmp::{max, min};
let bigger = max(a, b);   // Works for u32, u64, etc.
let smaller = min(a, b);
```

**⚠️ IMPORTANT**: If you use `core::cmp::{max, min}`, you MUST call `max()` and `min()` in your code. See "CRITICAL: No Unused Imports" section above.

---

## 3. Cairo Array Patterns

### CRITICAL: Arrays Are Immutable

Cairo arrays cannot be modified in place. Rebuilding arrays in loops creates O(n²) complexity.

```cairo
// BAD: O(n²) - rebuilds entire array each iteration
let mut i = n - 1;
loop {
    let mut new_arr: Array<u32> = array![];
    let mut j: u32 = 0;
    while j < n {
        if j == i {
            new_arr.append(new_value);
        } else {
            new_arr.append(*arr.at(j));
        }
        j += 1;
    };
    arr = new_arr;
    if i == 0 { break; }
    i -= 1;
};

// GOOD: O(n) - build array in single forward pass
let mut result: Array<u32> = array![];
let mut i: u32 = 0;
while i < n {
    result.append(compute_value(i));
    i += 1;
};
```

### Building Arrays Efficiently

```cairo
// GOOD: Single-pass forward construction
fn build_prefix_max(height: @Array<u32>) -> Array<u32> {
    let mut prefix_max: Array<u32> = array![];
    let mut current_max: u32 = 0;
    let mut i: u32 = 0;
    while i < height.len() {
        current_max = max(current_max, *height.at(i));
        prefix_max.append(current_max);
        i += 1;
    };
    prefix_max
}

// GOOD: Reverse iteration with forward construction
fn build_suffix_max(height: @Array<u32>) -> Array<u32> {
    let n = height.len();
    // First pass: compute values in reverse order
    let mut reversed: Array<u32> = array![];
    let mut current_max: u32 = 0;
    let mut i = n;
    while i > 0 {
        i -= 1;
        current_max = max(current_max, *height.at(i));
        reversed.append(current_max);
    };
    // Second pass: reverse to correct order
    let mut result: Array<u32> = array![];
    let mut j = n;
    while j > 0 {
        j -= 1;
        result.append(*reversed.at(j));
    };
    result
}
```

### When Mutation is Needed

Use `Felt252Dict` for O(1) random access updates:

```cairo
use core::dict::Felt252Dict;

fn solution_with_updates() {
    let mut cache: Felt252Dict<u32> = Default::default();
    
    // O(1) insert/update
    cache.insert(key.into(), value);
    
    // O(1) lookup
    let val = cache.get(key.into());
}
```

---

## 4. Naming Conventions

### Functions
- Use snake_case
- Format: `{action}_{variant}` for algorithm variants
- Be consistent across related functions

```cairo
// BAD: Inconsistent naming
fn trap(...)           // Missing variant suffix
fn trap_brute_force(...)
fn trapDP(...)         // Wrong case

// GOOD: Consistent naming
fn trap_two_pointers(...)
fn trap_brute_force(...)
fn trap_dynamic_programming(...)
```

### Variables
- Descriptive names over single letters (except loop indices)
- Avoid reusing variables for different purposes

```cairo
// BAD: Variable reuse obscures intent
let mut i: u32 = 0;
while i < n { /* loop 1 */ i += 1; };
i = 0;  // Reused!
while i < n { /* loop 2 */ i += 1; };
i = n - 1;  // Reused again!
while i > 0 { /* loop 3 */ i -= 1; };

// GOOD: Separate variables with clear scope
let mut build_idx: u32 = 0;
while build_idx < n { /* build loop */ build_idx += 1; };

let mut fill_idx: u32 = 0;
while fill_idx < n { /* fill loop */ fill_idx += 1; };

let mut scan_idx = n - 1;
while scan_idx > 0 { /* scan loop */ scan_idx -= 1; };
```

---

## 5. Cyclomatic Complexity

### Keep Functions Focused
- Maximum ~20 lines per function
- Single responsibility per function
- Extract nested loops into helper functions

```cairo
// BAD: High complexity, nested loops, multiple responsibilities
pub fn trap_dp(height: @Array<u32>) -> u32 {
    // 80+ lines with nested loops and array rebuilding
}

// GOOD: Decomposed into focused helpers
pub fn trap_dp(height: @Array<u32>) -> u32 {
    if height.len() <= 2 { return 0; }
    
    let left_max = build_prefix_max(height);
    let right_max = build_suffix_max(height);
    
    calculate_trapped_water(height, @left_max, @right_max)
}

fn build_prefix_max(height: @Array<u32>) -> Array<u32> { /* focused */ }
fn build_suffix_max(height: @Array<u32>) -> Array<u32> { /* focused */ }
fn calculate_trapped_water(...) -> u32 { /* focused */ }
```

---

## 6. API Design

### Single Optimal Entry Point
The main `solve` method should use the optimal algorithm:

```cairo
// BAD: Confusing - which solve is optimal?
impl SolutionImpl of SolutionTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap_brute_force(input)  // Why brute force?
    }
}

impl RainWaterImpl of RainWaterTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap_two_pointers(input)  // Different algorithm!
    }
}

// GOOD: Clear, consistent, documented
/// Primary solution trait - uses optimal algorithm
pub trait SolutionTrait {
    /// Solves the problem using the optimal O(n) time, O(1) space algorithm.
    fn solve(input: @Array<u32>) -> u32;
}

pub impl SolutionImpl of SolutionTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap_two_pointers(input)  // Explicitly optimal
    }
}
```

### Expose Variants Separately
If multiple algorithms are required, expose them clearly:

```cairo
pub trait RainWaterTrait {
    /// O(n) time, O(1) space - RECOMMENDED
    fn solve_optimal(input: @Array<u32>) -> u32;
    
    /// O(n) time, O(n) space - for comparison
    fn solve_dp(input: @Array<u32>) -> u32;
    
    /// O(n²) time, O(1) space - educational only
    fn solve_brute_force(input: @Array<u32>) -> u32;
}
```

---

## 7. Test Quality

### Avoid Duplication
```cairo
// BAD: Same test case repeated 3 times
#[test] fn test_bf_empty() { assert!(brute_force(@array![]) == 0); }
#[test] fn test_dp_empty() { assert!(dp(@array![]) == 0); }
#[test] fn test_opt_empty() { assert!(optimal(@array![]) == 0); }

// GOOD: Single test verifying all implementations agree
#[test]
fn test_empty_array_all_implementations() {
    let input = array![];
    let expected = 0;
    assert!(trap_brute_force(@input) == expected);
    assert!(trap_dp(@input) == expected);
    assert!(trap_two_pointers(@input) == expected);
}
```

### Test Organization
```cairo
#[cfg(test)]
mod tests {
    use super::*;
    
    // Group 1: Edge cases
    mod edge_cases {
        use super::*;
        
        #[test] fn test_empty() { /* ... */ }
        #[test] fn test_single_element() { /* ... */ }
        #[test] fn test_two_elements() { /* ... */ }
    }
    
    // Group 2: No water scenarios
    mod no_water {
        use super::*;
        
        #[test] fn test_ascending() { /* ... */ }
        #[test] fn test_descending() { /* ... */ }
        #[test] fn test_flat() { /* ... */ }
    }
    
    // Group 3: Water trapping scenarios
    mod water_scenarios {
        use super::*;
        
        #[test] fn test_simple_valley() { /* ... */ }
        #[test] fn test_multiple_valleys() { /* ... */ }
        #[test] fn test_example_1() { /* ... */ }
        #[test] fn test_example_2() { /* ... */ }
    }
    
    // Group 4: Implementation equivalence
    mod equivalence {
        use super::*;
        
        #[test]
        fn test_all_implementations_match() {
            let test_cases = array![
                array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1],
                array![4, 2, 0, 3, 2, 5],
                array![5, 0, 5],
            ];
            // Verify all produce same results
        }
    }
}
```

### Required Test Categories
1. **Edge cases**: Empty, single element, minimum valid input
2. **Boundary conditions**: Values at limits (0, max u32)
3. **Expected behavior**: Known inputs with known outputs
4. **Equivalence**: All algorithm variants produce same results
5. **Error conditions**: Invalid inputs (if applicable)

---

## 8. Pre-Submission Checklist

**STOP. Before submitting, verify ALL of these:**

### Import Hygiene (CHECK FIRST!)
- [ ] **CRITICAL**: Review EVERY `use` statement - is it actually used?
- [ ] If `use core::cmp::{max, min}` exists, code MUST call `max()` and `min()` (not `max_u32()`)
- [ ] If using custom helpers like `max_u32()`, REMOVE the `use core::cmp` line
- [ ] Run mental linter: any import not used = DELETE IT

### Code Quality
- [ ] No `len() == 0` (use `.is_empty()` if available)
- [ ] No array rebuilding in loops (O(n²) trap)
- [ ] All public functions have doc comments
- [ ] Time/space complexity documented
- [ ] `solve()` uses optimal algorithm
- [ ] Consistent naming across variants
- [ ] No variable reuse for different purposes

### Test Quality
- [ ] Tests verify all implementations match
- [ ] No duplicated test cases
- [ ] Edge cases covered (empty, single element)

---

## Summary

| Aspect | Requirement |
|--------|-------------|
| Documentation | Doc comments with O() complexity on all public functions |
| DRY | Extract helpers, use generics, no duplicated tests |
| Arrays | Never rebuild in loops; use single-pass construction |
| Naming | Consistent `action_variant` pattern |
| Complexity | Max ~20 lines/function; decompose nested loops |
| API | Single `solve()` uses optimal; variants clearly named |
| Tests | Grouped by behavior; equivalence tests required |
