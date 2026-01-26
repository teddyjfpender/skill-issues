use core::num::traits::{Zero, One};

fn max(a: u32, b: u32) -> u32 {
    if a > b {
        a
    } else {
        b
    }
}

fn min(a: u32, b: u32) -> u32 {
    if a < b {
        a
    } else {
        b
    }
}

pub fn trap_brute_force(height: @Array<u32>) -> u32 {
    if height.len() == 0 {
        return 0;
    }

    let mut total_water: u32 = 0;
    let n = height.len();
    
    let mut i: u32 = 0;
    while i < n {
        let mut left_max: u32 = 0;
        let mut j: u32 = 0;
        while j <= i {
            left_max = max(left_max, *height.at(j));
            j += 1;
        };
        
        let mut right_max: u32 = 0;
        let mut k: u32 = i;
        while k < n {
            right_max = max(right_max, *height.at(k));
            k += 1;
        };
        
        let water_level = min(left_max, right_max);
        let current_height = *height.at(i);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        
        i += 1;
    };
    
    total_water
}

pub fn trap_dp(height: @Array<u32>) -> u32 {
    if height.len() == 0 {
        return 0;
    }

    let n = height.len();
    
    let mut left_max: Array<u32> = array![];
    let mut current_left_max: u32 = 0;
    let mut i: u32 = 0;
    while i < n {
        current_left_max = max(current_left_max, *height.at(i));
        left_max.append(current_left_max);
        i += 1;
    };
    
    let mut right_max: Array<u32> = array![];
    let mut j: u32 = 0;
    while j < n {
        right_max.append(0);
        j += 1;
    };
    
    let mut current_right_max: u32 = 0;
    let mut k: u32 = n;
    while k > 0 {
        k -= 1;
        current_right_max = max(current_right_max, *height.at(k));
        
        let mut temp_array: Array<u32> = array![];
        let mut m: u32 = 0;
        while m < n {
            if m == k {
                temp_array.append(current_right_max);
            } else {
                temp_array.append(*right_max.at(m));
            }
            m += 1;
        };
        right_max = temp_array;
    };
    
    let mut total_water: u32 = 0;
    let mut idx: u32 = 0;
    while idx < n {
        let water_level = min(*left_max.at(idx), *right_max.at(idx));
        let current_height = *height.at(idx);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        idx += 1;
    };
    
    total_water
}

pub fn trap(height: @Array<u32>) -> u32 {
    if height.len() == 0 {
        return 0;
    }

    let mut left: u32 = 0;
    let mut right: u32 = height.len() - 1;
    let mut left_max: u32 = 0;
    let mut right_max: u32 = 0;
    let mut total_water: u32 = 0;

    while left < right {
        let left_height = *height.at(left);
        let right_height = *height.at(right);

        if left_height < right_height {
            if left_height >= left_max {
                left_max = left_height;
            } else {
                total_water += left_max - left_height;
            }
            left += 1;
        } else {
            if right_height >= right_max {
                right_max = right_height;
            } else {
                total_water += right_max - right_height;
            }
            right -= 1;
        }
    };

    total_water
}

pub trait RainWaterTrait {
    fn brute_force(height: @Array<u32>) -> u32;
    fn dynamic_programming(height: @Array<u32>) -> u32;
    fn two_pointer(height: @Array<u32>) -> u32;
    fn solve(height: @Array<u32>) -> u32;
}

pub impl RainWaterImpl of RainWaterTrait {
    fn brute_force(height: @Array<u32>) -> u32 {
        trap_brute_force(height)
    }

    fn dynamic_programming(height: @Array<u32>) -> u32 {
        trap_dp(height)
    }

    fn two_pointer(height: @Array<u32>) -> u32 {
        trap(height)
    }

    fn solve(height: @Array<u32>) -> u32 {
        trap(height)
    }
}

#[cfg(test)]
mod tests {
    use super::{RainWaterTrait, RainWaterImpl};

    #[test]
    fn test_example_1() {
        let height = array![0, 1, 0, 2, 1, 0, 1, 3, 2, 1, 2, 1];
        assert!(RainWaterImpl::brute_force(@height) == 6, "brute_force ex1");
        assert!(RainWaterImpl::dynamic_programming(@height) == 6, "dp ex1");
        assert!(RainWaterImpl::two_pointer(@height) == 6, "two_ptr ex1");
        assert!(RainWaterImpl::solve(@height) == 6, "solve ex1");
    }

    #[test]
    fn test_example_2() {
        let height = array![4, 2, 0, 3, 2, 5];
        assert!(RainWaterImpl::brute_force(@height) == 9, "brute_force ex2");
        assert!(RainWaterImpl::dynamic_programming(@height) == 9, "dp ex2");
        assert!(RainWaterImpl::two_pointer(@height) == 9, "two_ptr ex2");
        assert!(RainWaterImpl::solve(@height) == 9, "solve ex2");
    }

    #[test]
    fn test_empty_array() {
        let height = array![];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force empty");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp empty");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr empty");
        assert!(RainWaterImpl::solve(@height) == 0, "solve empty");
    }

    #[test]
    fn test_single_element() {
        let height = array![5];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force single");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp single");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr single");
        assert!(RainWaterImpl::solve(@height) == 0, "solve single");
    }

    #[test]
    fn test_two_elements() {
        let height = array![3, 7];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force two");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp two");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr two");
        assert!(RainWaterImpl::solve(@height) == 0, "solve two");
    }

    #[test]
    fn test_flat_array() {
        let height = array![3, 3, 3, 3];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force flat");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp flat");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr flat");
        assert!(RainWaterImpl::solve(@height) == 0, "solve flat");
    }

    #[test]
    fn test_descending() {
        let height = array![5, 4, 3, 2, 1];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force desc");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp desc");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr desc");
        assert!(RainWaterImpl::solve(@height) == 0, "solve desc");
    }

    #[test]
    fn test_ascending() {
        let height = array![1, 2, 3, 4, 5];
        assert!(RainWaterImpl::brute_force(@height) == 0, "brute_force asc");
        assert!(RainWaterImpl::dynamic_programming(@height) == 0, "dp asc");
        assert!(RainWaterImpl::two_pointer(@height) == 0, "two_ptr asc");
        assert!(RainWaterImpl::solve(@height) == 0, "solve asc");
    }

    #[test]
    fn test_v_shape() {
        let height = array![5, 0, 5];
        assert!(RainWaterImpl::brute_force(@height) == 5, "brute_force v");
        assert!(RainWaterImpl::dynamic_programming(@height) == 5, "dp v");
        assert!(RainWaterImpl::two_pointer(@height) == 5, "two_ptr v");
        assert!(RainWaterImpl::solve(@height) == 5, "solve v");
    }
}
