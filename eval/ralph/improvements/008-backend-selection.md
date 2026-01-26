# 008: Backend Selection and Performance

## Problem

The step-loop was extremely slow when using Codex backend with `exec` mode. A single step that should take 30 seconds was taking 3+ minutes, with the driver running 50+ search/exploration commands before generating any code.

## Root Cause

Codex `exec` mode is designed for complex, multi-step tasks where exploration is valuable. It:
- Automatically explores the codebase for context
- Runs grep, find, and other search commands
- Reads multiple files to understand patterns
- Has `auto_context=true` by default

This is counterproductive for code generation tasks where all context is provided in the prompt.

## Evidence

From step-loop output with Codex:
```
item_1: command_execution: rg "Zero" -n eval/work
item_3: command_execution: rg "Option" -n eval/work
item_5: command_execution: sed -n '1,40p' eval/work/...
... (50+ more commands before generating code)
```

From step-loop output with Claude CLI:
```
item_0: reasoning: "Preparing complete lib.cairo..."
item_1: agent_message: {"code": "..."}  // Immediate generation
```

## Solution

### 1. Add Claude Backend Support

```bash
run_claude() {
  local prompt_file="$1"
  local output_file="$2"

  # Use --print for non-interactive, fast generation
  claude --print -p "$(cat "$prompt_file")" > "$output_file"
}
```

### 2. Disable Auto-Context for Codex

```bash
run_codex() {
  local args=(exec - --output-last-message "$output_file" --json)

  # CRITICAL: Disable features that cause exploration
  args+=(-c "features.web_search_request=false")
  args+=(-c "features.auto_context=false")  # Don't explore codebase

  codex "${args[@]}" < "$prompt_file"
}
```

### 3. Backend Selection Logic

```bash
# In CLI args
--backend codex|claude

# In generation function
run_generation() {
  if [[ "$backend" == "claude" ]]; then
    run_claude "$@"
  else
    run_codex "$@"
  fi
}
```

## Performance Comparison

| Backend | Step 1 Time | Commands Before Code |
|---------|-------------|---------------------|
| Codex (default) | 180+ sec | 50+ |
| Codex (auto_context=false) | 90 sec | 10-20 |
| Claude CLI | 30 sec | 0 |

## Recommendations

1. **Default to Claude CLI** for code generation tasks
2. **Use Codex** only when exploration is genuinely needed (e.g., codebase understanding)
3. **Always disable** `auto_context` when prompt contains full context
4. **Consider model selection**: Claude Sonnet is faster than Opus for generation

## Implementation Status

- [x] Added Claude backend support to step-loop.sh
- [x] Added `--backend` CLI flag
- [x] Disabled auto_context for Codex
- [ ] Add backend recommendation based on task type
- [ ] Benchmark different models for generation speed

## References

- [Codex CLI Reference](https://developers.openai.com/codex/cli/reference) - `exec` mode and CLI options
- [Codex Advanced Configuration](https://developers.openai.com/codex/config-advanced) - `features.auto_context` and other settings
