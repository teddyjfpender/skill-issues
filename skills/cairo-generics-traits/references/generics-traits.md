# Cairo Generics and Traits Reference

Source: https://www.starknet.io/cairo-book/ch08-00-generic-types-and-traits.html

## Core ideas
- Generics are placeholders for concrete types and reduce code duplication.
- The compiler monomorphizes generics: it generates a concrete implementation for each type used.
- Monomorphization can increase compiled code size, which can matter for Starknet contracts.

## Traits and bounds
- Traits define shared behavior across types.
- Combine traits with generics to constrain which types are accepted by a function or struct.
