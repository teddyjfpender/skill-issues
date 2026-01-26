use core::cmp::{min, max};

pub fn max_u32(a: u32, b: u32) -> u32 {
    if a > b { a } else { b }
}

pub fn min_u32(a: u32, b: u32) -> u32 {
    if a < b { a } else { b }
}

pub fn trap_brute_force(height: @Array<u32>) -> u32 {
    if height.len() == 0 {
        return 0;
    }
    
    let mut total_water = 0;
    let mut i = 0;
    
    while i < height.len() {
        // Find maximum height to the left
        let mut left_max = 0;
        let mut j = 0;
        while j < i {
            left_max = max_u32(left_max, *height.at(j));
            j += 1;
        };
        
        // Find maximum height to the right
        let mut right_max = 0;
        j = i + 1;
        while j < height.len() {
            right_max = max_u32(right_max, *height.at(j));
            j += 1;
        };
        
        // Calculate water at current position
        let min_height = min_u32(left_max, right_max);
        let current_height = *height.at(i);
        if min_height > current_height {
            total_water += min_height - current_height;
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
    
    // Pre-compute left_max array
    let mut left_max: Array<u32> = array![];
    left_max.append(*height.at(0));
    let mut i = 1;
    while i < n {
        let prev_max = *left_max.at(i - 1);
        let curr_height = *height.at(i);
        left_max.append(max_u32(prev_max, curr_height));
        i += 1;
    };
    
    // Pre-compute right_max array
    let mut right_max: Array<u32> = array![];
    let mut j = 0;
    while j < n {
        right_max.append(0);
        j += 1;
    };
    
    // Fill right_max from right to left
    let last_idx = n - 1;
    let mut temp_arr: Array<u32> = array![];
    temp_arr.append(*height.at(last_idx));
    
    let mut k = 1;
    while k <= last_idx {
        let idx = last_idx - k;
        let prev_max = *temp_arr.at(k - 1);
        let curr_height = *height.at(idx);
        temp_arr.append(max_u32(prev_max, curr_height));
        k += 1;
    };
    
    // Reverse temp_arr into right_max
    right_max = array![];
    let mut m = 0;
    while m < n {
        let reverse_idx = n - 1 - m;
        right_max.append(*temp_arr.at(reverse_idx));
        m += 1;
    };
    
    // Calculate total water
    let mut total_water = 0;
    let mut p = 0;
    while p < n {
        let min_height = min_u32(*left_max.at(p), *right_max.at(p));
        let current_height = *height.at(p);
        if min_height > current_height {
            total_water += min_height - current_height;
        }
        p += 1;
    };
    
    total_water
}

pub fn trap(height: @Array<u32>) -> u32 {
    if height.len() == 0 {
        return 0;
    }
    
    let mut left = 0;
    let mut right = height.len() - 1;
    let mut left_max = 0;
    let mut right_max = 0;
    let mut total_water = 0;
    
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
    fn two_pointers(height: @Array<u32>) -> u32;
    fn solve(height: @Array<u32>) -> u32;
}

pub impl RainWaterImpl of RainWaterTrait {
    fn brute_force(height: @Array<u32>) -> u32 {
        trap_brute_force(height)
    }
    
    fn dynamic_programming(height: @Array<u32>) -> u32 {
        trap_dp(height)
    }
    
    fn two_pointers(height: @Array<u32>) -> u32 {
        trap(height)
    }
    
    fn solve(height: @Array<u32>) -> u32 {
        trap(height)
    }
}

pub trait SolutionTrait {
    fn solve(input: @Array<u32>) -> u32;
}

pub impl SolutionImpl of SolutionTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap(input)
    }
}
