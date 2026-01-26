# 017: felt252 String Length Limits

## Problem

Panic messages fail to compile when they exceed felt252's size limit:

```
error: The value does not fit within the range of type core::felt252.
 --> src/lib.cairo:381:54
    Option::None => core::panic_with_felt252('Incompatible matrix dimensions for addition'),
                                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

## Root Cause

In Cairo, `felt252` is a field element that can represent values up to approximately 2^251. When used for string literals (short strings), the maximum length is **31 ASCII characters**.

The panic message `'Incompatible matrix dimensions for addition'` is 45 characters - too long.

## Solutions

### Solution 1: Shorten the Message

```cairo
// TOO LONG (45 chars)
panic_with_felt252('Incompatible matrix dimensions for addition')

// OK (13 chars)
panic_with_felt252('dim mismatch')

// OK (11 chars)
panic_with_felt252('add: dims')
```

### Solution 2: Use panic! Macro with ByteArray

```cairo
// For longer messages, use panic! with ByteArray
panic!("Incompatible matrix dimensions for addition");

// Or with formatting
panic!("Matrix {}x{} incompatible with {}x{}", a.rows, a.cols, b.rows, b.cols);
```

### Solution 3: Use assert! Macro

```cairo
// assert! handles the panic automatically
assert!(self.cols == other.rows, "Matrix dimensions incompatible for multiplication");
```

## String Length Guidelines

| Length | Status | Example |
|--------|--------|---------|
| 1-31 chars | OK | `'dim mismatch'` |
| 32+ chars | ERROR | `'Incompatible matrix dimensions'` |

## Common Short Messages

```cairo
// Dimension errors
'dim mismatch'      // 12 chars
'bad dims'          // 8 chars
'size error'        // 10 chars

// Index errors
'out of bounds'     // 13 chars
'idx overflow'      // 12 chars

// Type errors
'type error'        // 10 chars
'invalid type'      // 12 chars

// Math errors
'div by zero'       // 11 chars
'overflow'          // 8 chars
'underflow'         // 9 chars

// Generic
'failed'            // 6 chars
'error'             // 5 chars
'invalid'           // 7 chars
```

## Operator Trait Panics

When implementing operator traits that need to panic on invalid input:

```cairo
impl MatrixAdd<T, ...> of Add<Matrix<T>> {
    fn add(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        // Option 1: Short felt252 message
        match MatrixTrait::add(@lhs, @rhs) {
            Option::Some(result) => result,
            Option::None => panic_with_felt252('add: dims'),
        }

        // Option 2: panic! macro
        match MatrixTrait::add(@lhs, @rhs) {
            Option::Some(result) => result,
            Option::None => panic!("Matrix add failed: dimension mismatch"),
        }
    }
}
```

## Counting Characters

```bash
# Quick check in bash
echo -n "your message here" | wc -c

# In Python
len("your message here")
```

## Skill Update

Consider adding to cairo-quirks:

```markdown
### felt252 Short String Limits

Panic messages using `panic_with_felt252('...')` are limited to 31 characters:

\`\`\`cairo
// WRONG - 45 characters
panic_with_felt252('Incompatible matrix dimensions for addition')

// CORRECT - 12 characters
panic_with_felt252('dim mismatch')

// ALTERNATIVE - use panic! for longer messages
panic!("Matrix dimensions incompatible for multiplication");
\`\`\`
```

## Implementation Status

- [x] Documented the 31-char limit
- [x] Provided common short messages
- [x] Showed alternative approaches
- [ ] Add to cairo-quirks skill
- [ ] Create message shortening helper
- [ ] Add lint rule for long felt252 strings
