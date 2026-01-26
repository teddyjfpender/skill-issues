# 009: Direct Skill Embedding vs Prefix Loading

## Problem

Skills referenced with `$skill-name` prefix were not being loaded by Codex. The driver reported "skill named '$cairo-quirks' which isn't present in the known agents" and proceeded without the skill content.

## Root Cause

The `$skill-name` syntax is a convention for interactive Claude Code sessions where skills are loaded from configured paths. When using Codex `exec` mode:
- The skills configuration may not be passed correctly
- The skill resolution happens at a different stage
- Piped input doesn't trigger skill expansion

## Evidence

```
{"type":"item.completed","item":{"id":"item_0","type":"reasoning",
"text":"**Checking skill availability**\n\nI see the user references a skill
named \"$cairo-quirks\" which isn't present in the known agents..."}}
```

## Solution

### 1. Load Skills at Prompt Build Time

```bash
load_skill_content() {
  local skill_name="$1"
  local skill_dir="$script_dir/../../skills/$skill_name"

  if [[ -d "$skill_dir" ]]; then
    # Load SKILL.md (overview/checklist)
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      cat "$skill_dir/SKILL.md"
      echo ""
    fi
    # Load all reference files
    if [[ -d "$skill_dir/references" ]]; then
      for ref_file in "$skill_dir/references"/*.md; do
        if [[ -f "$ref_file" ]]; then
          cat "$ref_file"
          echo ""
        fi
      done
    fi
  fi
}
```

### 2. Embed in Prompt Construction

```bash
build_step_prompt() {
  # ... other prompt sections ...

  # Embed skill content directly
  if [[ -n "$skills" ]]; then
    echo "## Language Reference"
    echo ""
    echo "Use this reference for correct syntax. DO NOT search for anything else."
    echo ""
    IFS=',' read -ra skill_arr <<< "$skills"
    for s in "${skill_arr[@]}"; do
      load_skill_content "$s"
    done
  fi

  # ... rest of prompt ...
}
```

### 3. Remove Prefix Approach

```bash
# OLD (unreliable):
full_prompt="\$cairo-quirks\n\n$(cat "$prompt_file")"
echo "$full_prompt" | codex exec -

# NEW (reliable):
# Skills embedded during prompt construction
codex exec - < "$prompt_file"
```

## Benefits

1. **Guaranteed Loading**: Skill content is always present in prompt
2. **No Runtime Dependencies**: Works regardless of Codex configuration
3. **Visible Context**: Can verify skill content in saved prompts
4. **Backend Agnostic**: Works with Claude CLI, Codex, or any LLM

## Skill Structure

```
skills/
  cairo-quirks/
    SKILL.md           # Overview and checklist (loaded first)
    references/
      quirks.md        # Detailed reference (loaded second)
      examples.md      # More references (loaded third)
```

## Considerations

- **Prompt Size**: Embedding skills increases prompt token count
- **Relevance**: Only embed skills needed for the task
- **Updates**: Skill changes require no configuration changes

## Implementation Status

- [x] Added `load_skill_content()` function
- [x] Embedded skills in prompt construction
- [x] Removed `$skill` prefix approach
- [x] Tested with cairo-quirks skill
- [ ] Add skill selection based on prompt content
- [ ] Add skill size limits/truncation

## References

- [Codex Skills Configuration](https://developers.openai.com/codex/skills#enable-or-disable-skills) - How Codex loads skills via `skills.additional_paths`
- [Codex Advanced Configuration](https://developers.openai.com/codex/config-advanced) - Configuration file structure and `-c` overrides
