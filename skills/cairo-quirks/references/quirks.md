# Cairo Quirks Reference

## Operator Limitations

### No Bit Shift Operators

Cairo does not have `>>` or `<<` operators. Use division/multiplication by powers of 2:

```cairo
// WRONG - won't compile
let high = value >> 64;

// CORRECT - use division
const TWO_POW_64: u128 = 0x1_0000_0000_0000_0000_u128;
let high = value / TWO_POW_64;

// For left shift, use multiplication
let shifted = value * TWO_POW_64;
```

### Unary Negation Parsing Issues

In some contexts, unary minus doesn't parse correctly:

```cairo
// WRONG - may not parse correctly
return -u256_cmp(a.mag, b.mag);

// CORRECT - use subtraction from zero
return 0_i32 - u256_cmp(a.mag, b.mag);
```

This is especially common in return statements and when the negation would be at the start of an expression.

## Array and Collection Quirks

### No Runtime Array Indexing

Fixed-size arrays `[T; N]` cannot be indexed with a runtime variable:

```cairo
// WRONG - won't compile
let arr: [u64; 4] = [1, 2, 3, 4];
let idx: u32 = 2;
let val = arr[idx];  // Error!

// CORRECT - convert to Span first
let val = arr.span().get(idx);  // Returns Option<@T>
// or
let val = *arr.span().at(idx);  // Returns T, panics if out of bounds
```

### Span for Iteration

```cairo
// Convert fixed array to span for iteration
let values: [SQ128x128; 5] = [MIN, NEG_ONE, ZERO, ONE, MAX];
let mut i: u32 = 0;
while i < 5 {
    let val = *values.span().at(i);
    // use val...
    i += 1;
};
```

## Scope and Declaration Issues

### No `use` Inside Functions

Import statements must be at the module level:

```cairo
// WRONG - won't compile
fn my_function() {
    use core::num::traits::Zero;  // Error!
    // ...
}

// CORRECT - import at module level
use core::num::traits::Zero;

fn my_function() {
    // now Zero is available
}
```

### Reserved Keywords

`type` is reserved even in lowercase:

```cairo
// WRONG
let type = "foo";  // Error!

// CORRECT
let kind = "foo";
let ty = "foo";
```

## Trait and Method Issues

### No Inherent Impls - Traits Required

**CRITICAL**: Cairo does NOT support Rust-style inherent impls. You cannot write `impl Type { fn new() -> Self }`. All methods must be defined via traits:

```cairo
// WRONG - Cairo does NOT support this syntax
impl Matrix {
    fn new(rows: u32, cols: u32) -> Matrix {
        // ...
    }
}

// CORRECT - must use trait + impl of trait
trait MatrixTrait {
    fn new(rows: u32, cols: u32) -> Matrix;
}

impl MatrixImpl of MatrixTrait {
    fn new(rows: u32, cols: u32) -> Matrix {
        // ...
    }
}
```

**Calling constructors**: You must call via the trait, not the type:

```cairo
// WRONG - will not compile
let m = Matrix::new(3, 3);

// CORRECT - call via trait
let m = MatrixTrait::new(3, 3);
```

### Ambiguous `unwrap`

When both `Option` and `Result` are in scope, `unwrap` can be ambiguous:

```cairo
// WRONG - may be ambiguous
let val = result.unwrap();

// CORRECT - specify the trait explicitly
let val = OptionTrait::unwrap(result);
// or
let val = ResultTrait::unwrap(result);
```

### PartialEq Takes Snapshot Parameters

Cairo's `PartialEq` trait uses snapshots, not owned values:

```cairo
// WRONG
impl MyTypePartialEq of PartialEq<MyType> {
    fn eq(lhs: MyType, rhs: MyType) -> bool {  // Error!
        // ...
    }
}

// CORRECT - use snapshots (@) and dereference (*)
impl MyTypePartialEq of PartialEq<MyType> {
    fn eq(lhs: @MyType, rhs: @MyType) -> bool {
        *lhs.field == *rhs.field  // Dereference with *
    }
}
```

### Trait Methods Need Import

To call a trait method, the trait must be in scope:

```cairo
// WRONG - Zero trait not in scope
fn test() {
    let x = SQ128x128::zero();  // Error: method not found
}

// CORRECT - import the trait
use core::num::traits::Zero;

fn test() {
    let x = SQ128x128::zero();  // Works now
}
```

## Numeric Type Quirks

### No Implicit Conversions

All type conversions must be explicit:

```cairo
// WRONG
let a: u64 = 5;
let b: u128 = a;  // Error!

// CORRECT
let a: u64 = 5;
let b: u128 = a.into();  // Infallible conversion

// For potentially failing conversions
let c: u128 = 1000;
let d: u64 = c.try_into().unwrap();  // May panic
```

### Comparison Functions Return i32

For ordering comparisons, return `i32` (-1, 0, 1) not bool:

```cairo
fn u256_cmp(a: U256, b: U256) -> i32 {
    if a.limb3 < b.limb3 { return -1_i32; }
    if a.limb3 > b.limb3 { return 1_i32; }
    // ... continue for other limbs
    0_i32
}

// Usage
let result = u256_cmp(a, b);
if result < 0_i32 { /* a < b */ }
if result == 0_i32 { /* a == b */ }
if result > 0_i32 { /* a > b */ }
```

### Integer Literal Suffixes

Always use explicit suffixes to avoid ambiguity:

```cairo
let a = 5_u64;      // u64
let b = -3_i32;     // i32
let c = 0_u128;     // u128
let d = 1_felt252;  // felt252
```

### felt252 String Limits

**CRITICAL**: felt252 short strings have a **maximum of 31 characters**. This limit is commonly encountered in:
- `panic!()` messages
- `assert!()` error messages
- Error strings in `Result::Err`

```cairo
// WRONG - too long (32+ characters)
panic!("Matrix dimension mismatch error");  // Error: string too long!
assert!(valid, "Invalid matrix dimensions provided");  // Error!

// CORRECT - shortened to 31 chars or less
panic!("dim mismatch");  // 12 chars, works!
assert!(valid, "invalid dims");  // 12 chars, works!
```

**Shortening strategies:**
| Long Message | Short Version | Chars |
|--------------|---------------|-------|
| "Matrix dimension mismatch" | "dim mismatch" | 12 |
| "Index out of bounds" | "idx OOB" | 7 |
| "Division by zero" | "div by 0" | 8 |
| "Invalid input parameter" | "bad input" | 9 |
| "Overflow in multiplication" | "mul overflow" | 12 |
| "Incompatible matrix sizes" | "size mismatch" | 13 |

**Alternative: Use error codes:**
```cairo
// For complex error handling, use codes
panic!("E001");  // Document: E001 = dimension mismatch
panic!("E002");  // Document: E002 = index out of bounds
```

## Testing Quirks

### Assert Messages Must Be String Literals

```cairo
// WRONG - variable message
let msg = "test failed";
assert!(condition, msg);  // Error!

// CORRECT - literal message
assert!(condition, "test failed");

// Also correct - format with values
assert!(x == y, "Expected {} but got {}", expected, actual);
```

### Tests Need Attributes

```cairo
#[test]
fn test_addition() {
    // test code
}

#[test]
#[should_panic(expected: ("overflow",))]  // Note: tuple with trailing comma
fn test_overflow_panics() {
    // code that should panic
}

#[test]
fn test_with_loop() {
    // NOTE: #[available_gas] is deprecated in newer versions
    // For snforge 0.55+, gas tracking is automatic
    let mut i = 0_u32;
    while i < 100 {
        i += 1;
    };
}

#[test]
#[ignore]  // Skip by default, run with --include-ignored
fn slow_test() {
    // expensive test
}
```

**NOTE**: The `#[available_gas(n)]` attribute is deprecated. Do NOT use it. Tests run with automatic gas tracking in snforge 0.55+.

## Struct and Type Issues

### Derive Macros

Common derives for data types:

```cairo
#[derive(Copy, Drop, Serde, Debug)]
pub struct MyType {
    pub field: u64,
}
```

- `Copy`: Type can be copied (required for most numeric types)
- `Drop`: Type can be dropped (most types need this)
- `Serde`: Serialization/deserialization
- `Debug`: Debug formatting

### Public Fields and Functions

```cairo
// Public struct with public fields
pub struct MyType {
    pub raw: i256,  // Public field
}

// Public function
pub fn my_function() -> u64 {
    // ...
}
```

## Import and Prelude Quirks

### Traits in the Prelude (DO NOT IMPORT)

These traits are in Cairo's prelude and available automatically - do NOT import them:

```cairo
// WRONG - will cause "Identifier not found" error
use core::ops::{Add, Mul, Sub};  // Error!

// CORRECT - use directly without import
impl MyTypeAdd of Add<MyType> {
    fn add(lhs: MyType, rhs: MyType) -> MyType { ... }
}
```

**Prelude traits (do not import):**
- `Add`, `Sub`, `Mul`, `Div` - arithmetic operators
- `Neg` - unary negation
- `PartialEq`, `PartialOrd` - comparison operators
- `Drop`, `Copy`, `Clone` - memory traits
- `Into`, `TryInto` - conversion traits

**Traits that DO need import:**
```cairo
use core::num::traits::{Zero, One};  // Zero::zero(), One::one()
use core::array::{Array, ArrayTrait};  // Array operations
use core::option::OptionTrait;  // Option::unwrap(), etc.
```

### Import Cheat Sheet

Quick reference for what needs importing vs what's in the prelude:

| Need | Import? | Notes |
|------|---------|-------|
| `Add`, `Sub`, `Mul`, `Div` | **NO** | Prelude traits - use directly |
| `PartialEq`, `PartialOrd` | **NO** | Prelude traits - use directly |
| `Into`, `TryInto` | **NO** | Prelude traits - use directly |
| `Drop`, `Copy`, `Clone` | **NO** | Prelude traits - use directly |
| `Neg` | **NO** | Prelude trait - use directly |
| `Array`, `Span` | **NO** | Prelude types - use directly |
| `Option`, `Result` | **NO** | Prelude types - use directly |
| `Zero`, `One` | **YES** | `use core::num::traits::{Zero, One};` |
| `OptionTrait` | **YES** | `use core::option::OptionTrait;` |
| `ResultTrait` | **YES** | `use core::result::ResultTrait;` |
| `ArrayTrait` | **YES** | `use core::array::ArrayTrait;` |
| `SpanTrait` | **YES** | `use core::array::SpanTrait;` |

**Rule of thumb:** Basic types and operator traits are prelude. Trait methods like `.zero()`, `.unwrap()`, `.append()` need their trait imported.

### Generic Trait Bounds

When defining generic implementations, use trait bounds as implicit parameters:

```cairo
// CORRECT - trait bounds as impl parameters
impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T> {
    // ... implementation
}
```

Note: The `+TraitName<T>` syntax means "T must implement TraitName".

### Standalone Functions Using Trait Methods

**CRITICAL**: If a standalone function needs to call trait methods, it must include ALL the trait bounds required by that trait's impl. Otherwise Cairo can't resolve the method.

```cairo
// WRONG - missing bounds needed by MatrixImpl
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    // This will fail: "Method get_unchecked could not be called"
    let val = *matrix.get_unchecked(row, col);  // Error!
}

// CORRECT - include ALL bounds from MatrixImpl, or access data directly
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    let val = *matrix.get_unchecked(row, col);  // Works!
}

// ALTERNATIVE - access data directly to avoid trait method calls
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    let idx = row * *matrix.cols + col;
    let val = *matrix.data.at(to_usize(idx));  // Direct access, fewer bounds needed
}
```

### Trait Bounds Cheat Sheet for Standalone Functions

**CRITICAL**: When a standalone function (not a method with `self`) calls trait methods, it must include ALL trait bounds from the impl that defines those methods.

**The Rule:** If `MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>>` defines method `get_unchecked`, then ANY standalone function calling `get_unchecked` needs those SAME bounds.

**Complete Example:**

```cairo
// The impl defines what bounds are needed for its methods
impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T> {
    fn new(rows: u32, cols: u32) -> Matrix<T> { ... }
    fn get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> T { ... }
    fn transpose(self: @Matrix<T>) -> Matrix<T> { ... }
}

// WRONG - This standalone function is missing bounds
// Error: "Method get_unchecked could not be called on type Matrix<T>"
pub fn trace<T, +Drop<T>, +Copy<T>, +Add<T>, +Zero<T>>(matrix: @Matrix<T>) -> T {
    let mut sum = Zero::zero();
    let n = *matrix.rows;
    let mut i: u32 = 0;
    while i < n {
        sum = sum + matrix.get_unchecked(i, i);  // FAILS - missing Sub, Mul, One bounds!
        i += 1;
    };
    sum
}

// CORRECT - Include ALL bounds from MatrixImpl
pub fn trace<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>>(
    matrix: @Matrix<T>
) -> T {
    let mut sum = Zero::zero();
    let n = *matrix.rows;
    let mut i: u32 = 0;
    while i < n {
        sum = sum + matrix.get_unchecked(i, i);  // WORKS!
        i += 1;
    };
    sum
}
```

**Common mistake pattern:**
```cairo
// You might think: "My function only uses Add and Zero, why do I need Sub, Mul, One?"
// Answer: Because the METHOD you're calling is defined in an impl that requires them ALL.
// Cairo needs to resolve which impl provides the method, and that requires matching ALL bounds.
```

**Quick checklist for standalone functions:**
1. Find the impl that defines the method you want to call
2. Copy ALL its trait bounds to your function signature
3. Even if your function doesn't directly use those traits, include them anyway

## Memory and Ownership

### Snapshot Field Access (CRITICAL)

**This is one of the most common Cairo errors.** When a method takes `self: @T` (snapshot), ALL struct fields become snapshots too. You must dereference them with `*` to use them as owned values.

```cairo
#[derive(Drop)]
struct Matrix {
    rows: u32,
    cols: u32,
    data: Array<u32>,
}

// WRONG - self.rows is @u32, not u32
fn get_size(self: @Matrix) -> u32 {
    self.rows * self.cols  // Error: Expected u32, found @u32
}

// CORRECT - dereference with *
fn get_size(self: @Matrix) -> u32 {
    *self.rows * *self.cols  // Works!
}
```

**Common patterns that require dereferencing:**

```cairo
trait MatrixTrait {
    fn get(self: @Matrix, row: u32, col: u32) -> Option<u32>;
}

impl MatrixImpl of MatrixTrait {
    fn get(self: @Matrix, row: u32, col: u32) -> Option<u32> {
        // WRONG - comparing u32 with @u32
        if row >= self.rows { return None; }

        // CORRECT - dereference self.rows
        if row >= *self.rows { return None; }

        // WRONG - passing @u32 where u32 expected
        let idx = row * self.cols + col;

        // CORRECT - dereference self.cols
        let idx = row * *self.cols + col;

        // For arrays, index then dereference the element
        Some(*self.data[idx])
    }
}
```

**When to dereference:**
- Comparisons: `if row >= *self.rows`
- Arithmetic: `row * *self.cols`
- Function arguments expecting owned values
- Returning owned values from snapshot fields

**When NOT to dereference:**
- Array indexing syntax handles it: `self.data[i]` returns `@T`, then `*self.data[i]` gives `T`
- Passing to functions that expect snapshots

### Snapshots vs References

Cairo uses snapshots (`@T`) for immutable borrows:

```cairo
fn read_value(value: @MyType) -> u64 {
    *value.field  // Dereference with *
}

// For mutable access, use ref
fn modify_value(ref value: MyType) {
    value.field = 42;
}
```

### No Mutable Closures

Cairo closures are more limited than Rust:

```cairo
// Closures can capture, but mutation is limited
let x = 5;
let f = || x + 1;  // Captures x by value

// For mutation, use explicit loops/recursion instead
```
