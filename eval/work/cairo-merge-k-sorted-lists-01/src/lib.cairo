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

/// Merges k sorted arrays using divide-and-conquer pairwise merging.
/// Time complexity: O(N log k) where N is total elements and k is number of lists.
///
/// Gas comparison (Sequential vs D&C):
/// - k=3:  Sequential wins (~177k vs ~253k) - overhead dominates
/// - k=8:  Roughly equal (~818k vs ~821k) - crossover point
/// - k=16: D&C wins (~1.93M vs ~1.39M) - 28% savings
/// - k=32: D&C wins (~2.32M vs ~1.82M) - 22% savings
fn merge_k_sorted_generic<
    T, impl TDrop: Drop<T>, impl TCopy: Copy<T>, impl TPartialOrd: PartialOrd<T>,
>(
    lists: @Array<Array<T>>,
) -> Array<T> {
    let lists_len = lists.len();

    if lists_len == 0 {
        return ArrayTrait::new();
    }

    // Copy input lists into working array
    let mut current: Array<Array<T>> = ArrayTrait::new();
    let mut i: usize = 0;
    while i < lists_len {
        let mut copy: Array<T> = ArrayTrait::new();
        let list = lists[i];
        let mut j: usize = 0;
        while j < list.len() {
            copy.append(*list[j]);
            j += 1;
        };
        current.append(copy);
        i += 1;
    };

    // Iteratively merge pairs until one list remains
    while current.len() > 1 {
        let mut next: Array<Array<T>> = ArrayTrait::new();
        let current_len = current.len();
        let mut idx: usize = 0;

        while idx + 1 < current_len {
            // Merge pairs - current[idx] already returns @Array<T>
            let merged = merge_two_sorted(current[idx], current[idx + 1]);
            next.append(merged);
            idx += 2;
        };

        // If odd number of lists, carry the last one forward
        if idx < current_len {
            let mut last_copy: Array<T> = ArrayTrait::new();
            let last: @Array<T> = current[idx];
            let mut k: usize = 0;
            while k < last.len() {
                last_copy.append(*last[k]);
                k += 1;
            };
            next.append(last_copy);
        }

        current = next;
    };

    // Extract the single remaining list
    let mut result: Array<T> = ArrayTrait::new();
    if current.len() == 1 {
        let final_list = @current[0];
        let mut i: usize = 0;
        while i < final_list.len() {
            result.append(*final_list[i]);
            i += 1;
        };
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

    #[test]
    fn merge_k8_lists() {
        // 8 lists with 3 elements each = 24 total elements
        let mut lists: Array<Array<i32>> = ArrayTrait::new();

        let mut l1: Array<i32> = ArrayTrait::new();
        l1.append(1); l1.append(9); l1.append(17);
        lists.append(l1);

        let mut l2: Array<i32> = ArrayTrait::new();
        l2.append(2); l2.append(10); l2.append(18);
        lists.append(l2);

        let mut l3: Array<i32> = ArrayTrait::new();
        l3.append(3); l3.append(11); l3.append(19);
        lists.append(l3);

        let mut l4: Array<i32> = ArrayTrait::new();
        l4.append(4); l4.append(12); l4.append(20);
        lists.append(l4);

        let mut l5: Array<i32> = ArrayTrait::new();
        l5.append(5); l5.append(13); l5.append(21);
        lists.append(l5);

        let mut l6: Array<i32> = ArrayTrait::new();
        l6.append(6); l6.append(14); l6.append(22);
        lists.append(l6);

        let mut l7: Array<i32> = ArrayTrait::new();
        l7.append(7); l7.append(15); l7.append(23);
        lists.append(l7);

        let mut l8: Array<i32> = ArrayTrait::new();
        l8.append(8); l8.append(16); l8.append(24);
        lists.append(l8);

        let merged = merge_k_sorted(lists);

        assert!(merged.len() == 24, "should have 24 elements");
        // Verify sorted order
        let mut i: usize = 0;
        while i < 23 {
            assert!(*merged[i] <= *merged[i + 1], "should be sorted");
            i += 1;
        };
    }

    #[test]
    fn merge_k16_lists() {
        // 16 lists with 2 elements each = 32 total elements
        let mut lists: Array<Array<i32>> = ArrayTrait::new();

        let mut i: i32 = 0;
        while i < 16 {
            let mut l: Array<i32> = ArrayTrait::new();
            l.append(i + 1);
            l.append(i + 17);
            lists.append(l);
            i += 1;
        };

        let merged = merge_k_sorted(lists);

        assert!(merged.len() == 32, "should have 32 elements");
        // Verify sorted order
        let mut j: usize = 0;
        while j < 31 {
            assert!(*merged[j] <= *merged[j + 1], "should be sorted");
            j += 1;
        };
    }

    #[test]
    fn merge_k32_many_small_lists() {
        // 32 lists with 1 element each = 32 total elements
        // This is the worst case for sequential (k iterations over growing result)
        let mut lists: Array<Array<i32>> = ArrayTrait::new();

        let mut i: i32 = 0;
        while i < 32 {
            let mut l: Array<i32> = ArrayTrait::new();
            l.append(32 - i); // reverse order to make merging non-trivial
            lists.append(l);
            i += 1;
        };

        let merged = merge_k_sorted(lists);

        assert!(merged.len() == 32, "should have 32 elements");
        // Verify sorted order
        let mut j: usize = 0;
        while j < 31 {
            assert!(*merged[j] <= *merged[j + 1], "should be sorted");
            j += 1;
        };
    }
}
