# Rubric for cairo-merge-k-sorted-lists-01

Pass if:
- The file compiles with `scarb build`.
- All tests pass with `snforge test`.
- `merge_k_sorted(lists: Array<Array<i32>>) -> Array<i32>` function exists.
- Merging `[[1,4,5], [1,3,4], [2,6]]` returns `[1,1,2,3,4,4,5,6]`.
- Empty input `[]` returns `[]`.
- Input with empty arrays `[[]]` returns `[]`.
- Single array input returns the same array.
- Duplicates across arrays are preserved in output.
- Output is sorted in ascending order.

Fail if:
- Code does not compile.
- Tests fail or are missing.
- Function signature does not match requirements.
- Output is not sorted.
- Empty cases are not handled correctly.
- Duplicates are lost or miscounted.
