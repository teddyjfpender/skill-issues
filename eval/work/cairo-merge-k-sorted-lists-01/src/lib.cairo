use core::array::{Array, ArrayTrait};

fn merge_two_sorted<T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TPartialOrd: PartialOrd<T>>(
    left: @Array<T>, right: @Array<T>,
) -> Array<T> {
    let mut result: Array<T> = ArrayTrait::new();
    let mut i: usize = 0;
    let mut j: usize = 0;
    let left_len = left.len();
    let right_len = right.len();

    while i < left_len && j < right_len {
        let left_value = *left[i];
        let right_value = *right[j];
        if left_value <= right_value {
            result.append(left_value);
            i += 1;
        } else {
            result.append(right_value);
            j += 1;
        }
    }

    while i < left_len {
        result.append(*left[i]);
        i += 1;
    }

    while j < right_len {
        result.append(*right[j]);
        j += 1;
    }

    result
}

fn merge_k_sorted_generic<
    T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TPartialOrd: PartialOrd<T>,
>(
    lists: @Array<Array<T>>,
) -> Array<T> {
    let mut result: Array<T> = ArrayTrait::new();
    let mut i: usize = 0;
    let lists_len = lists.len();

    while i < lists_len {
        let merged = merge_two_sorted(@result, lists[i]);
        result = merged;
        i += 1;
    }

    result
}

pub fn merge_k_sorted(lists: Array<Array<i32>>) -> Array<i32> {
    merge_k_sorted_generic(@lists)
}

#[cfg(test)]
mod tests {
    use core::array::{Array, ArrayTrait};
    use super::merge_k_sorted;

    fn assert_array_eq(expected: @Array<i32>, actual: @Array<i32>) {
        let expected_len = expected.len();
        let actual_len = actual.len();
        assert!(expected_len == actual_len, "array length mismatch");
        let mut i: usize = 0;
        while i < expected_len {
            assert!(*expected[i] == *actual[i], "array element mismatch");
            i += 1;
        }
    }

    #[test]
    fn merge_normal() {
        let mut list1: Array<i32> = ArrayTrait::new();
        list1.append(1_i32);
        list1.append(4_i32);
        list1.append(5_i32);

        let mut list2: Array<i32> = ArrayTrait::new();
        list2.append(1_i32);
        list2.append(3_i32);
        list2.append(4_i32);

        let mut list3: Array<i32> = ArrayTrait::new();
        list3.append(2_i32);
        list3.append(6_i32);

        let mut lists: Array<Array<i32>> = ArrayTrait::new();
        lists.append(list1);
        lists.append(list2);
        lists.append(list3);

        let merged = merge_k_sorted(lists);

        let mut expected: Array<i32> = ArrayTrait::new();
        expected.append(1_i32);
        expected.append(1_i32);
        expected.append(2_i32);
        expected.append(3_i32);
        expected.append(4_i32);
        expected.append(4_i32);
        expected.append(5_i32);
        expected.append(6_i32);

        assert_array_eq(@expected, @merged);
    }

    #[test]
    fn merge_empty_input() {
        let lists: Array<Array<i32>> = ArrayTrait::new();
        let merged = merge_k_sorted(lists);
        let expected: Array<i32> = ArrayTrait::new();
        assert_array_eq(@expected, @merged);
    }

    #[test]
    fn merge_with_empty_arrays() {
        let empty1: Array<i32> = ArrayTrait::new();
        let empty2: Array<i32> = ArrayTrait::new();

        let mut list: Array<i32> = ArrayTrait::new();
        list.append(2_i32);
        list.append(3_i32);

        let mut lists: Array<Array<i32>> = ArrayTrait::new();
        lists.append(empty1);
        lists.append(list);
        lists.append(empty2);

        let merged = merge_k_sorted(lists);

        let mut expected: Array<i32> = ArrayTrait::new();
        expected.append(2_i32);
        expected.append(3_i32);

        assert_array_eq(@expected, @merged);
    }

    #[test]
    fn merge_single_array() {
        let mut list: Array<i32> = ArrayTrait::new();
        list.append(7_i32);
        list.append(9_i32);
        list.append(10_i32);

        let mut lists: Array<Array<i32>> = ArrayTrait::new();
        lists.append(list);

        let merged = merge_k_sorted(lists);

        let mut expected: Array<i32> = ArrayTrait::new();
        expected.append(7_i32);
        expected.append(9_i32);
        expected.append(10_i32);

        assert_array_eq(@expected, @merged);
    }

    #[test]
    fn merge_with_duplicates() {
        let mut list1: Array<i32> = ArrayTrait::new();
        list1.append(1_i32);
        list1.append(2_i32);
        list1.append(2_i32);

        let mut list2: Array<i32> = ArrayTrait::new();
        list2.append(2_i32);
        list2.append(2_i32);

        let mut lists: Array<Array<i32>> = ArrayTrait::new();
        lists.append(list1);
        lists.append(list2);

        let merged = merge_k_sorted(lists);

        let mut expected: Array<i32> = ArrayTrait::new();
        expected.append(1_i32);
        expected.append(2_i32);
        expected.append(2_i32);
        expected.append(2_i32);
        expected.append(2_i32);

        assert_array_eq(@expected, @merged);
    }
}
