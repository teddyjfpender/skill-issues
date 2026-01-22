# Cairo Testing Reference

Source: https://book.cairo-lang.org/ch10-01-how-to-write-tests.html

## Basics
- Tests are functions annotated with `#[test]`.
- Unit tests in `src` should live in a `#[cfg(test)] mod tests` module.
- Use `use super::*;` inside the tests module to access code under test.

## Assert macros
- `assert!`, `assert_eq!`, `assert_ne!`, `assert_lt!`, `assert_le!`, `assert_gt!`, `assert_ge!`.
- Use `assert_macros = "2.8.2"` as a dev dependency to access the comparison macros.
- Optional custom messages are passed like `assert!(cond, "message")`.

## Panic tests
- `#[should_panic]` marks tests that must panic.
- `#[should_panic(expected: "...")]` checks the panic message contains the expected text.

## Running tests
- `scarb test` runs all tests.
- `scarb test <name>` runs tests whose names match the string.
- `#[ignore]` marks slow tests; run them with `scarb test --include-ignored`.

## Gas limits
- Tests have a default gas limit; override with `#[available_gas(<N>)]` for recursion or loops.
