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

## Scaffolding Script (Using `scarb new`)

**Note:** We now use `scarb new` instead of manual file creation. This ensures:
- Proper project structure matching Scarb conventions
- Correct default `Scarb.toml` with latest edition
- Sample code that validates the toolchain works
- Pre-configured snforge_std dependency and test scripts

Reference: https://docs.swmansion.com/scarb/docs/guides/creating-a-new-package.html

```bash
scaffold_project() {
  local project_dir="$1"
  local project_name="${2:-cairo_project}"

  # Use scarb new to create project structure
  if [[ -d "$project_dir" ]]; then
    log_warn "Project directory already exists, skipping scaffold"
    return 0
  fi

  local parent_dir=$(dirname "$project_dir")
  mkdir -p "$parent_dir"

  log_info "Scaffolding project with scarb new at $project_dir..."

  # Create new project with scarb
  # --no-vcs: avoid nested git repos
  # --test-runner=starknet-foundry: includes snforge_std, test scripts, snfoundry.toml
  (cd "$parent_dir" && scarb new "$project_name" --no-vcs --test-runner=starknet-foundry) || {
    log_error "Failed to create project with scarb new"
    return 1
  }

  log_ok "Project scaffolded with scarb new"
  return 0
}
```

### What `--test-runner=starknet-foundry` provides:
- `snforge_std` dependency pre-configured
- `snfoundry.toml` configuration file
- `tests/` directory with sample test
- `[scripts] test = "snforge test"` in Scarb.toml
- `starknet` dependency for contract development

### Key `scarb new` options:
- `--no-vcs` — Skip Git repository initialization (useful when inside existing repo)
- `--name <name>` — Use different package name than directory name
- `--test-runner=starknet-foundry` — Create with Starknet Foundry testing setup (required for non-interactive mode)

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
  local work_dir="$1"
  local error_file="$2"

  log_info "Verifying project setup..."

  # Check required files exist (scarb-generated structure)
  if [[ ! -f "$work_dir/Scarb.toml" ]]; then
    log_error "Missing Scarb.toml"
    return 1
  fi

  if [[ ! -f "$work_dir/src/lib.cairo" ]]; then
    log_error "Missing src/lib.cairo"
    return 1
  fi

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Verify scarb fmt --check works (checks formatting config)
  log_info "Checking formatting configuration..."
  if ! (cd "$work_dir" && scarb fmt --check 2>&1) > "$error_file" 2>&1; then
    log_warn "Formatting check failed (non-fatal)"
    # Non-fatal - continue with verification
  fi

  # Verify project builds
  log_info "Verifying project builds..."
  if ! (cd "$work_dir" && scarb build 2>&1) > "$error_file" 2>&1; then
    log_error "Project failed initial build check"
    cat "$error_file"
    return 1
  fi

  log_ok "Project setup verified"
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
- [x] Integrate scaffold into step-loop (scaffold_project and verify_project_setup functions)
- [x] Create project templates per task type (using `scarb new` instead of manual scaffolding)
- [ ] Add automatic dependency updates
