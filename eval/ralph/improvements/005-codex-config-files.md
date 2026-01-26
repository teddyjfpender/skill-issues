# Feature Improvement: Codex Configuration Files for Driver/Reviewer

**ID**: 005
**Status**: Fixed
**Priority**: High
**Created**: 2026-01-26
**Fixed**: 2026-01-26

## Problem

The ralph-loop currently invokes Codex without specifying a configuration file (`codex.toml`). This means:
1. Skills paths are not properly configured
2. Features like web search are not enabled/disabled as needed
3. Model-specific settings are not applied
4. Driver and reviewer cannot have different configurations

## Proposed Solution

Create a config directory structure with separate `codex.toml` files for driver and reviewer:

```
eval/ralph/config/
  driver/
    codex.toml
  reviewer/
    codex.toml
```

### Driver Configuration Example

```toml
# eval/ralph/config/driver/codex.toml

[model]
default = "o3"  # or specified via CLI

[features]
web_search_request = false  # Driver shouldn't need web search
auto_context = true

[skills]
# Path to skills directory relative to repo root
additional_paths = ["skills"]

[output]
# Structured output settings
format = "json"
```

### Reviewer Configuration Example

```toml
# eval/ralph/config/reviewer/codex.toml

[model]
default = "o3"

[features]
web_search_request = false
auto_context = false  # Reviewer gets all context in prompt

[skills]
additional_paths = ["skills"]

[output]
format = "json"
```

## Implementation Changes

### Option A: Config File Path Flag

Update `ralph-loop.sh` to accept config directory:

```bash
eval/ralph/ralph-loop.sh \
  --prompt cairo-matrix-algebra-01 \
  --config-dir eval/ralph/config \
  ...
```

Then pass to Codex:
```bash
codex exec \
  --config "${CONFIG_DIR}/driver/codex.toml" \
  -m "$DRIVER_MODEL" \
  ...
```

### Option B: Inline Config Overrides (Current Isabelle Approach)

Pass config options via `-c` flags:

```bash
local codex_opts=(-m "$MODEL")
codex_opts+=(-c "features.web_search_request=false")
codex_opts+=(-c "skills.additional_paths=[\"${SKILLS_DIR}\"]")

codex exec "${codex_opts[@]}" ...
```

### Option C: Hybrid (Recommended)

Use config files as base, allow CLI overrides:

```bash
codex exec \
  --config "${CONFIG_DIR}/driver/codex.toml" \
  -c "model.default=${DRIVER_MODEL}" \
  ...
```

## Reference: Isabelle Harness Pattern

From the working Isabelle harness:

```bash
run_ai_command() {
    local prompt="$1"
    local output_file="$2"
    local stderr_file="$3"
    local stream="$4"

    case "$PROVIDER" in
        openai)
            if command -v codex &> /dev/null; then
                local skills_dir="${PROJECT_ROOT}/.codex/skills"
                local codex_opts=(-m "$MODEL")

                # Enable web search feature
                codex_opts+=(-c "features.web_search_request=true")

                # Add skills directory config if it exists
                if [[ -d "$skills_dir" ]]; then
                    codex_opts+=(-c "skills.additional_paths=[\"${skills_dir}\"]")
                fi

                echo "$prompt" | codex exec \
                    "${codex_opts[@]}" \
                    - \
                    2>"$stderr_file" > "$output_file"
            fi
            ;;
    esac
}
```

## Benefits

1. **Consistent skill loading**: Driver will find skills without searching wrong paths
2. **Reproducible runs**: Configuration is version-controlled
3. **Agent-specific settings**: Driver and reviewer can have different configs
4. **Easier debugging**: Clear what settings each agent uses

## Implementation Steps

1. Create `eval/ralph/config/` directory structure
2. Create template `codex.toml` files for driver and reviewer
3. Update `ralph-loop.sh` to accept `--config-dir` flag
4. Update Codex invocation to use config files
5. Document configuration options in README

## Fix Applied

Implemented Option B (Inline Config Overrides) following the Isabelle harness pattern.

### Changes to `ralph-loop.sh`

1. Added `role` parameter to `run_backend()` function (9th parameter)
2. Added role-specific config options:

```bash
# Driver: focus on code generation, no web search
if [[ "$role" == "driver" ]]; then
  args+=(-c "features.web_search_request=false")
  args+=(-c "features.auto_context=true")
elif [[ "$role" == "reviewer" ]]; then
  args+=(-c "features.web_search_request=false")
  args+=(-c "features.auto_context=false")
fi

# Add skills directory
if [[ -d "$script_dir/../../skills" ]]; then
  skills_dir="$(cd "$script_dir/../../skills" && pwd)"
  args+=(-c "skills.additional_paths=[\"${skills_dir}\"]")
fi
```

3. Updated both `run_backend` calls to pass the role:
   - Driver call: `"driver"`
   - Reviewer call: `"reviewer"`

### Template Config Files Created

Created `eval/ralph/config/` with template files for documentation:
- `driver/codex.toml` - driver configuration reference
- `reviewer/codex.toml` - reviewer configuration reference

These serve as documentation; the actual config is applied via `-c` flags.

## Related Files

- `eval/ralph/ralph-loop.sh` - added config flags to run_backend
- `eval/ralph/config/driver/codex.toml` - template
- `eval/ralph/config/reviewer/codex.toml` - template

## Related Issues

- 003-skill-path-confusion.md (driver can't find skills)
- 001-driver-performance.md (proper config may improve focus)
