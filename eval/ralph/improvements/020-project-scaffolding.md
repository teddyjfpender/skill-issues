# 020: Project Scaffolding and Setup

## Problem

The initial project setup affects generation success:
- Missing dependencies cause build failures
- Wrong Cairo edition causes syntax errors
- Empty lib.cairo needs proper placeholder
- Test framework configuration affects test steps

## Recommended Scarb.toml

```toml
[package]
name = "project_name"
version = "0.1.0"
edition = "2024_07"  # Latest stable edition

[cairo]
enable-gas = true    # Required for gas tracking

[scripts]
test = "snforge test"

[dependencies]
# snforge for testing
snforge_std = "0.55.0"

# Optional: cairo_execute for executable contracts
# cairo_execute = "2.14.0"
```

## Edition Selection

| Edition | Cairo Version | Notes |
|---------|--------------|-------|
| `2023_01` | 1.x | Legacy, avoid |
| `2023_10` | 2.0-2.3 | Older stable |
| `2024_01` | 2.4-2.6 | Stable |
| `2024_07` | 2.7+ | Latest stable, recommended |

## Initial lib.cairo

```cairo
// Placeholder - will be replaced by generated code
```

Or with minimal structure:
```cairo
// Project: {project_name}
// Generated code will be placed here

#[cfg(test)]
mod tests {
    // Tests will be added here
}
```

## Scaffolding Script

```bash
scaffold_project() {
  local project_dir="$1"
  local project_name="$2"

  # Create directory structure
  mkdir -p "$project_dir/src"
  mkdir -p "$project_dir/tests"

  # Create Scarb.toml
  cat > "$project_dir/Scarb.toml" <<EOF
[package]
name = "$project_name"
version = "0.1.0"
edition = "2024_07"

[cairo]
enable-gas = true

[scripts]
test = "snforge test"

[dependencies]
snforge_std = "0.55.0"
EOF

  # Create placeholder lib.cairo
  echo "// placeholder" > "$project_dir/src/lib.cairo"

  # Initialize snforge (creates snfoundry.toml)
  (cd "$project_dir" && snforge init --force 2>/dev/null || true)

  # Verify setup
  (cd "$project_dir" && scarb build 2>/dev/null)
}
```

## snfoundry.toml

If using snforge features, create:
```toml
[snforge]
exit_first = false  # Continue on first failure

[fuzzer]
runs = 256
seed = 0
```

## Pre-Generation Checks

```bash
verify_project_setup() {
  local project_dir="$1"

  # Check Scarb.toml exists
  if [[ ! -f "$project_dir/Scarb.toml" ]]; then
    log_error "Missing Scarb.toml"
    return 1
  fi

  # Check edition
  local edition=$(grep "edition" "$project_dir/Scarb.toml" | cut -d'"' -f2)
  if [[ "$edition" < "2024_01" ]]; then
    log_warn "Old Cairo edition: $edition. Consider upgrading."
  fi

  # Check snforge dependency
  if ! grep -q "snforge_std" "$project_dir/Scarb.toml"; then
    log_warn "Missing snforge_std dependency"
  fi

  # Verify scarb works
  if ! (cd "$project_dir" && scarb build 2>/dev/null); then
    log_error "Project doesn't build cleanly"
    return 1
  fi

  return 0
}
```

## Directory Structure

```
project_name/
├── Scarb.toml           # Package manifest
├── snfoundry.toml       # snforge config (optional)
├── src/
│   └── lib.cairo        # Main source file
└── tests/               # Integration tests (optional)
    └── test_*.cairo
```

## Common Setup Issues

### Issue: Missing snforge_std
```
error: Package snforge_std not found
```
**Fix:** Add `snforge_std = "0.55.0"` to dependencies

### Issue: Old Edition
```
error: `while` loops are not supported
```
**Fix:** Update `edition = "2024_07"` in Scarb.toml

### Issue: Gas Not Enabled
```
error: Gas tracking required
```
**Fix:** Add `enable-gas = true` under `[cairo]`

## Integration with step-loop

```bash
# In step-loop.sh, before main loop
if ! verify_project_setup "$work_dir"; then
  log_error "Project setup invalid"
  exit 2
fi
```

## Implementation Status

- [x] Documented recommended Scarb.toml
- [x] Created scaffolding script
- [x] Listed common setup issues
- [x] Added pre-generation checks
- [ ] Integrate scaffold into step-loop
- [ ] Add automatic dependency updates
- [ ] Create project templates per task type
