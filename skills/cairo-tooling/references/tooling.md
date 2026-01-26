# Cairo Tooling Reference

## Formatting with `scarb fmt`

### Commands

```bash
# Format all Cairo files in the project
scarb fmt

# Check formatting without making changes (for CI)
scarb fmt --check

# Output formatted code to stdout without modifying files
scarb fmt --emit stdout

# Format specific packages
scarb fmt --package <package-name>

# Format entire workspace
scarb fmt --workspace
```

### Configuration

Add to `Scarb.toml`:

```toml
[tool.fmt]
sort-module-level-items = true   # Alphabetically sort imports (default: true)
max-line-length = 100            # Maximum line width (default: 100)
tab-size = 4                     # Spaces per tab (default: 4)
merge-use-items = true           # Consolidate use statements (default: true)
allow-duplicate-uses = false     # Permit duplicate use statements (default: false)
```

### Ignoring Files

Create `.cairofmtignore` file with `.gitignore` syntax to exclude paths.

### Skipping Specific Code

Use the `#[cairofmt::skip]` attribute to skip formatting individual statements:

```cairo
#[cairofmt::skip]
let very_long_initialization = SomeStruct { field1: value1, field2: value2, field3: value3 };
```

## Linting with `scarb lint`

### Commands

```bash
# Run linter on current project
scarb lint

# Auto-fix detected issues
scarb lint --fix

# Include test code in analysis
scarb lint --test

# Get help on available options
scarb lint --help
```

### Common Lint Rules

1. **Unnecessary boolean comparisons**
   - Bad: `if is_valid == true { ... }`
   - Good: `if is_valid { ... }`

2. **Unused variables**
   - Use underscore prefix for intentionally unused: `let _unused = value;`

3. **Deprecated patterns**
   - Follow lint suggestions to update to current idioms

4. **Style issues**
   - Naming conventions
   - Import organization
   - Code structure

### Suppressing Lint Warnings

For specific cases where lint warnings are intentional:

```cairo
#[allow(unused_variables)]
fn example(unused_param: felt252) {
    // ...
}
```

## CI/Validation Integration

### Recommended Validation Order

1. `scarb fmt --check` - Verify formatting
2. `scarb check` - Quick syntax validation
3. `scarb build` - Full compilation
4. `scarb lint` - Code quality checks
5. `snforge test` - Run tests

### Example CI Script

```bash
#!/bin/bash
set -e

# Check formatting
if ! scarb fmt --check; then
    echo "Formatting issues detected. Run 'scarb fmt' to fix."
    exit 1
fi

# Build
scarb build

# Lint (warn only, don't fail)
scarb lint || echo "Lint warnings detected"

# Test
snforge test
```

## Best Practices

1. **Format before commit**: Run `scarb fmt` before every commit
2. **Fix lint warnings**: Address all warnings, not just errors
3. **Use auto-fix**: Run `scarb lint --fix` for quick fixes
4. **Configure in project**: Add `[tool.fmt]` settings to `Scarb.toml`
5. **CI enforcement**: Use `scarb fmt --check` in CI pipelines
