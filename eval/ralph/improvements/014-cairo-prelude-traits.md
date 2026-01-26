# 014: Cairo Prelude Traits - Import Guidance

## Problem

Generated Cairo code frequently fails with "Identifier not found" errors when trying to import traits that are actually in the prelude:

```cairo
use core::ops::{Add, Mul, Sub};  // ERROR: Identifier not found
```

The LLM assumes Rust-like import patterns where operator traits need explicit imports.

## Root Cause

Cairo's prelude automatically includes many common traits. Unlike Rust where you might import `std::ops::Add`, Cairo has these available globally.

## Traits in Cairo's Prelude (DO NOT IMPORT)

### Operator Traits
- `Add`, `Sub`, `Mul`, `Div` - Arithmetic operators
- `Neg` - Unary negation
- `BitAnd`, `BitOr`, `BitXor` - Bitwise operators
- `Not` - Logical not

### Comparison Traits
- `PartialEq`, `Eq` - Equality comparison
- `PartialOrd`, `Ord` - Ordering comparison

### Memory Traits
- `Drop` - Resource cleanup
- `Copy` - Bitwise copy
- `Clone` - Deep copy

### Conversion Traits
- `Into`, `TryInto` - Type conversions
- `From`, `TryFrom` - Reverse conversions

### Core Types
- `Option`, `Some`, `None` - Optional values
- `Result`, `Ok`, `Err` - Error handling
- `bool`, `true`, `false` - Booleans

## Traits That DO Need Import

```cairo
// Numeric traits
use core::num::traits::{Zero, One};
use core::num::traits::{Sqrt, Pow2};

// Array operations
use core::array::{Array, ArrayTrait, SpanTrait};

// Option/Result operations (if calling methods explicitly)
use core::option::OptionTrait;
use core::result::ResultTrait;

// Hash operations
use core::hash::{Hash, HashStateTrait};
```

## Correct Usage Patterns

### Implementing Operator Traits
```cairo
// NO import needed for Add
impl MatrixAdd<T, +Drop<T>, +Copy<T>, +Add<T>> of Add<Matrix<T>> {
    fn add(lhs: Matrix<T>, rhs: Matrix<T>) -> Matrix<T> {
        // Implementation
    }
}
```

### Using Zero/One (NEED import)
```cairo
use core::num::traits::{Zero, One};

fn zeros<T, +Zero<T>>(count: u32) -> Array<T> {
    let mut arr = ArrayTrait::new();
    let mut i = 0_u32;
    while i < count {
        arr.append(Zero::zero());  // Requires import
        i += 1;
    };
    arr
}
```

### Generic Trait Bounds
```cairo
// Trait bounds reference prelude traits without imports
impl MatrixImpl<
    T,
    +Drop<T>,      // Prelude - no import
    +Copy<T>,      // Prelude - no import
    +Add<T>,       // Prelude - no import
    +Sub<T>,       // Prelude - no import
    +Mul<T>,       // Prelude - no import
    +Zero<T>,      // Needs: use core::num::traits::Zero
    +One<T>,       // Needs: use core::num::traits::One
> of MatrixTrait<T> {
    // ...
}
```

## Skill Update

Added to `cairo-quirks/references/quirks.md`:

```markdown
### Traits in the Prelude (DO NOT IMPORT)

These traits are in Cairo's prelude and available automatically - do NOT import them:

\`\`\`cairo
// WRONG - will cause "Identifier not found" error
use core::ops::{Add, Mul, Sub};  // Error!

// CORRECT - use directly without import
impl MyTypeAdd of Add<MyType> {
    fn add(lhs: MyType, rhs: MyType) -> MyType { ... }
}
\`\`\`
```

## Impact

This issue caused Step 1 to fail 3 times with Codex before we identified the pattern. Adding clear guidance to the skill and prompt prevented future failures.

## Implementation Status

- [x] Updated cairo-quirks skill with prelude guidance
- [x] Added explicit import guidance to step-loop prompts
- [x] Listed traits that DO need import
- [x] Tested with matrix algebra prompt
- [ ] Add linter to detect incorrect imports
- [ ] Create import cheat sheet for prompts
