<div align="center">

```
███████╗██╗  ██╗██╗██╗     ██╗          ██╗███████╗███████╗██╗   ██╗███████╗███████╗
██╔════╝██║ ██╔╝██║██║     ██║          ██║██╔════╝██╔════╝██║   ██║██╔════╝██╔════╝
███████╗█████╔╝ ██║██║     ██║          ██║███████╗███████╗██║   ██║█████╗  ███████╗
╚════██║██╔═██╗ ██║██║     ██║          ██║╚════██║╚════██║██║   ██║██╔══╝  ╚════██║
███████║██║  ██╗██║███████╗███████╗     ██║███████║███████║╚██████╔╝███████╗███████║
╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝     ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝
```

**AI Code Generation Evaluation Framework**

</div>

---

This repository contains two main components:

1. **Skills** - Reusable knowledge packages that improve AI code generation quality
2. **Eval Harness** - A multi-stage evaluation system for measuring and improving AI-generated code

## Quick Start: Step Loop Example

The **step-loop** is our primary evaluation tool. It breaks complex coding tasks into incremental steps, validates each step, and produces production-quality code.

### Example: Trapping Rain Water in Cairo

```bash
./skill-issues run cairo-trapping-rain-water-01
```

That's it. The CLI infers paths, applies default skills, and runs the full evaluation.

**With options:**
```bash
./skill-issues run cairo-trapping-rain-water-01 \
  -m claude-opus-4-20250514 \
  --clean \
  -v
```

**Other commands:**
```bash
./skill-issues list                              # Show available prompts
./skill-issues status cairo-trapping-rain-water-01   # Check run status
./skill-issues clean cairo-trapping-rain-water-01    # Remove generated files
```

This command:
1. Reads a 6-step prompt (brute force → DP → two-pointer optimization)
2. Generates code incrementally, validating each step with `scarb build`
3. Runs tests with `snforge test` at completion
4. Produces a modular multi-file project structure
5. Applies `cairo-quirks` and `cairo-quality` skills for better output

### What Gets Generated

```
eval/work/cairo-trapping-rain-water-01/
├── Scarb.toml
├── src/
│   ├── lib.cairo           # Module exports
│   └── solution.cairo      # Implementation (3 algorithms)
└── tests/
    └── test_lib.cairo      # 17+ integration tests
```

The generated `solution.cairo` includes:
- `trap_brute_force()` - O(n²) time, O(1) space
- `trap_dp()` - O(n) time, O(n) space
- `trap()` - O(n) time, O(1) space (optimal two-pointer)
- Full documentation with complexity analysis
- Comprehensive test coverage

## Why This Matters

### The Problem
AI code generators often produce code that:
- Compiles but has subtle bugs
- Uses suboptimal algorithms
- Has poor structure (everything in one file)
- Lacks documentation and tests
- Contains unused imports and lint warnings

### The Solution
This system addresses these issues through:

1. **Incremental validation** - Each step must compile before proceeding
2. **Skills** - Domain knowledge injected into prompts
3. **Multi-file structure** - Proper separation of concerns
4. **Quality skills** - Guidelines for DRY, complexity, documentation

## Repository Structure

```
skill-issues/
├── skills/                    # Reusable skill packages
│   ├── cairo-quirks/         # Cairo language patterns
│   └── cairo-quality/        # Code quality guidelines
├── eval/
│   ├── prompts/              # Task definitions (one per file)
│   ├── rubrics/              # Pass/fail criteria
│   ├── work/                 # Generated projects (gitignored)
│   └── ralph/
│       ├── step-loop.sh      # Main evaluation runner
│       └── .state/           # Execution state (gitignored)
└── dist/                     # Packaged .skill files
```

## Installation

### Skills Installation

**Option A — User-scoped (available in all repos)**

```bash
mkdir -p ~/.codex/skills
cp -R ./skills/cairo-* ~/.codex/skills/
```

**Option B — Repo-scoped (checked into this repo)**

```bash
mkdir -p ./.codex/skills
cp -R ./skills/cairo-* ./.codex/skills/
```

**Using packaged `.skill` files**

```bash
mkdir -p ~/.codex/skills
unzip ./dist/cairo-*.skill -d ~/.codex/skills
```

### Prerequisites for Eval Harness

- [Scarb](https://docs.swmansion.com/scarb/) - Cairo package manager
- [snforge](https://foundry-rs.github.io/starknet-foundry/) - Starknet testing framework
- `claude` CLI or `codex` CLI for AI backends

## Documentation

- [Eval Harness Overview](eval/README.md) - Full evaluation system docs
- [Step Loop Guide](eval/ralph/README.md) - Detailed step-loop documentation
- [Prompts Guide](eval/prompts/README.md) - How to write prompts
- [Rubrics Guide](eval/rubric/README.md) - How to write rubrics (also see `eval/rubrics/`)

## End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        step-loop.sh                              │
├─────────────────────────────────────────────────────────────────┤
│  1. Parse prompt into steps                                      │
│  2. Scaffold project (scarb new)                                 │
│  3. For each step:                                               │
│     a. Build prompt with accumulated code + skills               │
│     b. Call LLM backend (claude/codex)                           │
│     c. Extract code from response                                │
│     d. Write to project files                                    │
│     e. Validate (scarb check → scarb build)                      │
│     f. On failure: retry with error feedback (up to 3x)          │
│     g. Record metrics                                            │
│  4. Run tests (snforge test)                                     │
│  5. Run linter (scarb lint)                                      │
│  6. Output final metrics                                         │
└─────────────────────────────────────────────────────────────────┘
```

## Skills

Skills are markdown files that provide domain-specific knowledge to improve code generation.

### cairo-quirks
Cairo language patterns and common pitfalls:
- Array immutability and ownership
- Felt252 vs u256 usage
- Storage patterns for Starknet
- Common compiler errors and fixes

### cairo-quality
Code quality guidelines:
- Algorithm documentation (time/space complexity)
- DRY principles
- Unused import prevention
- Naming conventions
- Test quality standards

## Metrics

Each run produces metrics at `.state/<project>/metrics.json`:

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

## Contributing

1. **Add a prompt**: Create `eval/prompts/<id>.md` with step-by-step tasks
2. **Add a rubric**: Create `eval/rubrics/<id>.md` with pass/fail criteria
3. **Run evaluation**: Use step-loop to test generation quality
4. **Improve skills**: Add patterns that fix common failures

## License

MIT
