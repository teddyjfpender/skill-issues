use core::cmp::{max, min};

pub fn max_u32(a: u32, b: u32) -> u32 {
    if a > b { a } else { b }
}

pub fn min_u32(a: u32, b: u32) -> u32 {
    if a < b { a } else { b }
}

pub fn trap_brute_force(height: @Array<u32>) -> u32 {
    let n = height.len();
    if n <= 2 {
        return 0;
    }
    
    let mut total_water: u32 = 0;
    let mut i: u32 = 1;
    
    while i < n - 1 {
        // Find max height to the left
        let mut left_max: u32 = 0;
        let mut j: u32 = 0;
        while j < i {
            left_max = max_u32(left_max, *height.at(j));
            j += 1;
        };
        
        // Find max height to the right
        let mut right_max: u32 = 0;
        j = i + 1;
        while j < n {
            right_max = max_u32(right_max, *height.at(j));
            j += 1;
        };
        
        // Calculate water at current position
        let water_level = min_u32(left_max, right_max);
        let current_height = *height.at(i);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        
        i += 1;
    };
    
    total_water
}

pub fn trap_dp(height: @Array<u32>) -> u32 {
    let n = height.len();
    if n <= 2 {
        return 0;
    }
    
    // Pre-compute left_max array
    let mut left_max: Array<u32> = array![];
    left_max.append(*height.at(0));
    let mut i: u32 = 1;
    while i < n {
        let prev_max = *left_max.at(i - 1);
        let current_height = *height.at(i);
        left_max.append(max_u32(prev_max, current_height));
        i += 1;
    };
    
    // Pre-compute right_max array
    let mut right_max: Array<u32> = array![];
    // Fill with zeros first
    i = 0;
    while i < n {
        right_max.append(0);
        i += 1;
    };
    
    // Set last element
    let last_idx = n - 1;
    let mut new_right_max: Array<u32> = array![];
    i = 0;
    while i < n {
        if i == last_idx {
            new_right_max.append(*height.at(last_idx));
        } else {
            new_right_max.append(0);
        }
        i += 1;
    };
    right_max = new_right_max;
    
    // Fill right_max from right to left
    if n >= 2 {
        i = n - 2;
        loop {
            let next_max = *right_max.at(i + 1);
            let current_height = *height.at(i);
            let max_val = max_u32(next_max, current_height);
            
            // Rebuild array with updated value
            let mut updated_right_max: Array<u32> = array![];
            let mut j: u32 = 0;
            while j < n {
                if j == i {
                    updated_right_max.append(max_val);
                } else {
                    updated_right_max.append(*right_max.at(j));
                }
                j += 1;
            };
            right_max = updated_right_max;
            
            if i == 0 {
                break;
            }
            i -= 1;
        };
    }
    
    // Calculate trapped water
    let mut total_water: u32 = 0;
    i = 1;
    while i < n - 1 {
        let water_level = min_u32(*left_max.at(i), *right_max.at(i));
        let current_height = *height.at(i);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        i += 1;
    };
    
    total_water
}

pub fn trap(height: @Array<u32>) -> u32 {
    let n = height.len();
    if n <= 2 {
        return 0;
    }
    
    let mut left: u32 = 0;
    let mut right: u32 = n - 1;
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
    fn solve(input: @Array<u32>) -> u32;
    fn brute_force(input: @Array<u32>) -> u32;
    fn dynamic_programming(input: @Array<u32>) -> u32;
    fn optimal(input: @Array<u32>) -> u32;
}

pub impl RainWaterImpl of RainWaterTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap(input)
    }
    
    fn brute_force(input: @Array<u32>) -> u32 {
        trap_brute_force(input)
    }
    
    fn dynamic_programming(input: @Array<u32>) -> u32 {
        trap_dp(input)
    }
    
    fn optimal(input: @Array<u32>) -> u32 {
        trap(input)
    }
}

pub trait SolutionTrait {
    fn solve(input: @Array<u32>) -> u32;
}

pub impl SolutionImpl of SolutionTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap_brute_force(input)
    }
}
