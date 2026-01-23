# Prompt ID: cairo-merge-k-sorted-lists-01

Task:
- Write a Cairo `lib.cairo` that merges k sorted arrays into one sorted array.

Problem:
You are given an array of k arrays, where each inner array is sorted in ascending order.
Merge all arrays into one sorted array and return it.

Examples:
- Input: `[[1,4,5], [1,3,4], [2,6]]` → Output: `[1,1,2,3,4,4,5,6]`
- Input: `[]` → Output: `[]`
- Input: `[[]]` → Output: `[]`

Requirements:
- Define a function `merge_k_sorted(lists: Array<Array<i32>>) -> Array<i32>` that merges all sorted arrays.
- The function must handle empty input (no arrays) and arrays containing empty arrays.
- The output must be sorted in ascending order.
- Use generics where appropriate to demonstrate understanding of Cairo's type system.

Constraints:
- 0 <= k <= 100 (number of arrays)
- 0 <= lists[i].length <= 500
- -10000 <= lists[i][j] <= 10000
- Each `lists[i]` is sorted in ascending order.
- Must compile as a library file.
- Tests are required covering: normal merge, empty input, input with empty arrays, single array, arrays with duplicates.

Technical Notes:
- Cairo arrays are immutable; use `Array<T>` with `append` to build results.
- Consider using a helper function to merge two sorted arrays, then apply it iteratively or use divide-and-conquer.
- Generic implementations need proper trait bounds (e.g., `+Drop<T>`, `+Copy<T>`, `+PartialOrd<T>`).

Deliverable:
- Only the code for `src/lib.cairo`.
