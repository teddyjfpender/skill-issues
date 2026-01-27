# Prompt ID: cairo-<topic>-01

Task:
- <One-line description of what to build>

## Problem Description

<Detailed problem statement. Be specific about inputs, outputs, and behavior.>

**Example 1:**
- Input: <input>
- Output: <output>
- Explanation: <why this is the expected output>

**Example 2:**
- Input: <input>
- Output: <output>

## Related Skills
- `cairo-quirks`
- `cairo-quality`

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
- Create helper functions as needed
- Functions should be standalone (not in a trait)

**Validation:** Code compiles with `scarb build`

---

## Step 2: Core Implementation

Implement the main algorithm.

**Requirements:**
- Create function `<function_name>(input: @Array<u32>) -> u32`
- <Describe the algorithm approach>
- Handle empty array (return 0)

**Validation:** Code compiles with `scarb build`

---

## Step 3: Optimized Solution (Optional)

Implement a more efficient version if applicable.

**Requirements:**
- Create function `<function_name>_optimized(input: @Array<u32>) -> u32`
- <Complexity requirement: O(n) time, O(1) space>
- Handle empty array (return 0)

**Validation:** Code compiles with `scarb build`

---

## Step 4: Public Interface and Trait

Create a clean public interface.

**Requirements:**
- Create trait `<Name>Trait` with method signatures
- Create impl `<Name>Impl` implementing the trait
- Add a `solve` method that uses the optimal solution

**Validation:** Code compiles with `scarb build`

---

## Step 5: Comprehensive Tests

Create tests covering all cases.

**Requirements:**
- Test Example 1: <input> -> <expected>
- Test Example 2: <input> -> <expected>
- Test empty array -> 0
- Test single element -> <expected>
- Test edge case: <description> -> <expected>

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use `u32` for all numeric values
- Handle edge cases (empty, single element, etc.)

## Deliverable

Complete `src/lib.cairo` with:
1. Helper functions
2. Algorithm implementation(s)
3. Clean trait interface
4. Comprehensive test suite
