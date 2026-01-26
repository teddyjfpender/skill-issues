use core::array::{Array, ArrayTrait};
use core::num::traits::{One, Zero};
use core::option::OptionTrait;
use core::traits::{Add, Mul, Sub};

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

fn to_usize(value: u32) -> usize {
    value.try_into().unwrap()
}

fn index(row: u32, col: u32, cols: u32) -> usize {
    let idx: u32 = row * cols + col;
    to_usize(idx)
}

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

pub trait VectorTrait<T> {
    fn new(data: Array<T>) -> Vector<T>;
    fn len(self: @Vector<T>) -> u32;
    fn dot(self: @Vector<T>, other: @Vector<T>) -> Option<T>;
}

impl MatrixImpl<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TZero: Zero<T>,
    impl TOne: One<T>,
> of MatrixTrait<T> {
    fn new(rows: u32, cols: u32, data: Array<T>) -> Option<Matrix<T>> {
        if rows == 0_u32 || cols == 0_u32 {
            if rows == 0_u32 && cols == 0_u32 && data.len() == 0 {
                return Some(Matrix { data, rows, cols });
            }
            return None;
        }
        let expected: usize = to_usize(rows * cols);
        if data.len() != expected {
            return None;
        }
        Some(Matrix { data, rows, cols })
    }

    fn zeros(rows: u32, cols: u32) -> Matrix<T> {
        let total: u32 = rows * cols;
        let mut data: Array<T> = ArrayTrait::new();
        let mut i: u32 = 0;
        while i < total {
            data.append(Zero::zero());
            i += 1;
        }
        Matrix { data, rows, cols }
    }

    fn identity(n: u32) -> Matrix<T> {
        let mut data: Array<T> = ArrayTrait::new();
        let mut r: u32 = 0;
        while r < n {
            let mut c: u32 = 0;
            while c < n {
                if r == c {
                    data.append(One::one());
                } else {
                    data.append(Zero::zero());
                }
                c += 1;
            }
            r += 1;
        }
        Matrix { data, rows: n, cols: n }
    }

    fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> {
        let rows = *self.rows;
        let cols = *self.cols;
        if row >= rows || col >= cols {
            return None;
        }
        let idx = index(row, col, cols);
        Some(self.data[idx])
    }

    fn get_unchecked(self: @Matrix<T>, row: u32, col: u32) -> @T {
        let cols = *self.cols;
        let idx = index(row, col, cols);
        self.data[idx]
    }

    fn transpose(self: @Matrix<T>) -> Matrix<T> {
        let mut data: Array<T> = ArrayTrait::new();
        let rows = *self.rows;
        let cols = *self.cols;
        let mut c: u32 = 0;
        while c < cols {
            let mut r: u32 = 0;
            while r < rows {
                let value = *self.data[index(r, c, cols)];
                data.append(value);
                r += 1;
            }
            c += 1;
        }
        Matrix { data, rows: cols, cols: rows }
    }

    fn add(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        let rows = *self.rows;
        let cols = *self.cols;
        let other_rows = *other.rows;
        let other_cols = *other.cols;
        if rows != other_rows || cols != other_cols {
            return None;
        }
        let mut data: Array<T> = ArrayTrait::new();
        let len = self.data.len();
        let mut i: usize = 0;
        while i < len {
            let value = *self.data[i] + *other.data[i];
            data.append(value);
            i += 1;
        }
        Some(Matrix { data, rows, cols })
    }

    fn sub(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        let rows = *self.rows;
        let cols = *self.cols;
        let other_rows = *other.rows;
        let other_cols = *other.cols;
        if rows != other_rows || cols != other_cols {
            return None;
        }
        let mut data: Array<T> = ArrayTrait::new();
        let len = self.data.len();
        let mut i: usize = 0;
        while i < len {
            let value = *self.data[i] - *other.data[i];
            data.append(value);
            i += 1;
        }
        Some(Matrix { data, rows, cols })
    }

    fn mul(self: @Matrix<T>, other: @Matrix<T>) -> Option<Matrix<T>> {
        let rows = *self.rows;
        let cols = *self.cols;
        let other_rows = *other.rows;
        let other_cols = *other.cols;
        if cols != other_rows {
            return None;
        }
        let mut data: Array<T> = ArrayTrait::new();
        let mut r: u32 = 0;
        while r < rows {
            let mut c: u32 = 0;
            while c < other_cols {
                let mut sum = Zero::zero();
                let mut k: u32 = 0;
                while k < cols {
                    let a = *self.data[index(r, k, cols)];
                    let b = *other.data[index(k, c, other_cols)];
                    sum = sum + a * b;
                    k += 1;
                }
                data.append(sum);
                c += 1;
            }
            r += 1;
        }
        Some(Matrix { data, rows, cols: other_cols })
    }

    fn scalar_mul(self: @Matrix<T>, scalar: T) -> Matrix<T> {
        let mut data: Array<T> = ArrayTrait::new();
        let len = self.data.len();
        let mut i: usize = 0;
        while i < len {
            let value = *self.data[i] * scalar;
            data.append(value);
            i += 1;
        }
        Matrix { data, rows: *self.rows, cols: *self.cols }
    }

    fn det_2x2(self: @Matrix<T>) -> Option<T> {
        let rows = *self.rows;
        let cols = *self.cols;
        if rows != 2_u32 || cols != 2_u32 {
            return None;
        }
        let a = *self.data[0];
        let b = *self.data[1];
        let c = *self.data[2];
        let d = *self.data[3];
        Some(a * d - b * c)
    }

    fn det_3x3(self: @Matrix<T>) -> Option<T> {
        let rows = *self.rows;
        let cols = *self.cols;
        if rows != 3_u32 || cols != 3_u32 {
            return None;
        }
        let a = *self.data[0];
        let b = *self.data[1];
        let c = *self.data[2];
        let d = *self.data[3];
        let e = *self.data[4];
        let f = *self.data[5];
        let g = *self.data[6];
        let h = *self.data[7];
        let i = *self.data[8];
        let term1 = a * e * i + b * f * g + c * d * h;
        let term2 = c * e * g + b * d * i + a * f * h;
        Some(term1 - term2)
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
}

impl VectorImpl<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TMul: Mul<T>,
    impl TZero: Zero<T>,
> of VectorTrait<T> {
    fn new(data: Array<T>) -> Vector<T> {
        Vector { data }
    }

    fn len(self: @Vector<T>) -> u32 {
        self.data.len().try_into().unwrap()
    }

    fn dot(self: @Vector<T>, other: @Vector<T>) -> Option<T> {
        let len = self.data.len();
        if len != other.data.len() {
            return None;
        }
        let mut sum = Zero::zero();
        let mut i: usize = 0;
        while i < len {
            let value = *self.data[i] * *other.data[i];
            sum = sum + value;
            i += 1;
        }
        Some(sum)
    }
}

pub fn matrix_vector_mul<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TMul: Mul<T>,
    impl TZero: Zero<T>,
>(
    m: @Matrix<T>, v: @Vector<T>,
) -> Option<Vector<T>> {
    let rows = *m.rows;
    let cols = *m.cols;
    if to_usize(cols) != v.data.len() {
        return None;
    }
    let mut data: Array<T> = ArrayTrait::new();
    let mut r: u32 = 0;
    while r < rows {
        let mut sum = Zero::zero();
        let mut c: u32 = 0;
        while c < cols {
            let a = *m.data[index(r, c, cols)];
            let b = *v.data[to_usize(c)];
            sum = sum + a * b;
            c += 1;
        }
        data.append(sum);
        r += 1;
    }
    Some(Vector { data })
}

impl MatrixPartialEq<
    T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TPartialEq: PartialEq<T>,
> of PartialEq<Matrix<T>> {
    fn eq(lhs: @Matrix<T>, rhs: @Matrix<T>) -> bool {
        if *lhs.rows != *rhs.rows || *lhs.cols != *rhs.cols {
            return false;
        }
        let len = lhs.data.len();
        if len != rhs.data.len() {
            return false;
        }
        let mut i: usize = 0;
        while i < len {
            if *lhs.data[i] != *rhs.data[i] {
                return false;
            }
            i += 1;
        }
        true
    }
}

impl VectorPartialEq<
    T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TPartialEq: PartialEq<T>,
> of PartialEq<Vector<T>> {
    fn eq(lhs: @Vector<T>, rhs: @Vector<T>) -> bool {
        let len = lhs.data.len();
        if len != rhs.data.len() {
            return false;
        }
        let mut i: usize = 0;
        while i < len {
            if *lhs.data[i] != *rhs.data[i] {
                return false;
            }
            i += 1;
        }
        true
    }
}

impl MatrixAdd<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TZero: Zero<T>,
    impl TOne: One<T>,
> of Add<Matrix<T>> {
    fn add(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        OptionTrait::unwrap(MatrixTrait::add(@lhs, @rhs))
    }
}

impl MatrixMul<
    T,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMul: Mul<T>,
    impl TZero: Zero<T>,
    impl TOne: One<T>,
> of Mul<Matrix<T>> {
    fn mul(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        OptionTrait::unwrap(MatrixTrait::mul(@lhs, @rhs))
    }
}

#[cfg(test)]
mod tests {
    use core::array::{Array, ArrayTrait};
    use core::option::OptionTrait;
    use super::{Matrix, MatrixTrait, Vector, VectorTrait, matrix_vector_mul};

    fn make_matrix(rows: u32, cols: u32, data: Array<i32>) -> Matrix<i32> {
        OptionTrait::unwrap(MatrixTrait::new(rows, cols, data))
    }

    fn make_vector(data: Array<i32>) -> Vector<i32> {
        VectorTrait::new(data)
    }

    fn data_1_to_6() -> Array<i32> {
        let mut data: Array<i32> = ArrayTrait::new();
        data.append(1_i32);
        data.append(2_i32);
        data.append(3_i32);
        data.append(4_i32);
        data.append(5_i32);
        data.append(6_i32);
        data
    }

    fn data_1_to_12() -> Array<i32> {
        let mut data: Array<i32> = ArrayTrait::new();
        let mut i: i32 = 1_i32;
        while i <= 12_i32 {
            data.append(i);
            i += 1_i32;
        }
        data
    }

    #[test]
    fn matrix_new_valid() {
        let mut data: Array<i32> = ArrayTrait::new();
        data.append(1_i32);
        data.append(2_i32);
        data.append(3_i32);
        data.append(4_i32);
        let result = MatrixTrait::new(2_u32, 2_u32, data);
        match result {
            Some(m) => {
                assert!(MatrixTrait::rows(@m) == 2_u32, "rows");
                assert!(MatrixTrait::cols(@m) == 2_u32, "cols");
                assert!(MatrixTrait::is_square(@m), "square");
            },
            None => { assert!(false, "expected Some"); },
        }
    }

    #[test]
    fn matrix_new_invalid() {
        let mut data: Array<i32> = ArrayTrait::new();
        data.append(1_i32);
        data.append(2_i32);
        data.append(3_i32);
        let result = MatrixTrait::new(2_u32, 2_u32, data);
        match result {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }

    #[test]
    fn matrix_zeros() {
        let m = MatrixTrait::zeros(2_u32, 3_u32);
        assert!(MatrixTrait::rows(@m) == 2_u32, "rows");
        assert!(MatrixTrait::cols(@m) == 3_u32, "cols");
        let mut i: usize = 0;
        while i < m.data.len() {
            assert!(*m.data[i] == 0_i32, "zero");
            i += 1;
        }
    }

    #[test]
    fn matrix_identity() {
        let m = MatrixTrait::identity(3_u32);
        let mut expected_data: Array<i32> = ArrayTrait::new();
        expected_data.append(1_i32);
        expected_data.append(0_i32);
        expected_data.append(0_i32);
        expected_data.append(0_i32);
        expected_data.append(1_i32);
        expected_data.append(0_i32);
        expected_data.append(0_i32);
        expected_data.append(0_i32);
        expected_data.append(1_i32);
        let expected = make_matrix(3_u32, 3_u32, expected_data);
        assert!(m == expected, "identity");
    }

    #[test]
    fn matrix_get_and_row_major() {
        let m = make_matrix(2_u32, 3_u32, data_1_to_6());
        match MatrixTrait::get(@m, 1_u32, 2_u32) {
            Some(v) => { assert!(*v == 6_i32, "get value"); },
            None => { assert!(false, "expected Some"); },
        }
        match MatrixTrait::get(@m, 0_u32, 1_u32) {
            Some(v) => { assert!(*v == 2_i32, "row-major 0,1"); },
            None => { assert!(false, "expected Some"); },
        }
        match MatrixTrait::get(@m, 1_u32, 0_u32) {
            Some(v) => { assert!(*v == 4_i32, "row-major 1,0"); },
            None => { assert!(false, "expected Some"); },
        }
        match MatrixTrait::get(@m, 2_u32, 0_u32) {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }

    #[test]
    fn matrix_transpose() {
        let m = make_matrix(2_u32, 3_u32, data_1_to_6());
        let t = MatrixTrait::transpose(@m);
        let mut expected_data: Array<i32> = ArrayTrait::new();
        expected_data.append(1_i32);
        expected_data.append(4_i32);
        expected_data.append(2_i32);
        expected_data.append(5_i32);
        expected_data.append(3_i32);
        expected_data.append(6_i32);
        let expected = make_matrix(3_u32, 2_u32, expected_data);
        assert!(t == expected, "transpose");

        let tt = MatrixTrait::transpose(@t);
        assert!(tt == m, "transpose twice");

        let mut single_row: Array<i32> = ArrayTrait::new();
        single_row.append(7_i32);
        single_row.append(8_i32);
        single_row.append(9_i32);
        let row_matrix = make_matrix(1_u32, 3_u32, single_row);
        let row_t = MatrixTrait::transpose(@row_matrix);
        let mut expected_col: Array<i32> = ArrayTrait::new();
        expected_col.append(7_i32);
        expected_col.append(8_i32);
        expected_col.append(9_i32);
        let expected_col_matrix = make_matrix(3_u32, 1_u32, expected_col);
        assert!(row_t == expected_col_matrix, "transpose 1xn");
    }

    #[test]
    fn matrix_add_sub() {
        let a = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(1_i32);
                data.append(2_i32);
                data.append(3_i32);
                data.append(4_i32);
                data
            },
        );
        let zeros = MatrixTrait::zeros(2_u32, 2_u32);
        let sum = OptionTrait::unwrap(MatrixTrait::add(@a, @zeros));
        assert!(sum == a, "A + zeros");

        let b = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(5_i32);
                data.append(6_i32);
                data.append(7_i32);
                data.append(8_i32);
                data
            },
        );
        let sum_ab = OptionTrait::unwrap(MatrixTrait::add(@a, @b));
        let sum_ba = OptionTrait::unwrap(MatrixTrait::add(@b, @a));
        assert!(sum_ab == sum_ba, "commutative");

        let diff = OptionTrait::unwrap(MatrixTrait::sub(@a, @zeros));
        assert!(diff == a, "A - zeros");

        let mismatch = MatrixTrait::add(@a, @MatrixTrait::zeros(2_u32, 3_u32));
        match mismatch {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }

    #[test]
    fn matrix_mul() {
        let a = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(1_i32);
                data.append(2_i32);
                data.append(3_i32);
                data.append(4_i32);
                data
            },
        );
        let identity = MatrixTrait::identity(2_u32);
        let left = OptionTrait::unwrap(MatrixTrait::mul(@a, @identity));
        let right = OptionTrait::unwrap(MatrixTrait::mul(@identity, @a));
        assert!(left == a, "A * I");
        assert!(right == a, "I * A");

        let b = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(2_i32);
                data.append(0_i32);
                data.append(1_i32);
                data.append(2_i32);
                data
            },
        );
        let ab = OptionTrait::unwrap(MatrixTrait::mul(@a, @b));
        let ba = OptionTrait::unwrap(MatrixTrait::mul(@b, @a));
        assert!(ab != ba, "non-commutative");

        let m23 = make_matrix(2_u32, 3_u32, data_1_to_6());
        let m34 = make_matrix(3_u32, 4_u32, data_1_to_12());
        let prod = OptionTrait::unwrap(MatrixTrait::mul(@m23, @m34));
        assert!(MatrixTrait::rows(@prod) == 2_u32, "rows 2x4");
        assert!(MatrixTrait::cols(@prod) == 4_u32, "cols 2x4");
        let mut expected_data: Array<i32> = ArrayTrait::new();
        expected_data.append(38_i32);
        expected_data.append(44_i32);
        expected_data.append(50_i32);
        expected_data.append(56_i32);
        expected_data.append(83_i32);
        expected_data.append(98_i32);
        expected_data.append(113_i32);
        expected_data.append(128_i32);
        let expected = make_matrix(2_u32, 4_u32, expected_data);
        assert!(prod == expected, "mul 2x3 * 3x4");

        let bad = MatrixTrait::mul(@m23, @m23);
        match bad {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }

    #[test]
    fn matrix_scalar_mul() {
        let a = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(1_i32);
                data.append(2_i32);
                data.append(3_i32);
                data.append(4_i32);
                data
            },
        );
        let zeros = MatrixTrait::zeros(2_u32, 2_u32);
        let zeroed = MatrixTrait::scalar_mul(@a, 0_i32);
        assert!(zeroed == zeros, "A * 0");
        let ones = MatrixTrait::scalar_mul(@a, 1_i32);
        assert!(ones == a, "A * 1");
        let doubled = MatrixTrait::scalar_mul(@a, 2_i32);
        let mut expected_data: Array<i32> = ArrayTrait::new();
        expected_data.append(2_i32);
        expected_data.append(4_i32);
        expected_data.append(6_i32);
        expected_data.append(8_i32);
        let expected = make_matrix(2_u32, 2_u32, expected_data);
        assert!(doubled == expected, "A * 2");
    }

    #[test]
    fn matrix_determinant() {
        let a = make_matrix(
            2_u32,
            2_u32,
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(1_i32);
                data.append(2_i32);
                data.append(3_i32);
                data.append(4_i32);
                data
            },
        );
        let det = OptionTrait::unwrap(MatrixTrait::det_2x2(@a));
        let expected = 0_i32 - 2_i32;
        assert!(det == expected, "det 2x2");

        let id2 = MatrixTrait::identity(2_u32);
        let det_id2 = OptionTrait::unwrap(MatrixTrait::det_2x2(@id2));
        assert!(det_id2 == 1_i32, "det identity 2x2");

        let id3 = MatrixTrait::identity(3_u32);
        let det_id3 = OptionTrait::unwrap(MatrixTrait::det_3x3(@id3));
        assert!(det_id3 == 1_i32, "det identity 3x3");

        let nonsquare = MatrixTrait::det_2x2(@MatrixTrait::zeros(2_u32, 3_u32));
        match nonsquare {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }

    #[test]
    fn vector_ops() {
        let v1 = make_vector(
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(1_i32);
                data.append(2_i32);
                data.append(3_i32);
                data
            },
        );
        let v2 = make_vector(
            {
                let mut data: Array<i32> = ArrayTrait::new();
                data.append(4_i32);
                data.append(5_i32);
                data.append(6_i32);
                data
            },
        );
        assert!(VectorTrait::len(@v1) == 3_u32, "vector len");
        let dot = OptionTrait::unwrap(VectorTrait::dot(@v1, @v2));
        assert!(dot == 32_i32, "dot product");

        let identity = MatrixTrait::identity(3_u32);
        let mv = OptionTrait::unwrap(matrix_vector_mul(@identity, @v1));
        assert!(mv == v1, "matrix-vector identity");

        let bad = matrix_vector_mul(@MatrixTrait::identity(2_u32), @v1);
        match bad {
            Some(_) => { assert!(false, "expected None"); },
            None => {},
        }
    }
}
