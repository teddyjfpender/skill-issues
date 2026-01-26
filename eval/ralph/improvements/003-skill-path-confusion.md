# Feature Improvement: Driver Skill Path Confusion

**ID**: 003
**Status**: Open
**Priority**: Medium
**Created**: 2026-01-26

## Problem

The driver agent wasted significant time searching for skill files in incorrect locations. It attempted paths like `/Users/theodorepender/.codex/skills/.system/cairo-generics-traits/SKILL.md` which don't exist.

## Observed Behavior

From Attempt 1 logs:
```
{"type":"item.completed","item":{"id":"item_3","type":"command_execution",
"command":"/bin/zsh -lc 'cat /Users/theodorepender/.codex/skills/.system/cairo-generics-traits/SKILL.md'",
"aggregated_output":"cat: /Users/theodorepender/.codex/skills/.system/cairo-generics-traits/SKILL.md: No such file or directory\n",
"exit_code":1,"status":"failed"}}
```

The driver assumed a Codex-style skill path structure instead of discovering the actual `skills/` directory in the repo root.

## Root Cause

1. Driver prompt doesn't explicitly state where skills are located
2. Driver may have been trained on different skill path conventions
3. No pre-validation that skills can be accessed

## Proposed Solutions

### Option A: Explicit Skill Paths in Prompt
Add to driver prompt:
```
Skills are located in the `skills/` directory at the repo root.
For example: `skills/cairo-generics-traits/SKILL.md`
```

### Option B: Pre-load Skills into Prompt
Instead of letting driver search for skills, include skill content directly in the prompt:
- Reduces search time to zero
- Ensures driver has correct information
- Increases prompt size

### Option C: Skill Index File
Create a skills index that driver can read first:
```json
{
  "cairo-generics-traits": "skills/cairo-generics-traits/SKILL.md",
  "cairo-operator-overloading": "skills/cairo-operator-overloading/SKILL.md"
}
```

## Recommendation

Option B (pre-load skills) is likely most effective for reducing iteration time, though it increases prompt token usage. Consider a hybrid: pre-load core skill content, provide index for additional reference files.

## Related Issues

- 001-driver-performance.md (excessive research time)
