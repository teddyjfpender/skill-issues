# Ralph: Multi-Agent Cairo Code Generation

This directory contains two code generation systems:

1. **step-loop.sh** - Incremental step-by-step code generation with validation
2. **ralph-loop.sh** - Driver/Reviewer co-pilot pattern for iterative refinement

## Step Loop (Primary)

The step-loop breaks complex coding tasks into incremental steps, validating each step before proceeding. This produces higher quality code than one-shot generation.

### Quick Start (High-Level CLI)

From the repository root:

```bash
./skill-issues run cairo-trapping-rain-water-01
```

The `skill-issues` CLI wraps step-loop with sensible defaults. See `./skill-issues --help` for options.

### Quick Start (Low-Level)

For full control, use step-loop.sh directly:

```bash
./step-loop.sh \
  --prompt ../prompts/cairo-trapping-rain-water-01.md \
  --rubric ../rubrics/cairo-trapping-rain-water.md \
  --work-dir ../work/cairo-trapping-rain-water-01 \
  --state-dir .state/cairo-trapping-rain-water-01 \
  --backend claude \
  --model claude-sonnet-4-20250514 \
  --skills cairo-quirks,cairo-quality \
  --multi-file \
  --max-retries 3 \
  --timeout 180
```

### How It Works

```
┌────────────────────────────────────────────────────────────────┐
│  STEP LOOP FLOW                                                 │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PARSE PROMPT                                                │
│     └── Extract steps from markdown (## Step N headers)         │
│                                                                 │
│  2. SCAFFOLD PROJECT                                            │
│     └── scarb new → create src/solution.cairo, tests/           │
│                                                                 │
│  3. FOR EACH STEP (with retries):                               │
│     ┌─────────────────────────────────────────────────────┐    │
│     │  a. Build prompt:                                    │    │
│     │     - Current step instructions                      │    │
│     │     - Accumulated code from previous steps           │    │
│     │     - Skills content (cairo-quirks, cairo-quality)   │    │
│     │     - Error feedback (if retry)                      │    │
│     │                                                      │    │
│     │  b. Call LLM backend (claude/codex)                  │    │
│     │                                                      │    │
│     │  c. Extract code:                                    │    │
│     │     - Parse // FILE: markers for multi-file          │    │
│     │     - Fall back to single lib.cairo if no markers    │    │
│     │                                                      │    │
│     │  d. Write files to project                           │    │
│     │                                                      │    │
│     │  e. Validate:                                        │    │
│     │     - scarb check (syntax)                           │    │
│     │     - scarb build (full compilation)                 │    │
│     │                                                      │    │
│     │  f. On failure → extract errors → retry              │    │
│     │  g. On success → record metrics → next step          │    │
│     └─────────────────────────────────────────────────────┘    │
│                                                                 │
│  4. FINAL VALIDATION                                            │
│     ├── snforge test (run all tests)                            │
│     └── scarb lint (check for warnings)                         │
│                                                                 │
│  5. OUTPUT METRICS                                              │
│     └── .state/<project>/metrics.json                           │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--prompt <path>` | Path to prompt file | Required |
| `--rubric <path>` | Path to rubric file | Required |
| `--work-dir <path>` | Output project directory | Required |
| `--state-dir <path>` | State/metrics directory | Required |
| `--backend <name>` | LLM backend: `claude` or `codex` | `claude` |
| `--model <name>` | Model identifier | Backend default |
| `--skills <list>` | Comma-separated skill names | None |
| `--multi-file` | Enable modular file structure | Disabled |
| `--max-retries <n>` | Retries per step on failure | `3` |
| `--timeout <sec>` | Timeout per LLM call | `120` |

### Multi-File Mode

With `--multi-file`, the model outputs code with file markers:

```cairo
// FILE: src/solution.cairo
pub fn trap(height: @Array<u32>) -> u32 {
    // implementation
}

// FILE: src/lib.cairo
mod solution;
pub use solution::*;

// FILE: tests/test_lib.cairo
use cairo_trapping_rain_water_01::*;

#[test]
fn test_example() {
    assert!(trap(@array![0, 1, 0, 2]) == 1);
}
```

The system parses these markers and writes each section to its respective file.

### Example: Trapping Rain Water

The `cairo-trapping-rain-water-01` prompt demonstrates a 6-step algorithmic progression:

| Step | Description | Complexity |
|------|-------------|------------|
| 1 | Project setup with SolutionTrait | - |
| 2 | Brute force implementation | O(n²) time, O(1) space |
| 3 | Dynamic programming approach | O(n) time, O(n) space |
| 4 | Two-pointer optimization | O(n) time, O(1) space |
| 5 | Unified API with RainWaterTrait | - |
| 6 | Comprehensive test coverage | - |

**Generated output:**

```
eval/work/cairo-trapping-rain-water-01/
├── Scarb.toml
├── src/
│   ├── lib.cairo           # mod solution; pub use solution::*;
│   └── solution.cairo      # 3 algorithms + traits
└── tests/
    └── test_lib.cairo      # 17+ tests
```

### State Management

State is persisted to allow resumption:

```
.state/cairo-trapping-rain-water-01/
├── metrics.json            # Execution metrics
├── state.json              # Current step, accumulated code
├── step-001/
│   └── attempt-001/
│       ├── prompt.txt      # Full prompt sent to LLM
│       ├── output.md       # Raw LLM response
│       └── files.json      # Extracted file contents
├── step-002/
│   └── ...
└── .scarb-cache/           # Isolated Scarb cache
```

### Metrics Output

```json
{
  "prompt_id": "cairo-trapping-rain-water-01",
  "total_steps": 6,
  "steps_completed": 6,
  "total_iterations": 6,
  "lint_warnings": 0,
  "tests_passed": 17,
  "tests_failed": 0,
  "status": "completed"
}
```

### Skills

Skills inject domain knowledge into prompts:

- **cairo-quirks**: Cairo language patterns, array handling, common errors
- **cairo-quality**: Code quality guidelines (DRY, complexity, documentation)

Skills are loaded from `~/.codex/skills/` or `skills/` directory.

---

## Ralph Loop (Driver/Reviewer)

The ralph-loop uses two agents: a Driver that generates code and a Reviewer that validates against a rubric before expensive build steps.

### Quick Start

```bash
./ralph-loop.sh \
  --prompt cairo-generics-traits-01 \
  --rubric cairo-generics-traits-01 \
  --driver-backend codex \
  --driver-skills "cairo-generics-traits" \
  --reviewer-backend claude \
  --max-attempts 5
```

### Architecture

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

### Loop Flow

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

### Options

#### Required
- `--prompt <id|path>` - Prompt file ID or path
- `--rubric <id|path>` - Rubric file ID or path

#### Driver Options
- `--driver-backend <backend>` - Backend: `codex` or `claude` (default: codex)
- `--driver-model <model>` - Model name
- `--driver-skills <skills>` - Comma-separated skill names

#### Reviewer Options
- `--reviewer-backend <backend>` - Backend: `codex` or `claude` (default: codex)
- `--reviewer-model <model>` - Model name
- `--reviewer-skills <skills>` - Comma-separated skill names

#### Loop Options
- `--max-attempts <n>` - Maximum attempts (default: 5)
- `--timeout <seconds>` - Timeout per step (default: 120)

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - code passes all checks |
| 1 | Max attempts exhausted |
| 2 | Unfixable problem (reviewer verdict) |
| 3 | Configuration error |

### State Directory

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
```

### Reviewer Output Schema

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

---

## Comparison

| Feature | step-loop | ralph-loop |
|---------|-----------|------------|
| Approach | Incremental steps | Full generation + review |
| Validation | Per-step compile | Reviewer + compile |
| Best for | Complex algorithms | Simpler one-shot tasks |
| State | Step-by-step | Attempt history |
| Multi-file | Yes (`--multi-file`) | No |

## Components

| File | Purpose |
|------|---------|
| `step-loop.sh` | Incremental step-by-step generation |
| `ralph-loop.sh` | Driver/Reviewer co-pilot loop |
| `build-driver-prompt.py` | Assemble driver prompt with feedback |
| `build-reviewer-prompt.py` | Assemble reviewer prompt |
| `extract-feedback.py` | Parse errors into actionable hints |
| `update-history.py` | Manage history.json |
| `metrics.py` | Metrics recording utilities |
