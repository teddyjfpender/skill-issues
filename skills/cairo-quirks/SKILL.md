---
name: cairo-quirks
description: Document Cairo language quirks, gotchas, and idiomatic workarounds; use when encountering unexpected compilation errors or behaviors in Cairo that differ from Rust.
---

# Cairo Quirks

## Overview
Cairo has Rust-like syntax but differs in important ways. This skill documents common gotchas and their workarounds.

## Quick Use
- Read `references/quirks.md` for the full list.
- Most issues have simple workarounds once you know them.
- When stuck, check if the issue is on this list before debugging further.

## Response Checklist

### Operator Limitations
- **No bit shift operators** (`>>`, `<<`): Use division/multiplication by power-of-2 constants.
- **Unary negation parsing**: In some contexts, use `0_i32 - value` instead of `-value`.

### Array/Collection Issues
- **No runtime array indexing**: Can't do `arr[i]` with runtime `i` on `[T; N]`. Use `.span().get(i)`.
- **Span for iteration**: Convert fixed-size arrays to Span before iteration with `.span()`.

## Array Initialization and Usage

**CRITICAL: Cairo arrays are append-only queues, NOT random-access mutable arrays.**

### Initialization
```cairo
// CORRECT ways to create arrays:
let arr: Array<u32> = array![];           // Empty array
let arr: Array<u32> = array![1, 2, 3];    // With initial values
let arr: Array<u32> = ArrayTrait::new();  // Alternative empty

// WRONG - these do NOT exist in Cairo:
let arr = ArrayDefault::default();  // NO
let arr = Array::new();             // NO
let arr = Vec::new();               // NO (Vec doesn't exist)
```

### Array Operations
```cairo
// Adding elements (append-only)
arr.append(value);        // Add to end
arr.append_span(span);    // Add multiple

// Reading elements
let val = *arr.at(index); // Get by index (returns snapshot, must dereference)
let len = arr.len();      // Get length

// Removing elements
let val = arr.pop_front(); // Remove from front, returns Option<T>

// WRONG - these do NOT exist:
arr.set(index, value);    // NO random access write
arr[index] = value;       // NO assignment by index
arr.push(value);          // NO (use append)
arr.pop();                // NO (use pop_front)
```

### Common Pattern: "Updating" Array Values
Since Cairo arrays can't be modified in place, use these patterns:

```cairo
// Pattern 1: Rebuild array (simple but O(n))
let mut new_arr: Array<u32> = array![];
let mut i: u32 = 0;
while i < arr.len() {
    if i == target_index {
        new_arr.append(new_value);
    } else {
        new_arr.append(*arr.at(i));
    }
    i += 1;
};

// Pattern 2: Pop and append (for queue-like usage)
let _discarded = arr.pop_front().unwrap();
arr.append(new_value);
```

### Scope and Declarations
- **No `use` in functions**: Import statements must be at module level, not inside functions.
- **No variables named `type`**: Reserved keyword, even in lowercase.

### Trait and Method Issues
- **Ambiguous `unwrap`**: When compiler says "ambiguous", use `OptionTrait::unwrap(x)` explicitly.
- **PartialEq takes snapshots**: `fn eq(lhs: @Self, rhs: @Self)` - use `*` to dereference.
- **Trait methods need import**: Bring trait into scope to call its methods.

### Numeric Types
- **No implicit conversions**: Use `.into()` or `.try_into().unwrap()` explicitly.
- **i32 for comparisons**: Return `i32` from comparison functions, not `bool`.
- **felt252 is not an integer**: Different semantics, be careful with arithmetic.

### Testing
- **Assert messages must be literals**: `assert!(x, "msg")` not `assert!(x, variable)`.
- **Tests need `#[test]` attribute**: Don't forget the attribute above test functions.
- **DO NOT use `#[available_gas(n)]`**: This is deprecated. Remove it entirely; snforge handles gas automatically.

### Memory and Ownership (CRITICAL)
- **Snapshot field access**: When `self: @T`, all fields become `@Field`. Use `*self.field` to dereference.
- **Common error**: `Expected u32, found @u32` means you need to dereference with `*`.
- **Pattern**: `if row >= *self.rows` not `if row >= self.rows`.

## Example Requests
- "Why does my bit shift not compile in Cairo?"
- "Why can't I index my array with a variable?"
- "Why is `unwrap` ambiguous?"

## Cairo by Example
- [Operators](https://cairo-by-example.xyz/primitives/operators)
- [Arrays](https://cairo-by-example.xyz/primitives/array)
- [Traits](https://cairo-by-example.xyz/trait)
