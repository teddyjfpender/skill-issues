# Rubric for cairo-matrix-algebra-01

## Pass Criteria

### Compilation (Required)
- [ ] Code compiles with `scarb build` without errors
- [ ] Code passes `scarb fmt` without changes

### Type Definitions (Required)
- [ ] `Matrix<T>` struct exists with `data: Array<T>`, `rows: u32`, `cols: u32`
- [ ] `Vector<T>` struct exists with `data: Array<T>`
- [ ] Both structs derive `Drop` (at minimum)
- [ ] Structs are generic over element type `T`

### Construction Functions (Required)
- [ ] `Matrix::new` returns `Option<Matrix<T>>` and validates dimensions
- [ ] `Matrix::zeros` creates zero-filled matrix
- [ ] `Matrix::identity` creates identity matrix
- [ ] `Vector::new` creates vector from array

### Element Access (Required)
- [ ] `get(row, col)` returns `Option<@T>` with bounds checking
- [ ] Row-major indexing formula `i * cols + j` is correctly implemented

### Core Operations (Required - at least 4 of 6)
- [ ] `transpose` correctly swaps rows and columns
- [ ] `add` performs element-wise addition with dimension check
- [ ] `sub` performs element-wise subtraction with dimension check
- [ ] `mul` performs matrix multiplication with dimension validation
- [ ] `scalar_mul` multiplies all elements by scalar
- [ ] `dot` computes vector dot product

### Determinant (Required - at least one)
- [ ] `det_2x2` correctly computes 2×2 determinant (ad - bc)
- [ ] `det_3x3` correctly computes 3×3 determinant

### Tests (Required)
- [ ] Tests exist and run with `snforge test`
- [ ] At least 5 test functions covering different operations
- [ ] Tests cover at least one edge case (empty, dimension mismatch, etc.)

### Trait Implementations (Bonus)
- [ ] `PartialEq` implemented for `Matrix<T>`
- [ ] `Add` trait implemented for `Matrix<T>`
- [ ] `Mul` trait implemented for `Matrix<T>`

## Fail Criteria

Fail if ANY of these are true:
- Code does not compile with `scarb build`
- `Matrix` or `Vector` structs are missing or not generic
- No element access function exists
- Matrix multiplication is missing or has incorrect dimension logic
- Fewer than 3 core operations are implemented
- No tests exist
- Tests fail

## Scoring Guide

| Score | Description |
|-------|-------------|
| 100% | All required + all bonus traits |
| 90% | All required criteria met |
| 80% | Compiles, 5+ operations, tests pass |
| 70% | Compiles, 4 operations, some tests |
| 60% | Compiles, basic operations only |
| 0% | Does not compile or missing core types |
