# Rubric for cairo-generics-traits-01

Pass if:
- The file compiles with `scarb build`.
- `Pair<T>` is generic and contains `first` and `second` fields of type `T`.
- A generic trait `Swap<T>` exists with `swap(self: Pair<T>) -> Pair<T>`.
- There is an implementation of `Swap<T>` for `Pair<T>` that swaps the two fields.
- `fn demo() -> Pair<u32>` constructs a pair and uses the swap behavior.

Fail if:
- The trait or impl is missing or not generic.
- The swap implementation does not swap fields.
- `demo` is missing or does not call the swap behavior.
