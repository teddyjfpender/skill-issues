# Rubric for <prompt-id>

Pass if:
- The file compiles with `scarb build`
- `<StructName>` struct exists with required fields
- `<TraitName>` trait exists with required methods
- `<ImplName>` implements `<TraitName>` correctly
- `<function_name>` produces correct output for examples
- Tests pass with `snforge test`

Fail if:
- Code does not compile
- Required struct/trait/impl is missing
- Implementation does not match specification
- Edge cases are not handled (empty input, single element, etc.)

Notes:
- <Any additional context or edge cases to check>
