# Prompt ID: cairo-matrix-algebra-01

Task:
- Implement a generic matrix library in Cairo with core linear algebra operations.

## Related Skills
- `cairo-generics-traits`: Generic structs, trait bounds, implementations
- `cairo-operator-overloading`: Add, Sub, Mul trait implementations
- `cairo-arrays`: Array operations, spans, indexing patterns
- `cairo-testing`: Comprehensive test coverage
- `cairo-quirks`: Cairo-specific gotchas (snapshots, no inherent impls)

## Cairo-Specific Implementation Notes

**CRITICAL - No Inherent Impls**: Cairo does NOT support Rust-style `impl Type { }`. All methods must use traits:

```cairo
// WRONG - will not compile
impl Matrix<T> {
    fn new(...) -> Matrix<T> { ... }
}

// CORRECT - define trait + impl of trait
trait MatrixTrait<T> {
    fn new(...) -> Option<Matrix<T>>;
}

impl MatrixImpl<T, +Drop<T>, +Copy<T>> of MatrixTrait<T> {
    fn new(...) -> Option<Matrix<T>> { ... }
}
```

**Snapshot Field Access**: When `self: @Matrix<T>`, fields become snapshots. Use `*self.rows` not `self.rows`:
```cairo
fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> {
    if row >= *self.rows { return None; }  // Dereference with *
    let idx = row * *self.cols + col;       // Dereference with *
    Some(self.data[to_usize(idx)])
}
```

---

## Step 1: Imports and Core Structs

Create the foundation with imports and struct definitions.

**Requirements:**
- Add necessary imports: `use core::array::{Array, ArrayTrait};` and `use core::num::traits::{Zero, One};`
- Note: `Add`, `Mul`, `Sub`, `Drop`, `Copy` are in Cairo's prelude - do NOT import them
- Define `Matrix<T>` struct with `data: Array<T>`, `rows: u32`, `cols: u32`
- Define `Vector<T>` struct with `data: Array<T>`
- Add `#[derive(Drop, Clone, Debug)]` to both structs
- Add helper function `to_usize(value: u32) -> usize` for index conversion
- Add helper function `index(row: u32, col: u32, cols: u32) -> usize` for row-major indexing

**Validation:** Code compiles with `scarb build`

---

## Step 2: MatrixTrait Definition

Define the trait with all method signatures (no implementation yet).

**Requirements:**
- Define `MatrixTrait<T>` with signatures:
  - `fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>>`
  - `fn zeros(rows: u32, cols: u32) -> Matrix<T>`
  - `fn identity(n: u32) -> Matrix<T>`
  - `fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T>`
  - `fn get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> @T`
  - `fn transpose(self: @Matrix<T>) -> Matrix<T>`
  - `fn add(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>`
  - `fn sub(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>`
  - `fn mul(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>`
  - `fn scalar_mul(self: @Matrix<T>, scalar: T) -> Matrix<T>`
  - `fn det_2x2(self: @Matrix<T>) -> Option<T>`
  - `fn det_3x3(self: @Matrix<T>) -> Option<T>`
  - `fn rows(self: @Matrix<T>) -> u32`
  - `fn cols(self: @Matrix<T>) -> u32`
  - `fn is_square(self: @Matrix<T>) -> bool`

**Validation:** Code compiles with `scarb build`

---

## Step 3: Basic Matrix Implementation

Implement construction and accessor methods.

**Requirements:**
- Create `impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T>`
- Implement `new`: validate `data.len() == rows * cols`, return `Option`
- Implement `zeros`: create matrix filled with `Zero::zero()`
- Implement `identity`: create n×n matrix with `One::one()` on diagonal
- Implement `get`: bounds-check, return `Option<@T>`
- Implement `get_unchecked`: direct array access
- Implement `rows`, `cols`, `is_square`: simple accessors using `*self.rows`, `*self.cols`

**Validation:** Code compiles with `scarb build`

---

## Step 4: Matrix Transpose

Implement transpose operation.

**Requirements:**
- Implement `transpose`: swap rows and columns
- Build new data array by iterating columns then rows
- Use `*self.data[index(r, c, cols)]` to access and copy elements
- Return new Matrix with swapped dimensions

**Validation:** Code compiles with `scarb build`

---

## Step 5: Matrix Arithmetic Operations

Implement add, sub, mul, scalar_mul.

**Requirements:**
- Implement `add`: element-wise addition, return None if dimensions mismatch
- Implement `sub`: element-wise subtraction, return None if dimensions mismatch
- Implement `mul`: matrix multiplication (self.cols must == other.rows)
  - Result dimensions: self.rows × other.cols
  - Sum of products for each cell
- Implement `scalar_mul`: multiply each element by scalar

**Validation:** Code compiles with `scarb build`

---

## Step 6: Determinant Functions

Implement 2x2 and 3x3 determinant.

**Requirements:**
- Implement `det_2x2`: return None if not 2×2, formula: `a*d - b*c`
- Implement `det_3x3`: return None if not 3×3, use rule of Sarrus

**Validation:** Code compiles with `scarb build`

---

## Step 7: VectorTrait and Implementation

Define and implement Vector operations.

**Requirements:**
- Define `VectorTrait<T>` with:
  - `fn new(data: Array<T>) -> Vector<T>`
  - `fn len(self: @Vector<T>) -> u32`
  - `fn dot(self: @Vector<T>, other: @Vector<T>) -> Option<T>`
- Implement `VectorImpl` with all methods
- Implement standalone `matrix_vector_mul` function

**Validation:** Code compiles with `scarb build`

---

## Step 8: PartialEq Implementations

Implement equality comparison for Matrix and Vector.

**Requirements:**
- Implement `PartialEq<Matrix<T>>`: compare dimensions, then element-wise
- Implement `PartialEq<Vector<T>>`: compare lengths, then element-wise
- Use snapshot parameters: `fn eq(lhs: @Matrix<T>, rhs: @Matrix<T>) -> bool`

**Validation:** Code compiles with `scarb build`

---

## Step 9: Operator Trait Implementations

Implement Add and Mul operators for Matrix.

**Requirements:**
- Implement `Add<Matrix<T>>`: wrapper around `MatrixTrait::add` that unwraps
- Implement `Mul<Matrix<T>>`: wrapper around `MatrixTrait::mul` that unwraps

**Validation:** Code compiles with `scarb build`

---

## Step 10: Test Module Setup

Create test module with helper functions.

**Requirements:**
- Add `#[cfg(test)] mod tests { ... }`
- Import necessary items: `Array, ArrayTrait, OptionTrait`
- Import from super: `Matrix, MatrixTrait, Vector, VectorTrait, matrix_vector_mul`
- Create helper: `make_matrix(rows, cols, data) -> Matrix<i32>`
- Create helper: `make_vector(data) -> Vector<i32>`
- Create helpers for common test data arrays

**Validation:** Code compiles with `scarb build`

---

## Step 11: Construction Tests

Test Matrix construction and accessors.

**Requirements:**
- Test `new` with valid dimensions
- Test `new` rejects invalid dimensions
- Test `zeros` creates correct matrix
- Test `identity` creates correct identity
- Test `get` returns correct elements
- Test `get` returns None for out-of-bounds
- Test row-major indexing is correct

**Validation:** All tests pass with `snforge test`

---

## Step 12: Operation Tests

Test all matrix and vector operations.

**Requirements:**
- Test `transpose`: verify correct transformation, transpose twice = original
- Test `add/sub`: identity properties, commutativity, dimension mismatch → None
- Test `mul`: identity properties, non-commutativity, dimension validation
- Test `scalar_mul`: multiply by 0, 1, 2
- Test `det_2x2` and `det_3x3`: known values, identity = 1, non-square → None
- Test `Vector::dot`: known result (1·4 + 2·5 + 3·6 = 32)
- Test `matrix_vector_mul`: identity preserves vector, dimension mismatch → None

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use generics throughout (no hardcoded i32/u32 matrices)
- Handle edge cases (empty matrices, dimension mismatches)

## Deliverable

Complete `src/lib.cairo` with all steps implemented.
