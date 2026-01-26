// Cairo Matrix Algebra Library - Step 1: Foundation
use core::array::{Array, ArrayTrait};
use core::num::traits::{Zero, One};

#[derive(Drop, Clone, Debug)]
pub struct Matrix<T> {
    pub data: Array<T>,
    pub rows: u32,
    pub cols: u32,
}

#[derive(Drop, Clone, Debug)]
pub struct Vector<T> {
    pub data: Array<T>,
}

pub fn to_usize(value: u32) -> usize {
    value.into()
}

pub fn index(row: u32, col: u32, cols: u32) -> usize {
    to_usize(row * cols + col)
}

// Step 2: Trait Definition
pub trait MatrixTrait<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>>;
    fn zeros(rows: u32, cols: u32) -> Matrix<T>;
    fn identity(n: u32) -> Matrix<T>;
    fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T>;
    fn get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> @T;
    fn transpose(self: @Matrix<T>) -> Matrix<T>;
    fn add(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>;
    fn sub(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>;
    fn mul(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>>;
    fn scalar_mul(self: @Matrix<T>, scalar: T) -> Matrix<T>;
    fn det_2x2(self: @Matrix<T>) -> Option<T>;
    fn det_3x3(self: @Matrix<T>) -> Option<T>;
    fn rows(self: @Matrix<T>) -> u32;
    fn cols(self: @Matrix<T>) -> u32;
    fn is_square(self: @Matrix<T>) -> bool;
}

// Step 7: Vector Trait Definition
pub trait VectorTrait<T> {
    fn new(data: Array<T>) -> Vector<T>;
    fn len(self: @Vector<T>) -> u32;
    fn dot(self: @Vector<T>, other: @Vector<T>) -> Option<T>;
}

// Step 3: Construction and Accessor Implementation
impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>> {
        let expected_len = to_usize(rows * cols);
        if data.len() == expected_len {
            Option::Some(Matrix { data, rows, cols })
        } else {
            Option::None
        }
    }

    fn zeros(rows: u32, cols: u32) -> Matrix<T> {
        let mut data = ArrayTrait::new();
        let total_elements = rows * cols;
        let mut i = 0_u32;
        while i < total_elements {
            data.append(Zero::zero());
            i += 1;
        };
        Matrix { data, rows, cols }
    }

    fn identity(n: u32) -> Matrix<T> {
        let mut data = ArrayTrait::new();
        let total_elements = n * n;
        let mut i = 0_u32;
        while i < total_elements {
            let row = i / n;
            let col = i % n;
            if row == col {
                data.append(One::one());
            } else {
                data.append(Zero::zero());
            }
            i += 1;
        };
        Matrix { data, rows: n, cols: n }
    }

    fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> {
        if row >= *self.rows || col >= *self.cols {
            Option::None
        } else {
            let idx = index(row, col, *self.cols);
            Option::Some(self.data.at(idx))
        }
    }

    fn get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> @T {
        let idx = index(row, col, *self.cols);
        self.data.at(idx)
    }

    fn rows(self: @Matrix<T>) -> u32 {
        *self.rows
    }

    fn cols(self: @Matrix<T>) -> u32 {
        *self.cols
    }

    fn is_square(self: @Matrix<T>) -> bool {
        *self.rows == *self.cols
    }

    fn transpose(self: @Matrix<T>) -> Matrix<T> {
        let mut data = ArrayTrait::new();
        let rows = *self.rows;
        let cols = *self.cols;
        
        // Iterate columns then rows to build transposed matrix
        let mut col = 0_u32;
        while col < cols {
            let mut row = 0_u32;
            while row < rows {
                let idx = index(row, col, cols);
                data.append(*self.data.at(idx));
                row += 1;
            };
            col += 1;
        };
        
        Matrix { data, rows: cols, cols: rows }
    }

    fn add(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        // Check dimensions match
        if *self.rows != *other.rows || *self.cols != *other.cols {
            return Option::None;
        }
        
        let mut data = ArrayTrait::new();
        let total_elements = *self.rows * *self.cols;
        let mut i = 0_u32;
        
        while i < total_elements {
            let idx = to_usize(i);
            let sum = *self.data.at(idx) + *other.data.at(idx);
            data.append(sum);
            i += 1;
        };
        
        Option::Some(Matrix { data, rows: *self.rows, cols: *self.cols })
    }

    fn sub(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        // Check dimensions match
        if *self.rows != *other.rows || *self.cols != *other.cols {
            return Option::None;
        }
        
        let mut data = ArrayTrait::new();
        let total_elements = *self.rows * *self.cols;
        let mut i = 0_u32;
        
        while i < total_elements {
            let idx = to_usize(i);
            let diff = *self.data.at(idx) - *other.data.at(idx);
            data.append(diff);
            i += 1;
        };
        
        Option::Some(Matrix { data, rows: *self.rows, cols: *self.cols })
    }

    fn mul(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        // Check dimensions are compatible for multiplication
        if *self.cols != *other.rows {
            return Option::None;
        }
        
        let mut data = ArrayTrait::new();
        let result_rows = *self.rows;
        let result_cols = *other.cols;
        let inner_dim = *self.cols;
        
        let mut row = 0_u32;
        while row < result_rows {
            let mut col = 0_u32;
            while col < result_cols {
                // Compute dot product for result[row][col]
                let mut sum = Zero::zero();
                let mut k = 0_u32;
                while k < inner_dim {
                    let self_val = *self.get_unchecked(row, k);
                    let other_val = *other.get_unchecked(k, col);
                    sum = sum + self_val * other_val;
                    k += 1;
                };
                data.append(sum);
                col += 1;
            };
            row += 1;
        };
        
        Option::Some(Matrix { data, rows: result_rows, cols: result_cols })
    }

    fn scalar_mul(self: @Matrix<T>, scalar: T) -> Matrix<T> {
        let mut data = ArrayTrait::new();
        let total_elements = *self.rows * *self.cols;
        let mut i = 0_u32;
        
        while i < total_elements {
            let idx = to_usize(i);
            let product = *self.data.at(idx) * scalar;
            data.append(product);
            i += 1;
        };
        
        Matrix { data, rows: *self.rows, cols: *self.cols }
    }

    fn det_2x2(self: @Matrix<T>) -> Option<T> {
        // Check if matrix is 2x2
        if *self.rows != 2_u32 || *self.cols != 2_u32 {
            return Option::None;
        }
        
        // For 2x2 matrix [[a, b], [c, d]], determinant is ad - bc
        let a = *self.get_unchecked(0_u32, 0_u32);
        let b = *self.get_unchecked(0_u32, 1_u32);
        let c = *self.get_unchecked(1_u32, 0_u32);
        let d = *self.get_unchecked(1_u32, 1_u32);
        
        Option::Some(a * d - b * c)
    }

    fn det_3x3(self: @Matrix<T>) -> Option<T> {
        // Check if matrix is 3x3
        if *self.rows != 3_u32 || *self.cols != 3_u32 {
            return Option::None;
        }
        
        // For 3x3 matrix, use rule of Sarrus
        // [[a, b, c], [d, e, f], [g, h, i]]
        // det = aei + bfg + cdh - ceg - afh - bdi
        let a = *self.get_unchecked(0_u32, 0_u32);
        let b = *self.get_unchecked(0_u32, 1_u32);
        let c = *self.get_unchecked(0_u32, 2_u32);
        let d = *self.get_unchecked(1_u32, 0_u32);
        let e = *self.get_unchecked(1_u32, 1_u32);
        let f = *self.get_unchecked(1_u32, 2_u32);
        let g = *self.get_unchecked(2_u32, 0_u32);
        let h = *self.get_unchecked(2_u32, 1_u32);
        let i = *self.get_unchecked(2_u32, 2_u32);
        
        let positive = a * e * i + b * f * g + c * d * h;
        let negative = c * e * g + a * f * h + b * d * i;
        
        Option::Some(positive - negative)
    }
}

// Step 7: Vector Implementation
impl VectorImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>> of VectorTrait<T> {
    fn new(data: Array<T>) -> Vector<T> {
        Vector { data }
    }

    fn len(self: @Vector<T>) -> u32 {
        self.data.len()
    }

    fn dot(self: @Vector<T>, other: @Vector<T>) -> Option<T> {
        // Check if vectors have same length
        if self.data.len() != other.data.len() {
            return Option::None;
        }
        
        let mut sum = Zero::zero();
        let len = self.data.len();
        let mut i = 0_u32;
        
        while i < len {
            let idx = to_usize(i);
            let product = *self.data.at(idx) * *other.data.at(idx);
            sum = sum + product;
            i += 1;
        };
        
        Option::Some(sum)
    }
}

// Step 8: PartialEq Implementation for Matrix
impl MatrixPartialEq<T, +Drop<T>, +Copy<T>, +PartialEq<T>> of PartialEq<Matrix<T>> {
    fn eq(lhs: @Matrix<T>, rhs: @Matrix<T>) -> bool {
        // First check dimensions
        if *lhs.rows != *rhs.rows || *lhs.cols != *rhs.cols {
            return false;
        }
        
        // Check element-wise equality
        let total_elements = *lhs.rows * *lhs.cols;
        let mut i = 0_u32;
        
        while i < total_elements {
            let idx = to_usize(i);
            if *lhs.data.at(idx) != *rhs.data.at(idx) {
                return false;
            }
            i += 1;
        };
        
        true
    }
}

// Step 8: PartialEq Implementation for Vector
impl VectorPartialEq<T, +Drop<T>, +Copy<T>, +PartialEq<T>> of PartialEq<Vector<T>> {
    fn eq(lhs: @Vector<T>, rhs: @Vector<T>) -> bool {
        // First check lengths
        if lhs.data.len() != rhs.data.len() {
            return false;
        }
        
        // Check element-wise equality
        let len = lhs.data.len();
        let mut i = 0_u32;
        
        while i < len {
            let idx = to_usize(i);
            if *lhs.data.at(idx) != *rhs.data.at(idx) {
                return false;
            }
            i += 1;
        };
        
        true
    }
}

// Step 7: Matrix-Vector Multiplication Function
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    // Check dimensions are compatible (matrix cols == vector length)
    if *matrix.cols != vector.data.len() {
        return Option::None;
    }
    
    let mut result_data = ArrayTrait::new();
    let rows = *matrix.rows;
    let cols = *matrix.cols;
    
    let mut row = 0_u32;
    while row < rows {
        let mut sum = Zero::zero();
        let mut col = 0_u32;
        while col < cols {
            let idx = index(row, col, cols);
            let matrix_val = *matrix.data.at(idx);
            let vector_val = *vector.data.at(to_usize(col));
            sum = sum + matrix_val * vector_val;
            col += 1;
        };
        result_data.append(sum);
        row += 1;
    };
    
    Option::Some(Vector { data: result_data })
}

// Step 9: Add and Mul Operator Implementations for Matrix
impl MatrixAdd<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of Add<Matrix<T>> {
    fn add(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        lhs.add(@rhs).unwrap()
    }
}

impl MatrixMul<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of Mul<Matrix<T>> {
    fn mul(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        lhs.mul(@rhs).unwrap()
    }
}

// Step 10: Test Module with Helper Functions
#[cfg(test)]
mod tests {
    use core::array::{Array, ArrayTrait};
    use core::option::OptionTrait;
    use super::{Matrix, MatrixTrait, Vector, VectorTrait, matrix_vector_mul};

    fn make_matrix(rows: u32, cols: u32, data: Array<i32>) -> Matrix<i32> {
        MatrixTrait::new(rows, cols, data).unwrap()
    }

    fn make_vector(data: Array<i32>) -> Vector<i32> {
        VectorTrait::new(data)
    }

    fn array_2x2() -> Array<i32> {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr
    }

    fn array_3x3() -> Array<i32> {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr.append(4);
        arr.append(5);
        arr.append(6);
        arr.append(7);
        arr.append(8);
        arr.append(9);
        arr
    }

    fn array_vector_3() -> Array<i32> {
        let mut arr = ArrayTrait::new();
        arr.append(1);
        arr.append(2);
        arr.append(3);
        arr
    }

    // Step 11: Matrix construction and accessor tests
    #[test]
    fn test_new_valid_dimensions() {
        let data = array_2x2();
        let matrix = MatrixTrait::new(2_u32, 2_u32, data);
        assert!(matrix.is_some(), "Matrix creation should succeed with valid dimensions");
    }

    #[test]
    fn test_new_invalid_dimensions() {
        let data = array_2x2(); // Has 4 elements
        let matrix = MatrixTrait::new(3_u32, 3_u32, data); // Expects 9 elements
        assert!(matrix.is_none(), "Matrix creation should fail with invalid dimensions");
    }

    #[test]
    fn test_zeros_creates_correct_matrix() {
        let matrix: Matrix<i32> = MatrixTrait::zeros(2_u32, 3_u32);
        assert!(matrix.rows() == 2_u32, "Rows should be 2");
        assert!(matrix.cols() == 3_u32, "Cols should be 3");
        
        let mut row = 0_u32;
        while row < 2_u32 {
            let mut col = 0_u32;
            while col < 3_u32 {
                let val = matrix.get(row, col).unwrap();
                assert!(*val == 0_i32, "All elements should be zero");
                col += 1;
            };
            row += 1;
        };
    }

    #[test]
    fn test_identity_creates_correct_matrix() {
        let matrix: Matrix<i32> = MatrixTrait::identity(3_u32);
        assert!(matrix.rows() == 3_u32, "Rows should be 3");
        assert!(matrix.cols() == 3_u32, "Cols should be 3");
        
        let mut row = 0_u32;
        while row < 3_u32 {
            let mut col = 0_u32;
            while col < 3_u32 {
                let val = matrix.get(row, col).unwrap();
                if row == col {
                    assert!(*val == 1_i32, "Diagonal elements should be 1");
                } else {
                    assert!(*val == 0_i32, "Off-diagonal elements should be 0");
                }
                col += 1;
            };
            row += 1;
        };
    }

    #[test]
    fn test_get_returns_correct_elements() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        
        assert!(*matrix.get(0_u32, 0_u32).unwrap() == 1_i32, "Element (0,0) should be 1");
        assert!(*matrix.get(0_u32, 1_u32).unwrap() == 2_i32, "Element (0,1) should be 2");
        assert!(*matrix.get(1_u32, 0_u32).unwrap() == 3_i32, "Element (1,0) should be 3");
        assert!(*matrix.get(1_u32, 1_u32).unwrap() == 4_i32, "Element (1,1) should be 4");
    }

    #[test]
    fn test_get_out_of_bounds() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        
        assert!(matrix.get(2_u32, 0_u32).is_none(), "Row out of bounds should return None");
        assert!(matrix.get(0_u32, 2_u32).is_none(), "Column out of bounds should return None");
        assert!(matrix.get(3_u32, 3_u32).is_none(), "Both out of bounds should return None");
    }

    #[test]
    fn test_row_major_indexing() {
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        data.append(4);
        data.append(5);
        data.append(6);
        
        let matrix = make_matrix(2_u32, 3_u32, data); // 2x3 matrix
        
        // First row: 1, 2, 3
        assert!(*matrix.get(0_u32, 0_u32).unwrap() == 1_i32, "Element (0,0) should be 1");
        assert!(*matrix.get(0_u32, 1_u32).unwrap() == 2_i32, "Element (0,1) should be 2");
        assert!(*matrix.get(0_u32, 2_u32).unwrap() == 3_i32, "Element (0,2) should be 3");
        
        // Second row: 4, 5, 6
        assert!(*matrix.get(1_u32, 0_u32).unwrap() == 4_i32, "Element (1,0) should be 4");
        assert!(*matrix.get(1_u32, 1_u32).unwrap() == 5_i32, "Element (1,1) should be 5");
        assert!(*matrix.get(1_u32, 2_u32).unwrap() == 6_i32, "Element (1,2) should be 6");
    }

    // Step 12: Test all matrix and vector operations
    #[test]
    fn test_transpose_2x3_matrix() {
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        data.append(4);
        data.append(5);
        data.append(6);
        
        let matrix = make_matrix(2_u32, 3_u32, data); // 2x3 matrix
        let transposed = matrix.transpose();
        
        assert!(transposed.rows() == 3_u32, "Transposed rows should be 3");
        assert!(transposed.cols() == 2_u32, "Transposed cols should be 2");
        
        // Verify element transformation
        assert!(*transposed.get(0_u32, 0_u32).unwrap() == 1_i32, "Transposed (0,0) should be 1");
        assert!(*transposed.get(0_u32, 1_u32).unwrap() == 4_i32, "Transposed (0,1) should be 4");
        assert!(*transposed.get(1_u32, 0_u32).unwrap() == 2_i32, "Transposed (1,0) should be 2");
        assert!(*transposed.get(1_u32, 1_u32).unwrap() == 5_i32, "Transposed (1,1) should be 5");
        assert!(*transposed.get(2_u32, 0_u32).unwrap() == 3_i32, "Transposed (2,0) should be 3");
        assert!(*transposed.get(2_u32, 1_u32).unwrap() == 6_i32, "Transposed (2,1) should be 6");
    }

    #[test]
    fn test_transpose_twice_returns_original() {
        let matrix = make_matrix(2_u32, 3_u32, array_vector_3().clone());
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        data.append(4);
        data.append(5);
        data.append(6);
        let original = make_matrix(2_u32, 3_u32, data);
        
        let double_transposed = original.transpose().transpose();
        
        assert!(original == double_transposed, "Double transpose should equal original");
    }

    #[test]
    fn test_add_commutativity() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let mut b_data = ArrayTrait::new();
        b_data.append(5);
        b_data.append(6);
        b_data.append(7);
        b_data.append(8);
        let b = make_matrix(2_u32, 2_u32, b_data);
        
        let ab = a.add(@b).unwrap();
        let ba = b.add(@a).unwrap();
        
        assert!(ab == ba, "Addition should be commutative");
    }

    #[test]
    fn test_add_identity_property() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let zero: Matrix<i32> = MatrixTrait::zeros(2_u32, 2_u32);
        
        let result = a.add(@zero).unwrap();
        
        assert!(result == a, "Adding zero matrix should return original");
    }

    #[test]
    fn test_add_dimension_mismatch() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let mut b_data = ArrayTrait::new();
        b_data.append(1);
        b_data.append(2);
        b_data.append(3);
        let b = make_matrix(1_u32, 3_u32, b_data);
        
        let result = a.add(@b);
        
        assert!(result.is_none(), "Adding matrices with different dimensions should return None");
    }

    #[test]
    fn test_sub_identity_property() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let zero: Matrix<i32> = MatrixTrait::zeros(2_u32, 2_u32);
        
        let result = a.sub(@zero).unwrap();
        
        assert!(result == a, "Subtracting zero matrix should return original");
    }

    #[test]
    fn test_sub_dimension_mismatch() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let mut b_data = ArrayTrait::new();
        b_data.append(1);
        b_data.append(2);
        b_data.append(3);
        let b = make_matrix(1_u32, 3_u32, b_data);
        
        let result = a.sub(@b);
        
        assert!(result.is_none(), "Subtracting matrices with different dimensions should return None");
    }

    #[test]
    fn test_mul_identity_property() {
        let a = make_matrix(2_u32, 2_u32, array_2x2());
        let identity: Matrix<i32> = MatrixTrait::identity(2_u32);
        
        let result = a.mul(@identity).unwrap();
        
        assert!(result == a, "Multiplying by identity should return original");
    }

    #[test]
    fn test_mul_non_commutativity() {
        let mut a_data = ArrayTrait::new();
        a_data.append(1);
        a_data.append(2);
        a_data.append(3);
        a_data.append(4);
        let a = make_matrix(2_u32, 2_u32, a_data);
        
        let mut b_data = ArrayTrait::new();
        b_data.append(5);
        b_data.append(6);
        b_data.append(7);
        b_data.append(8);
        let b = make_matrix(2_u32, 2_u32, b_data);
        
        let ab = a.mul(@b).unwrap();
        let ba = b.mul(@a).unwrap();
        
        assert!(ab != ba, "Matrix multiplication should not be commutative");
    }

    #[test]
    fn test_mul_dimension_validation() {
        let a = make_matrix(2_u32, 3_u32, array_vector_3().clone());
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        data.append(4);
        data.append(5);
        data.append(6);
        let a_full = make_matrix(2_u32, 3_u32, data);
        
        let mut b_data = ArrayTrait::new();
        b_data.append(1);
        b_data.append(2);
        let b = make_matrix(2_u32, 1_u32, b_data);
        
        let result = a_full.mul(@b);
        
        assert!(result.is_none(), "Multiplying incompatible dimensions should return None");
    }

    #[test]
    fn test_scalar_mul_by_zero() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        let result = matrix.scalar_mul(0_i32);
        let zero: Matrix<i32> = MatrixTrait::zeros(2_u32, 2_u32);
        
        assert!(result == zero, "Scalar multiplication by zero should give zero matrix");
    }

    #[test]
    fn test_scalar_mul_by_one() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        let result = matrix.scalar_mul(1_i32);
        
        assert!(result == matrix, "Scalar multiplication by one should return original");
    }

    #[test]
    fn test_scalar_mul_by_two() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        let result = matrix.scalar_mul(2_i32);
        
        assert!(*result.get(0_u32, 0_u32).unwrap() == 2_i32, "Element (0,0) should be 2");
        assert!(*result.get(0_u32, 1_u32).unwrap() == 4_i32, "Element (0,1) should be 4");
        assert!(*result.get(1_u32, 0_u32).unwrap() == 6_i32, "Element (1,0) should be 6");
        assert!(*result.get(1_u32, 1_u32).unwrap() == 8_i32, "Element (1,1) should be 8");
    }

    #[test]
    fn test_det_2x2_known_values() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        let det = matrix.det_2x2().unwrap();
        
        // For [[1, 2], [3, 4]], det = 1*4 - 2*3 = 4 - 6 = -2
        assert!(det == -2_i32, "Determinant of 2x2 matrix should be -2");
    }

    #[test]
    fn test_det_2x2_identity() {
        let identity: Matrix<i32> = MatrixTrait::identity(2_u32);
        let det = identity.det_2x2().unwrap();
        
        assert!(det == 1_i32, "Determinant of 2x2 identity should be 1");
    }

    #[test]
    fn test_det_2x2_non_square() {
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        let matrix = make_matrix(1_u32, 3_u32, data);
        
        let det = matrix.det_2x2();
        
        assert!(det.is_none(), "Determinant of non-2x2 matrix should return None");
    }

    #[test]
    fn test_det_3x3_known_values() {
        let matrix = make_matrix(3_u32, 3_u32, array_3x3());
        let det = matrix.det_3x3().unwrap();
        
        // For [[1, 2, 3], [4, 5, 6], [7, 8, 9]], det should be 0 (singular matrix)
        assert!(det == 0_i32, "Determinant of 3x3 matrix should be 0");
    }

    #[test]
    fn test_det_3x3_identity() {
        let identity: Matrix<i32> = MatrixTrait::identity(3_u32);
        let det = identity.det_3x3().unwrap();
        
        assert!(det == 1_i32, "Determinant of 3x3 identity should be 1");
    }

    #[test]
    fn test_det_3x3_non_square() {
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3);
        data.append(4);
        let matrix = make_matrix(2_u32, 2_u32, data);
        
        let det = matrix.det_3x3();
        
        assert!(det.is_none(), "Determinant of non-3x3 matrix should return None");
    }

    #[test]
    fn test_vector_dot_known_result() {
        let mut v1_data = ArrayTrait::new();
        v1_data.append(1);
        v1_data.append(2);
        v1_data.append(3);
        let v1 = make_vector(v1_data);
        
        let mut v2_data = ArrayTrait::new();
        v2_data.append(4);
        v2_data.append(5);
        v2_data.append(6);
        let v2 = make_vector(v2_data);
        
        let dot = v1.dot(@v2).unwrap();
        
        // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
        assert!(dot == 32_i32, "Dot product should be 32");
    }

    #[test]
    fn test_vector_dot_dimension_mismatch() {
        let v1 = make_vector(array_vector_3());
        let mut v2_data = ArrayTrait::new();
        v2_data.append(1);
        v2_data.append(2);
        let v2 = make_vector(v2_data);
        
        let dot = v1.dot(@v2);
        
        assert!(dot.is_none(), "Dot product with different dimensions should return None");
    }

    #[test]
    fn test_matrix_vector_mul_known_result() {
        // Test 2x3 matrix * 3x1 vector = 2x1 vector
        let mut matrix_data = ArrayTrait::new();
        matrix_data.append(1);
        matrix_data.append(2);
        matrix_data.append(3);
        matrix_data.append(4);
        matrix_data.append(5);
        matrix_data.append(6);
        let matrix = make_matrix(2_u32, 3_u32, matrix_data);
        
        let vector = make_vector(array_vector_3());
        
        let result = matrix_vector_mul(@matrix, @vector).unwrap();
        
        assert!(result.len() == 2_u32, "Result should have 2 elements");
        // First element: 1*1 + 2*2 + 3*3 = 1 + 4 + 9 = 14
        assert!(*result.data.at(0) == 14_i32, "First element should be 14");
        // Second element: 4*1 + 5*2 + 6*3 = 4 + 10 + 18 = 32
        assert!(*result.data.at(1) == 32_i32, "Second element should be 32");
    }

    #[test]
    fn test_matrix_vector_mul_identity_preserves() {
        let identity: Matrix<i32> = MatrixTrait::identity(3_u32);
        let vector = make_vector(array_vector_3());
        
        let result = matrix_vector_mul(@identity, @vector).unwrap();
        
        assert!(result == vector, "Identity matrix should preserve vector");
    }

    #[test]
    fn test_matrix_vector_mul_dimension_mismatch() {
        let matrix = make_matrix(2_u32, 2_u32, array_2x2());
        let vector = make_vector(array_vector_3()); // 3 elements, matrix has 2 cols
        
        let result = matrix_vector_mul(@matrix, @vector);
        
        assert!(result.is_none(), "Matrix-vector multiplication with mismatched dimensions should return None");
    }
}
