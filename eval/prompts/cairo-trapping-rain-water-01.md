# Prompt ID: cairo-trapping-rain-water-01

Task:
- Implement the "Trapping Rain Water" algorithm (LeetCode #42 - Hard) in Cairo.

## Problem Description

Given `n` non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it can trap after raining.

**Example 1:**
- Input: height = [0,1,0,2,1,0,1,3,2,1,2,1]
- Output: 6
- Explanation: The elevation map (black bars) traps 6 units of rain water (blue section).

**Example 2:**
- Input: height = [4,2,0,3,2,5]
- Output: 9

## Related Skills
- `cairo-quirks`
- `cairo-arrays`

## Context

**CRITICAL - No Inherent Impls**: Cairo does NOT support Rust-style `impl Type { }`. All methods must use traits.

**Array Access**: Use `arr.at(index)` which returns a snapshot. Dereference with `*arr.at(i)`.

**Loops**: Use `while` loops with explicit index management. Cairo has no `for` loops.

**No usize**: Cairo uses `u32` for array indexing. Use `arr.len()` which returns `usize` but compare with `u32`.

---

## Step 1: Imports and Helper Functions

Set up imports and helper functions for the algorithm.

**Requirements:**
- Import necessary traits from core library
- Create a `max` helper function for u32 values
- Create a `min` helper function for u32 values
- Functions should be standalone (not in a trait)

**Validation:** Code compiles with `scarb build`

---

## Step 2: Brute Force Solution

Implement the O(n²) brute force approach.

**Requirements:**
- Create function `trap_brute_force(height: @Array<u32>) -> u32`
- For each element, find max height to left and right
- Water at index i = min(left_max, right_max) - height[i]
- Sum all water amounts
- Handle empty array (return 0)

**Validation:** Code compiles with `scarb build`

---

## Step 3: Dynamic Programming Solution

Implement the O(n) time, O(n) space DP approach.

**Requirements:**
- Create function `trap_dp(height: @Array<u32>) -> u32`
- Pre-compute left_max array (max height from left up to i)
- Pre-compute right_max array (max height from right up to i)
- Calculate water using both arrays
- Handle empty array (return 0)

**Validation:** Code compiles with `scarb build`

---

## Step 4: Two Pointer Solution (Optimal)

Implement the O(n) time, O(1) space optimal solution.

**Requirements:**
- Create function `trap(height: @Array<u32>) -> u32`
- Use two pointers (left and right) starting from ends
- Track left_max and right_max as you go
- Move pointer with smaller max inward, accumulating water
- Handle empty array (return 0)

**Validation:** Code compiles with `scarb build`

---

## Step 5: Public Interface and Trait

Create a clean public interface.

**Requirements:**
- Create trait `RainWaterTrait` with method signatures
- Create impl `RainWaterImpl` implementing the trait
- Include all three solutions as trait methods
- Add a `solve` method that uses the optimal solution

**Validation:** Code compiles with `scarb build`

---

## Step 6: Comprehensive Tests

Create tests covering all cases.

**Requirements:**
- Add `#[cfg(test)] mod tests { ... }`
- Test Example 1: [0,1,0,2,1,0,1,3,2,1,2,1] -> 6
- Test Example 2: [4,2,0,3,2,5] -> 9
- Test empty array -> 0
- Test single element -> 0
- Test two elements -> 0
- Test flat array [3,3,3,3] -> 0
- Test descending [5,4,3,2,1] -> 0
- Test ascending [1,2,3,4,5] -> 0
- Test V-shape [5,0,5] -> 5
- Verify all three solutions give same results

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use `u32` for all numeric values
- Handle edge cases (empty, single element, no water possible)
- All three algorithm variants must produce identical results

## Deliverable

Complete `src/lib.cairo` with:
1. Helper functions (min, max)
2. Three algorithm implementations (brute force, DP, two-pointer)
3. Clean trait interface
4. Comprehensive test suite
