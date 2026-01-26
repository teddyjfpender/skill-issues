# Prompt ID: cairo-matrix-algebra-01

Task:
- Implement a generic matrix library in Cairo with core linear algebra operations.

## Related Skills
- `cairo-generics-traits`: Generic structs, trait bounds, implementations
- `cairo-operator-overloading`: Add, Sub, Mul trait implementations
- `cairo-arrays`: Array operations, spans, indexing patterns
- `cairo-testing`: Comprehensive test coverage

## Overview

Implement a 2D matrix type that supports basic linear algebra operations. The matrix should be generic over the element type and support common operations like addition, multiplication, transpose, and determinant calculation (for small matrices).

## Type Definitions

### Core Structures

```cairo
#[derive(Drop, Clone, Debug)]
pub struct Matrix<T> {
    pub data: Array<T>,      // Row-major storage
    pub rows: u32,
    pub cols: u32,
}

#[derive(Drop, Clone, Debug)]
pub struct Vector<T> {
    pub data: Array<T>,
}
```

### Critical Invariants

1. `data.len() == rows * cols` - Matrix storage matches dimensions
2. `rows > 0 && cols > 0` for non-empty matrices (or both zero for empty)
3. Row-major ordering: element at (i, j) is at index `i * cols + j`

## Required Operations

### Construction

- `Matrix::new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>>`
  - Returns None if data.len() != rows * cols

- `Matrix::zeros(rows: u32, cols: u32) -> Matrix<T>` where T: Zero + Copy + Drop
  - Create matrix filled with zeros

- `Matrix::identity(n: u32) -> Matrix<T>` where T: Zero + One + Copy + Drop
  - Create n×n identity matrix

- `Vector::new(data: Array<T>) -> Vector<T>`
  - Create vector from array

### Element Access

- `get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T>`
  - Returns None if out of bounds

- `get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> @T`
  - Panics if out of bounds (for internal use)

### Matrix Operations

- `transpose(self: @Matrix<T>) -> Matrix<T>` where T: Copy + Drop
  - Returns transposed matrix (rows ↔ cols)

- `add(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>` where T: Add + Copy + Drop
  - Element-wise addition, None if dimensions mismatch

- `sub(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>` where T: Sub + Copy + Drop
  - Element-wise subtraction, None if dimensions mismatch

- `mul(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>` where T: Add + Mul + Zero + Copy + Drop
  - Matrix multiplication (self.cols must equal other.rows)
  - Result is self.rows × other.cols

- `scalar_mul(self: @Matrix<T>, scalar: T) -> Matrix<T>` where T: Mul + Copy + Drop
  - Multiply every element by scalar

### Vector Operations

- `dot(self: @Vector<T>, other: @Vector<T>) -> Option<T>` where T: Add + Mul + Zero + Copy + Drop
  - Dot product, None if lengths differ

- `matrix_vector_mul(m: @Matrix<T>, v: @Vector<T>) -> Option<Vector<T>>`
  - Matrix-vector multiplication (m.cols must equal v.len())

### Determinant (2x2 and 3x3 only)

- `det_2x2(self: @Matrix<T>) -> Option<T>` where T: Mul + Sub + Copy + Drop
  - Returns None if not 2×2
  - Formula: `a*d - b*c`

- `det_3x3(self: @Matrix<T>) -> Option<T>` where T: Mul + Sub + Add + Copy + Drop
  - Returns None if not 3×3
  - Use rule of Sarrus or cofactor expansion

### Utility

- `rows(self: @Matrix<T>) -> u32`
- `cols(self: @Matrix<T>) -> u32`
- `is_square(self: @Matrix<T>) -> bool`
- `len(self: @Vector<T>) -> u32`

## Standard Trait Implementations

Implement for `Matrix<T>`:
- `PartialEq` - element-wise comparison (dimensions must match)
- `Add` - panic wrapper around checked add
- `Mul` - panic wrapper around checked matrix multiply

Implement for `Vector<T>`:
- `PartialEq` - element-wise comparison

## Cairo-Specific Implementation Notes

**CRITICAL - No Inherent Impls**: Cairo does NOT support Rust-style `impl Type { }`. All methods must use traits:

```cairo
// WRONG - will not compile
impl Matrix<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Matrix<T> { ... }
}

// CORRECT - define trait + impl of trait
trait MatrixTrait<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>>;
    fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T>;
    // ... other methods
}

impl MatrixImpl<T, +Drop<T>, +Copy<T>> of MatrixTrait<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>> { ... }
    fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> { ... }
}
```

**Calling constructors**: Call via trait name, not type:
```cairo
let m = MatrixTrait::new(3, 3, data);  // CORRECT
// let m = Matrix::new(3, 3, data);    // WRONG - won't compile
```

Other notes:
- **Array indexing**: Use `.span().get(i)` for bounds-checked access
- **Building results**: Create new Array and use `.append()` in loops
- **Trait bounds**: Generic impls need explicit bounds like `+Drop<T>, +Copy<T>`
- **Snapshots**: Matrix method parameters should typically be `@Matrix<T>` (snapshots)
- **No in-place mutation**: Always return new matrices

## Required Tests

### Construction
- `Matrix::new` validates dimensions correctly
- `Matrix::zeros` creates correct zero matrix
- `Matrix::identity` creates correct identity matrix
- Reject invalid dimensions (data.len() != rows * cols)

### Element Access
- `get` returns correct elements
- `get` returns None for out-of-bounds
- Row-major indexing is correct

### Transpose
- `[[1,2,3],[4,5,6]]` transposed is `[[1,4],[2,5],[3,6]]`
- Transpose of transpose equals original
- 1×n transpose is n×1

### Addition/Subtraction
- Identity: `A + zeros == A`
- Commutativity: `A + B == B + A`
- Dimension mismatch returns None

### Multiplication
- `A * identity == A`
- `identity * A == A`
- `(A * B) != (B * A)` in general (non-commutative)
- Dimension validation: (2×3) * (3×4) = (2×4), (2×3) * (2×3) = None

### Scalar Multiplication
- `A * 0 == zeros`
- `A * 1 == A`
- `A * 2` doubles all elements

### Determinant
- `det([[1,2],[3,4]]) == -2`
- `det(identity_2x2) == 1`
- `det(identity_3x3) == 1`
- Non-square returns None

### Vector Operations
- Dot product of `[1,2,3]` and `[4,5,6]` equals `32`
- Matrix-vector multiply with identity returns same vector
- Dimension mismatches return None

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use generics throughout (no hardcoded i32/u32 matrices)
- Handle edge cases (empty matrices, dimension mismatches)

## Deliverable

- Only the code for `src/lib.cairo`
