# Cairo Tooling Skill

Guidelines for using Scarb's built-in tools for code quality.

## Formatting with `scarb fmt`

- Run `scarb fmt` to format Cairo code
- Run `scarb fmt --check` to verify formatting without changes
- Formatting is enforced in CI/validation

## Linting with `scarb lint`

- Run `scarb lint` to check for common issues
- Cairo Lint catches: unused variables, deprecated patterns, style issues
- Fix all lint warnings before submitting code

## Best Practices

- Always format before committing
- Run lint as part of validation
- Address warnings, not just errors
