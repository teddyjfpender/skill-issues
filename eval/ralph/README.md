# Ralph Loop - Multi-Agent Cairo Code Generation

Ralph Loop is a multi-agent wrapper around the one-shot evaluation harness. Two AI agents (Driver and Reviewer) collaborate iteratively to produce valid, working Cairo code.

## Architecture

```
ralph-loop.sh (orchestrator)
    │
    ├── build-driver-prompt.py → DRIVER LLM → code
    │
    ├── build-reviewer-prompt.py → REVIEWER LLM → verdict
    │
    ├── run-prompt.sh (reused) → codex/claude execution
    │
    └── verify.sh (reused) → verify.json
```

## Quick Start

```bash
# Basic usage with defaults (codex for both driver and reviewer)
eval/ralph/ralph-loop.sh \
  --prompt cairo-generics-traits-01 \
  --rubric cairo-generics-traits-01

# With different backends for driver and reviewer
eval/ralph/ralph-loop.sh \
  --prompt cairo-generics-traits-01 \
  --rubric cairo-generics-traits-01 \
  --driver-backend codex \
  --driver-skills "cairo-generics-traits" \
  --reviewer-backend claude \
  --reviewer-model claude-sonnet-4-20250514

# Full options
eval/ralph/ralph-loop.sh \
  --prompt cairo-generics-traits-01 \
  --rubric cairo-generics-traits-01 \
  --max-attempts 5 \
  --driver-backend codex \
  --driver-model o3 \
  --driver-skills "cairo-generics-traits,cairo-arrays" \
  --reviewer-backend claude \
  --timeout 120
```

## Loop Flow

```
FOR attempt IN 1..MAX_ATTEMPTS:
  1. BUILD_DRIVER_PROMPT(prompt, rubric, history)
  2. DRIVER_GENERATE → code
  3. REVIEWER_VALIDATE(code, rubric) → verdict
  4. IF verdict == "INVALID" → record feedback, continue
  5. IF verdict == "UNFIXABLE" → exit early
  6. VERIFY(scarb fmt, build, test) → verify.json
  7. IF status == "pass" → SUCCESS
  8. EXTRACT_FEEDBACK(errors) → history
EXIT: max attempts exhausted
```

## Options

### Required
- `--prompt <id|path>` - Prompt file ID or path
- `--rubric <id|path>` - Rubric file ID or path

### Driver Options
- `--driver-backend <backend>` - Backend: `codex` or `claude` (default: codex)
- `--driver-model <model>` - Model name (default: `gpt-5.2-codex` for codex, `claude-opus-4-5` for claude)
- `--driver-skills <skills>` - Comma-separated skill names

### Reviewer Options
- `--reviewer-backend <backend>` - Backend: `codex` or `claude` (default: codex)
- `--reviewer-model <model>` - Model name (default: `gpt-5.2-codex` for codex, `claude-opus-4-5` for claude)
- `--reviewer-skills <skills>` - Comma-separated skill names

### Loop Options
- `--max-attempts <n>` - Maximum attempts (default: 5)
- `--timeout <seconds>` - Timeout per step (default: 120)
- `--pre-validate` - Enable Cairo pre-validation (not yet implemented)

### Directory Options
- `--ralph-dir <path>` - State directory (default: `.ralph/<prompt-id>`)
- `--work-dir <path>` - Scarb project (default: `eval/work/<prompt-id>`)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - code passes all checks |
| 1 | Max attempts exhausted |
| 2 | Unfixable problem (reviewer verdict) |
| 3 | Configuration error |

## State Directory

Each run creates a state directory:

```
.ralph/<prompt-id>/
  history.json           # Full attempt history
  final.cairo           # Successful code (if any)
  attempts/
    001/
      driver_prompt.txt
      driver_output.json
      code.cairo
      reviewer_prompt.txt
      reviewer_output.json
      verify.json
      feedback.json
      build.out, build.err
    002/
      ...
```

## Components

| File | Purpose |
|------|---------|
| `ralph-loop.sh` | Main orchestrator |
| `build-driver-prompt.py` | Assemble driver prompt with feedback |
| `build-reviewer-prompt.py` | Assemble reviewer prompt |
| `extract-feedback.py` | Parse errors into actionable hints |
| `update-history.py` | Manage history.json |
| `schema/review-output.schema.json` | Reviewer output schema |
| `schema/history.schema.json` | History file schema |

## Reviewer Output Schema

```json
{
  "verdict": "VALID" | "INVALID" | "UNFIXABLE",
  "issues": [
    {
      "criterion": "which rubric item",
      "severity": "error" | "warning",
      "description": "what is wrong",
      "suggestion": "how to fix"
    }
  ],
  "notes": "optional summary"
}
```

## Example

```bash
# Run on the generics-traits prompt
cd /path/to/skill-issues
eval/ralph/ralph-loop.sh \
  --prompt cairo-generics-traits-01 \
  --rubric cairo-generics-traits-01 \
  --driver-skills "cairo-generics-traits"

# Check results
cat .ralph/cairo-generics-traits-01/history.json | jq '.status'
cat .ralph/cairo-generics-traits-01/final.cairo
```
