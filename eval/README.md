# Skill Evaluation Harness

This harness combines a stable prompt set, a simple verification runner, and a results workflow to measure one-shot success and guide skill improvements.

See `eval/harness.md` for the rationale and the longer-term "best-in-class" direction.

## Directory layout

- `eval/prompts/` - One file per prompt.
- `eval/rubric/` - One file per prompt ID describing pass/fail criteria.
- `eval/work/` - Working directories for generated code (not committed).
- `eval/results/` - Timestamped verification output (not committed).
- `eval/verify.sh` - Runs `scarb fmt`, `scarb build`, and `snforge test` (if tests exist).
- `eval/scaffold.sh` - Creates a temp Scarb project (or copies a template).
- `eval/eval-runner.sh` - Batch runs verification across `eval/work/`.
- `eval/run-prompt.sh` - End-to-end: run Codex on a prompt, capture logs/JSON, write code, then verify.
- `eval/record_step.py` + `eval/steps_to_verify.py` - Build `verify.json`.
- `eval/schema/code-output.schema.json` - Default JSON schema for structured output.

## One-shot evaluation loop

1) Add a prompt
- Create `eval/prompts/<prompt-id>.md` with a single, one-shot task.
- Keep prompts stable; add new ones instead of editing old ones.

2) Add a rubric
- Create `eval/rubric/<prompt-id>.md` with objective pass/fail checks.

3) Create a workspace
```bash
eval/scaffold.sh eval/work/<prompt-id>
```

4) Run a one-shot attempt (manual)
- Use the skill to generate code once.
- Paste the output into the workspace (e.g. `eval/work/<prompt-id>/src/lib.cairo`).

5) Verify (manual)
```bash
eval/verify.sh eval/work/<prompt-id> eval/results/$(date -u +%Y-%m-%d)/<prompt-id>
```

6) Score and update
- Check `verify.json` and the rubric.
- If it failed, update the skill with the missing information only.

7) Re-run the same prompt set
- Re-run the same prompt(s) to confirm improvement.
- Track regressions across previously passing prompts.

## Batch runs

```bash
eval/eval-runner.sh
```

Defaults:
- Work root: `eval/work`
- Results root: `eval/results/YYYY-MM-DD`

## End-to-end run (Codex + verify)

```bash
eval/run-prompt.sh --prompt cairo-generics-traits-01 --skill cairo-generics-traits --schema default
```

Without skills:
```bash
eval/run-prompt.sh --prompt cairo-generics-traits-01 --disable-skills --schema default
```

This writes:
- `eval/results/YYYY-MM-DD/<prompt-id>/codex.jsonl` (Codex event log)
- `eval/results/YYYY-MM-DD/<prompt-id>/codex.stderr`
- `eval/results/YYYY-MM-DD/<prompt-id>/assistant_last.txt` (raw model output)
- `eval/results/YYYY-MM-DD/<prompt-id>/run.json` (run metadata)
- `eval/results/YYYY-MM-DD/<prompt-id>/verify.json` (verification results)

Example prompt included:
- `eval/prompts/cairo-generics-traits-01.md`
- `eval/rubric/cairo-generics-traits-01.md`

## Notes

- The verifier expects a Scarb project with `Scarb.toml`.
- If `snforge` is not installed or no tests exist, the test step is recorded as skipped.
- `verify.json` is the structured output used for scoring.
- When `--schema default` is used, `eval/run-prompt.sh` expects JSON output with `code` and `notes` fields and writes `code` into `src/lib.cairo`.
- `eval/scaffold.sh` runs `scarb new`/`scarb init` with `--no-vcs` and defaults to `--test-runner none`. Set `SCARB_INIT_TEST_RUNNER=starknet-foundry` if you want Foundry test scaffolding.
- If a work dir already exists but lacks `Scarb.toml`, scaffolding uses `scarb init` in place.
- Scarb package names are sanitized to lowercase and underscores (hyphens become underscores).
