use core::array::ArrayTrait;

pub fn max(a: u32, b: u32) -> u32 {
    if a > b {
        a
    } else {
        b
    }
}

pub fn min(a: u32, b: u32) -> u32 {
    if a < b {
        a
    } else {
        b
    }
}

pub fn trap_brute_force(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }

    let mut total_water = 0;
    let mut i = 1;

    while i < height.len() - 1 {
        // Find max height to the left
        let mut left_max = 0;
        let mut j = 0;
        while j < i {
            left_max = max(left_max, *height.at(j));
            j += 1;
        }

        // Find max height to the right
        let mut right_max = 0;
        j = i + 1;
        while j < height.len() {
            right_max = max(right_max, *height.at(j));
            j += 1;
        }

        // Calculate water at current position
        let min_height = min(left_max, right_max);
        let current_height = *height.at(i);
        if min_height > current_height {
            total_water += min_height - current_height;
        }

        i += 1;
    }

    total_water
}

pub fn trap_dp(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }

    let n = height.len();
    let mut left_max: Array<u32> = ArrayTrait::new();
    let mut right_max: Array<u32> = ArrayTrait::new();

    // Build left_max array
    left_max.append(*height.at(0));
    let mut i = 1;
    while i < n {
        let prev_max = *left_max.at(i - 1);
        let current_height = *height.at(i);
        left_max.append(max(prev_max, current_height));
        i += 1;
    }

    // Build right_max array - fill with zeros first
    let mut j = 0;
    while j < n {
        right_max.append(0);
        j += 1;
    }

    // Set last element and fill backwards
    let last_idx = n - 1;
    right_max.append(*height.at(last_idx));
    let _right_max_span = right_max.span();

    // Create new array for actual right_max values
    let mut final_right_max: Array<u32> = ArrayTrait::new();
    j = 0;
    while j < n {
        final_right_max.append(0);
        j += 1;
    }

    // Calculate right_max properly
    let mut temp_right_max: Array<u32> = ArrayTrait::new();
    temp_right_max.append(*height.at(last_idx));

    let mut k = 1;
    while k < n {
        let idx = n - 1 - k;
        let prev_max = *temp_right_max.at(k - 1);
        let current_height = *height.at(idx);
        temp_right_max.append(max(prev_max, current_height));
        k += 1;
    }

    // Reverse temp_right_max to get final_right_max
    let mut final_right: Array<u32> = ArrayTrait::new();
    let mut m = 0;
    while m < n {
        let reverse_idx = n - 1 - m;
        final_right.append(*temp_right_max.at(reverse_idx));
        m += 1;
    }

    // Calculate total water
    let mut total_water = 0;
    let mut p = 0;
    while p < n {
        let left_val = *left_max.at(p);
        let right_val = *final_right.at(p);
        let current_height = *height.at(p);
        let water_level = min(left_val, right_val);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        p += 1;
    }

    total_water
}

pub fn trap(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }

    let mut left = 0;
    let mut right = height.len() - 1;
    let mut left_max = 0;
    let mut right_max = 0;
    let mut total_water = 0;

    while left < right {
        if *height.at(left) < *height.at(right) {
            if *height.at(left) >= left_max {
                left_max = *height.at(left);
            } else {
                total_water += left_max - *height.at(left);
            }
            left += 1;
        } else {
            if *height.at(right) >= right_max {
                right_max = *height.at(right);
            } else {
                total_water += right_max - *height.at(right);
            }
            right -= 1;
        }
    }

    total_water
}

trait RainWaterTrait {
    fn solve(height: @Array<u32>) -> u32;
    fn brute_force(height: @Array<u32>) -> u32;
    fn dynamic_programming(height: @Array<u32>) -> u32;
    fn two_pointers(height: @Array<u32>) -> u32;
}

impl RainWaterImpl of RainWaterTrait {
    fn solve(height: @Array<u32>) -> u32 {
        trap(height)
    }

    fn brute_force(height: @Array<u32>) -> u32 {
        trap_brute_force(height)
    }

    fn dynamic_programming(height: @Array<u32>) -> u32 {
        trap_dp(height)
    }

    fn two_pointers(height: @Array<u32>) -> u32 {
        trap(height)
    }
}

#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use super::{max, min, trap, trap_brute_force, trap_dp};

    #[test]
    fn test_helper_max() {
        assert(max(3, 5) == 5, 'max(3,5) should be 5');
        assert(max(7, 2) == 7, 'max(7,2) should be 7');
        assert(max(4, 4) == 4, 'max(4,4) should be 4');
    }

    #[test]
    fn test_helper_min() {
        assert(min(3, 5) == 3, 'min(3,5) should be 3');
        assert(min(7, 2) == 2, 'min(7,2) should be 2');
        assert(min(4, 4) == 4, 'min(4,4) should be 4');
    }

    #[test]
    fn test_example_1_two_pointer() {
        // [0,1,0,2,1,0,1,3,2,1,2,1] -> 6
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(0);
        height.append(1);
        height.append(0);
        height.append(2);
        height.append(1);
        height.append(0);
        height.append(1);
        height.append(3);
        height.append(2);
        height.append(1);
        height.append(2);
        height.append(1);
        assert(trap(@height) == 6, 'Example 1 should be 6');
    }

    #[test]
    fn test_example_1_brute_force() {
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(0);
        height.append(1);
        height.append(0);
        height.append(2);
        height.append(1);
        height.append(0);
        height.append(1);
        height.append(3);
        height.append(2);
        height.append(1);
        height.append(2);
        height.append(1);
        assert(trap_brute_force(@height) == 6, 'BF Example 1 should be 6');
    }

    #[test]
    fn test_example_2() {
        // [4,2,0,3,2,5] -> 9
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(4);
        height.append(2);
        height.append(0);
        height.append(3);
        height.append(2);
        height.append(5);
        assert(trap(@height) == 9, 'Example 2 should be 9');
    }

    #[test]
    fn test_empty_array() {
        let height: Array<u32> = ArrayTrait::new();
        assert(trap(@height) == 0, 'Empty should be 0');
    }

    #[test]
    fn test_single_element() {
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(5);
        assert(trap(@height) == 0, 'Single should be 0');
    }

    #[test]
    fn test_two_elements() {
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(5);
        height.append(3);
        assert(trap(@height) == 0, 'Two elements should be 0');
    }

    #[test]
    fn test_flat_array() {
        // [3,3,3,3] -> 0
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(3);
        height.append(3);
        height.append(3);
        height.append(3);
        assert(trap(@height) == 0, 'Flat should be 0');
    }

    #[test]
    fn test_descending() {
        // [5,4,3,2,1] -> 0
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(5);
        height.append(4);
        height.append(3);
        height.append(2);
        height.append(1);
        assert(trap(@height) == 0, 'Descending should be 0');
    }

    #[test]
    fn test_ascending() {
        // [1,2,3,4,5] -> 0
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(1);
        height.append(2);
        height.append(3);
        height.append(4);
        height.append(5);
        assert(trap(@height) == 0, 'Ascending should be 0');
    }

    #[test]
    fn test_v_shape() {
        // [5,0,5] -> 5
        let mut height: Array<u32> = ArrayTrait::new();
        height.append(5);
        height.append(0);
        height.append(5);
        assert(trap(@height) == 5, 'V-shape should be 5');
    }
}
