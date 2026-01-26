use core::num::traits::Zero;

pub fn max(a: u32, b: u32) -> u32 {
    if a > b { a } else { b }
}

pub fn min(a: u32, b: u32) -> u32 {
    if a < b { a } else { b }
}

/// Calculates trapped rainwater using brute force approach.
/// 
/// Time: O(n²) - for each element, scans left and right
/// Space: O(1) - only uses fixed number of variables
/// 
/// Algorithm: For each position, find maximum height to the left
/// and right, then calculate water level as min of those maxes
/// minus the current height.
pub fn trap_brute_force(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }
    
    let mut total_water: u32 = 0;
    let n = height.len();
    
    let mut i: u32 = 1;
    while i < n - 1 {
        // Find max height to the left
        let mut left_max: u32 = 0;
        let mut j: u32 = 0;
        while j < i {
            left_max = max(left_max, *height.at(j));
            j += 1;
        };
        
        // Find max height to the right
        let mut right_max: u32 = 0;
        let mut k: u32 = i + 1;
        while k < n {
            right_max = max(right_max, *height.at(k));
            k += 1;
        };
        
        // Calculate water at this position
        let water_level = min(left_max, right_max);
        let current_height = *height.at(i);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        
        i += 1;
    };
    
    total_water
}

/// Calculates trapped rainwater using dynamic programming approach.
/// 
/// Time: O(n) - three passes through array
/// Space: O(n) - stores left_max and right_max arrays
/// 
/// Algorithm: Pre-compute maximum heights from left and right for
/// each position, then calculate water level at each position.
pub fn trap_dp(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }
    
    let n = height.len();
    
    // Build left_max array
    let mut left_max: Array<u32> = array![];
    let mut current_max: u32 = 0;
    let mut i: u32 = 0;
    while i < n {
        current_max = max(current_max, *height.at(i));
        left_max.append(current_max);
        i += 1;
    };
    
    // Build right_max array
    let mut right_max: Array<u32> = array![];
    current_max = 0;
    let mut j = n;
    while j > 0 {
        j -= 1;
        current_max = max(current_max, *height.at(j));
        right_max.append(current_max);
    };
    
    // Reverse right_max to correct order
    let mut right_max_correct: Array<u32> = array![];
    let mut k = n;
    while k > 0 {
        k -= 1;
        right_max_correct.append(*right_max.at(k));
    };
    
    // Calculate trapped water
    let mut total_water: u32 = 0;
    let mut idx: u32 = 0;
    while idx < n {
        let water_level = min(*left_max.at(idx), *right_max_correct.at(idx));
        let current_height = *height.at(idx);
        if water_level > current_height {
            total_water += water_level - current_height;
        }
        idx += 1;
    };
    
    total_water
}

/// Calculates trapped rainwater using two-pointer technique.
/// 
/// Time: O(n) - single pass through array
/// Space: O(1) - only uses fixed number of variables
/// 
/// Algorithm: Maintain left/right pointers and track max heights seen
/// from each direction. Water at each position is bounded by the
/// smaller of the two maxes.
pub fn trap(height: @Array<u32>) -> u32 {
    if height.len() <= 2 {
        return 0;
    }
    
    let n = height.len();
    let mut left: u32 = 0;
    let mut right: u32 = n - 1;
    let mut left_max: u32 = 0;
    let mut right_max: u32 = 0;
    let mut total_water: u32 = 0;
    
    while left < right {
        if *height.at(left) <= *height.at(right) {
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
    };
    
    total_water
}

pub trait SolutionTrait {
    fn solve(input: @Array<u32>) -> u32;
}

pub impl SolutionImpl of SolutionTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap(input)
    }
}

/// Trait providing multiple algorithm variants for the trapped rainwater problem.
pub trait RainWaterTrait {
    /// O(n) time, O(1) space - OPTIMAL
    fn solve(input: @Array<u32>) -> u32;
    
    /// O(n²) time, O(1) space - educational only
    fn solve_brute_force(input: @Array<u32>) -> u32;
    
    /// O(n) time, O(n) space - for comparison
    fn solve_dp(input: @Array<u32>) -> u32;
    
    /// O(n) time, O(1) space - optimal two-pointer technique
    fn solve_two_pointers(input: @Array<u32>) -> u32;
}

pub impl RainWaterImpl of RainWaterTrait {
    fn solve(input: @Array<u32>) -> u32 {
        trap(input)
    }
    
    fn solve_brute_force(input: @Array<u32>) -> u32 {
        trap_brute_force(input)
    }
    
    fn solve_dp(input: @Array<u32>) -> u32 {
        trap_dp(input)
    }
    
    fn solve_two_pointers(input: @Array<u32>) -> u32 {
        trap(input)
    }
}
