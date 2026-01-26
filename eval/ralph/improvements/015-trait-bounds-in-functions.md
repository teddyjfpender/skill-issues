# 015: Trait Bounds in Standalone Functions

## Problem

Standalone generic functions that call trait methods fail with:
```
Method `get_unchecked` could not be called on type `@Matrix<T>`.
Candidate `MatrixTrait::get_unchecked` inference failed with:
Trait has no implementation in context: MatrixTrait<T>.
```

## Root Cause

When a generic implementation like `MatrixImpl` has trait bounds:
```cairo
impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T>
```

A standalone function calling methods from that impl MUST have the same bounds:
```cairo
// FAILS: Missing bounds that MatrixImpl requires
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    let val = *matrix.get_unchecked(row, col);  // ERROR!
}
```

Cairo can't resolve `get_unchecked` because it doesn't know which `MatrixTrait<T>` impl to use - the bounds don't match.

## Solutions

### Solution 1: Include All Required Bounds

```cairo
// Include ALL bounds from MatrixImpl
pub fn matrix_vector_mul<
    T,
    +Drop<T>,
    +Copy<T>,
    +Add<T>,
    +Sub<T>,    // Added
    +Mul<T>,
    +Zero<T>,
    +One<T>,    // Added
>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    let val = *matrix.get_unchecked(row, col);  // Works!
}
```

### Solution 2: Access Data Directly (Avoid Trait Methods)

```cairo
// Don't call trait methods - access struct fields directly
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Mul<T>, +Zero<T>>(
    matrix: @Matrix<T>, vector: @Vector<T>
) -> Option<Vector<T>> {
    // Direct field access instead of get_unchecked()
    let idx = row * *matrix.cols + col;
    let val = *matrix.data.at(to_usize(idx));  // Works with fewer bounds!
}
```

### Solution 3: Make Function a Trait Method

```cairo
// Add to MatrixTrait
trait MatrixTrait<T> {
    // ... existing methods ...
    fn mul_vector(self: @Matrix<T>, vector: @Vector<T>) -> Option<Vector<T>>;
}

// Implement in MatrixImpl - automatically has all bounds
impl MatrixImpl<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>> of MatrixTrait<T> {
    fn mul_vector(self: @Matrix<T>, vector: @Vector<T>) -> Option<Vector<T>> {
        let val = *self.get_unchecked(row, col);  // Works!
    }
}
```

## Decision Guide

| Approach | Pros | Cons |
|----------|------|------|
| All bounds | Simple, uses trait methods | Function signature gets long |
| Direct access | Minimal bounds | Bypasses trait abstraction |
| Trait method | Clean API | Requires modifying trait |

## Skill Update

Added to `cairo-quirks/references/quirks.md`:

```markdown
### Standalone Functions Using Trait Methods

**CRITICAL**: If a standalone function needs to call trait methods, it must
include ALL the trait bounds required by that trait's impl.

\`\`\`cairo
// WRONG - missing bounds needed by MatrixImpl
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>>(...)

// CORRECT - include ALL bounds, or access data directly
pub fn matrix_vector_mul<T, +Drop<T>, +Copy<T>, +Add<T>, +Sub<T>, +Mul<T>, +Zero<T>, +One<T>>(...)
\`\`\`
```

## Impact

This issue caused Step 7 to fail multiple times. The generated code was logically correct but had insufficient trait bounds. Adding this guidance to the skill helped subsequent generations.

## Implementation Status

- [x] Documented the issue in cairo-quirks
- [x] Added examples of all three solutions
- [x] Tested with matrix_vector_mul function
- [ ] Add trait bound analyzer to detect mismatches
- [ ] Create trait bound cheat sheet
