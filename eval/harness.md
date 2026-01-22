# Verification harness (“the compiler is the judge”)

This is the biggest question you asked: do you need Rust harnesses?

You need a harness, period. The language is a tradeoff.

Minimum viable verifier (recommended baseline):
	•	Shell scripts that run:
	•	scarb fmt (or equivalent)
	•	scarb build
	•	snforge test (if tests exist)

…and a small parser that turns stdout/stderr into structured JSON.

Best-in-class verifier (what I’d actually ship):
	•	a small Rust CLI cairo-verify that:
	•	creates a temp workspace
	•	writes generated files
	•	runs the commands
	•	parses diagnostics robustly
	•	outputs verify.json

Why Rust helps:
	•	single binary, easy to call from Codex/Claude scripts
	•	better log parsing + stable structured output
	•	fits the “runner_crate” concept already present in cairo-coder (fixtures/runner_crate)  ￼

But you do not need to rewrite the backend in Rust. Keep Python where it already exists.


# Do you need to write more harnesses?

You need one serious harness, plus a couple tiny scripts.

Must-have
	•	cairo-verify (Rust OR Python, but Rust is nicer)
	•	verify.sh wrapper (so skills can call it)
	•	scaffold.sh (create temp scarb project / copy into place)
	•	diagnostics.json normalization

Nice-to-have
	•	cairo-minimize (reduce failing repro into smallest snippet; great for “repair pass”)
	•	cairo-lint (pattern checks: missing events, wrong attribute macros, etc.)
	•	eval-runner (batch specs → pass/fail + stats)

If you do only one: do the verifier. That’s the thing that turns “LLM output” into “engineering output”.

# This repo's implementation

See `eval/README.md` for the concrete workflow and scripts:
- `eval/verify.sh` runs `scarb fmt`, `scarb build`, and `snforge test` (if tests exist).
- `eval/scaffold.sh` creates a Scarb project or copies a template.
- `eval/eval-runner.sh` batch-runs verification across `eval/work/`.
- `eval/run-prompt.sh` runs Codex on a prompt, captures logs/JSON, writes code, then verifies.
- `eval/record_step.py` + `eval/steps_to_verify.py` produce `verify.json`.
- `eval/schema/code-output.schema.json` defines a default structured output schema.
