# Feature Improvement: Driver Performance

**ID**: 001
**Status**: Fixed
**Priority**: High
**Created**: 2026-01-26
**Fixed**: 2026-01-26

## Problem

The driver agent spends excessive time researching before generating code. In testing with `cairo-matrix-algebra-01`, the driver executed 100+ reasoning/command items (reading skills, searching for patterns, examining existing code) before producing any code output.

This results in:
- Long iteration times (several minutes per attempt)
- Increased API costs
- Poor user experience when monitoring progress

## Observed Behavior

During Attempt 1 of `cairo-matrix-algebra-01`:
1. Driver read 50+ skill files
2. Driver searched for existing Cairo examples
3. Driver examined multiple work directories
4. Only after extensive research did it generate code
5. Total time for single attempt: several minutes

## Potential Causes

1. **Prompt lacks urgency**: Driver prompt doesn't emphasize code generation as the primary goal
2. **Model behavior**: Codex o3 may be overly cautious and wants comprehensive context
3. **Skill loading**: Too many skills available, causing excessive reading
4. **No early stopping**: Driver doesn't know when it has "enough" context

## Proposed Solutions

### Option A: Prompt Engineering (Low effort)
Add explicit guidance to driver prompt:
```
IMPORTANT: Your primary goal is to generate code, not research.
- Read only the most relevant skills (max 3-5 files)
- Generate code within the first 20 reasoning steps
- Prefer attempting code generation and iterating over extensive research
```

### Option B: Skill Pre-filtering (Medium effort)
- Pre-select relevant skills based on prompt metadata
- Only include 2-3 most relevant skills in driver context
- Reduces temptation to read everything

### Option C: Staged Approach (Higher effort)
- Phase 1: Quick context gathering (max 10 items)
- Phase 2: Code generation (required output)
- Enforce phase transitions in prompt/system

### Option D: Model Configuration
- Investigate Codex parameters that might affect reasoning depth
- Consider using different models for different attempt stages

## Success Metrics

- Driver generates initial code within 30 reasoning items
- Total attempt time under 2 minutes
- Code quality remains comparable

## Fix Applied

Updated `build-driver-prompt.py` to add explicit performance guidance at the top of the prompt:

```
## IMPORTANT: Performance Guidelines

You are in an iterative code generation loop. Your goal is to generate code QUICKLY.

**DO:**
- Generate code immediately using the skills and context provided below
- Make your best attempt even if uncertain - you'll get feedback to iterate
- Focus on satisfying the requirements, not on exploring the codebase

**DO NOT:**
- Search for skill files - they are pre-loaded below
- Extensively research existing code patterns
- Read more than 2-3 files for reference
- Aim for perfection on the first attempt
```

This emphasizes the iterative nature of the loop and discourages extensive research.

## Related Files

- `eval/ralph/build-driver-prompt.py`

## Related Issues

- 003 (Skill Path Confusion) - also fixed by pre-loading skills
