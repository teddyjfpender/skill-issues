# Rubric for cairo-generics-traits-02

## Pass Criteria

### Structure (Required)
- [ ] `MinStack<T>` is a generic struct with at least two internal storage mechanisms
- [ ] `MinStackTrait<T>` is a generic trait with the specified method signatures
- [ ] Implementation includes appropriate generic bounds (`+Drop<T>`, `+Copy<T>`, `+PartialOrd<T>`, `+PartialEq<T>`)

### Core Operations (Required)
- [ ] `new()` creates an empty stack
- [ ] `push()` adds elements to the stack
- [ ] `pop()` removes and returns the top element (or None if empty)
- [ ] `peek()` returns the top element without removal (or None if empty)
- [ ] `is_empty()` correctly reports stack state

### Algorithm Correctness (Required)
- [ ] `get_min()` returns the minimum element currently in the stack
- [ ] `get_min()` is O(1) - implemented via auxiliary data structure, not iteration
- [ ] Minimum is correctly updated when the minimum value is popped
- [ ] Handles duplicate minimum values correctly (min doesn't change until all copies removed)

### Tests (Required)
- [ ] Test demonstrates push operations
- [ ] Test verifies get_min after pushes
- [ ] Test verifies get_min updates correctly after popping the minimum
- [ ] Test handles empty stack edge case (returns None)

### Compilation (Required)
- [ ] Code compiles with `scarb build`
- [ ] Tests pass with `snforge test`

## Fail Criteria

Fail if any of the following:
- [ ] `MinStack` or `MinStackTrait` is not generic
- [ ] `get_min()` iterates through all elements (O(n) implementation)
- [ ] Missing trait bounds cause compilation errors
- [ ] `get_min()` returns incorrect value after pop operations
- [ ] Duplicate minimums are not handled (popping one copy incorrectly changes min)
- [ ] No tests provided
- [ ] Code does not compile

## Scoring (Optional)

| Criteria | Points |
|----------|--------|
| Compiles | 20 |
| Generic struct + trait defined | 20 |
| Core operations work (push/pop/peek) | 20 |
| get_min is O(1) with correct algorithm | 30 |
| Comprehensive tests | 10 |
| **Total** | **100** |

## Example Correct Behavior

```
push(3) -> stack: [3], min_stack: [3], get_min: 3
push(5) -> stack: [3,5], min_stack: [3], get_min: 3
push(2) -> stack: [3,5,2], min_stack: [3,2], get_min: 2
push(2) -> stack: [3,5,2,2], min_stack: [3,2,2], get_min: 2
pop()   -> returns 2, stack: [3,5,2], min_stack: [3,2], get_min: 2
pop()   -> returns 2, stack: [3,5], min_stack: [3], get_min: 3
pop()   -> returns 5, stack: [3], min_stack: [3], get_min: 3
pop()   -> returns 3, stack: [], min_stack: [], get_min: None
```
