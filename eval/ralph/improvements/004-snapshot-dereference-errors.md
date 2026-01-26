# Feature Improvement: Cairo Snapshot Dereferencing Guidance

**ID**: 004
**Status**: Open
**Priority**: High
**Created**: 2026-01-26

## Problem

Attempt 1 generated code with 34 build errors, primarily related to Cairo snapshot type handling. The driver didn't properly dereference snapshot fields (`@T`) when passing to functions expecting owned values (`T`).

## Error Pattern

All 34 errors were variations of:
```
error: Unexpected argument type. Expected: "core::integer::u32", found: "@core::integer::u32".
--> src/lib.cairo:105:19
    if row >= self.rows || col >= self.cols {
              ^^^^^^^^^
```

## Root Cause

In Cairo, when a method takes `self: @Matrix<T>` (snapshot), all fields become snapshots:
- `self.rows` is `@u32`, not `u32`
- Must dereference with `*self.rows` to get `u32`

The driver generated:
```cairo
fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> {
    if row >= self.rows || col >= self.cols {  // ERROR: self.rows is @u32
        return None;
    }
    let idx = index(row, col, self.cols);  // ERROR: self.cols is @u32
    ...
}
```

Should have been:
```cairo
fn get(self: @Matrix<T>, row: u32, col: u32) -> Option<@T> {
    if row >= *self.rows || col >= *self.cols {  // Dereference with *
        return None;
    }
    let idx = index(row, col, *self.cols);  // Dereference with *
    ...
}
```

## Proposed Solutions

### Option A: Add to cairo-quirks Skill
Extend `skills/cairo-quirks/references/quirks.md` with a section on snapshot dereferencing:

```markdown
### Snapshot Field Access

When a method takes `self: @T`, all struct fields become snapshots:

```cairo
// WRONG - self.field is @Type, not Type
fn method(self: @MyStruct) -> u32 {
    self.field  // Returns @u32, not u32
}

// CORRECT - dereference with *
fn method(self: @MyStruct) -> u32 {
    *self.field  // Returns u32
}
```

### Option B: Dedicated Snapshot Skill
Create `skills/cairo-snapshots/` with comprehensive snapshot handling guidance.

### Option C: Enhanced Feedback Extraction
Improve `extract-feedback.py` to detect this pattern and provide specific hints:
```
Hint: When using snapshot self (@Type), dereference fields with * to get owned values.
Example: Use *self.rows instead of self.rows
```

## Recommendation

Implement Option A immediately (quick fix) and Option C for better iteration feedback.

## Related Files

- `skills/cairo-quirks/references/quirks.md`
- `eval/ralph/extract-feedback.py`
