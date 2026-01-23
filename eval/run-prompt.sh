#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_step() {
  echo -e "${CYAN}[STEP]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
  cat <<'USAGE'
Usage: eval/run-prompt.sh --prompt <id|path> [options]

Options:
  --skill <name>           Prefix prompt with $<skill-name>. Can be specified multiple times.
  --disable-skills         Disable skills via config override.
  --schema <path|default>  Enforce JSON output schema. Use "default" for eval/schema/code-output.schema.json.
  --model <name>           Override the model for this run.
  --out-file <path>        Write generated code to this file (default: <work-dir>/src/lib.cairo).
  --work-dir <path>        Workspace root (default: eval/work/<prompt-id>).
  --results-dir <path>     Results root (default: eval/results/YYYY-MM-DD/<prompt-id>).
  --no-verify              Skip eval/verify.sh.
  --no-scaffold            Skip eval/scaffold.sh even if Scarb.toml is missing.
  --help, -h               Show this help.

Any extra arguments after -- are passed to codex exec.
USAGE
}

prompt_arg=""
skills=()
disable_skills=0
schema_arg=""
model=""
out_file=""
work_dir=""
results_dir=""
no_verify=0
no_scaffold=0
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      prompt_arg="$2"
      shift 2
      ;;
    --skill)
      skills+=("$2")
      shift 2
      ;;
    --disable-skills)
      disable_skills=1
      shift
      ;;
    --schema)
      schema_arg="$2"
      shift 2
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    --out-file)
      out_file="$2"
      shift 2
      ;;
    --work-dir)
      work_dir="$2"
      shift 2
      ;;
    --results-dir)
      results_dir="$2"
      shift 2
      ;;
    --no-verify)
      no_verify=1
      shift
      ;;
    --no-scaffold)
      no_scaffold=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$prompt_arg" ]]; then
  echo "missing --prompt" >&2
  usage >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prompt_path=""
if [[ -f "$prompt_arg" ]]; then
  prompt_path="$prompt_arg"
else
  prompt_path="$script_dir/prompts/$prompt_arg.md"
fi

if [[ ! -f "$prompt_path" ]]; then
  echo "prompt not found: $prompt_path" >&2
  exit 2
fi

prompt_id="$(basename "$prompt_path")"
prompt_id="${prompt_id%.md}"

echo ""
log_info "=========================================="
log_info "  Eval Runner: $prompt_id"
log_info "=========================================="
echo ""

if [[ -z "$work_dir" ]]; then
  work_dir="$script_dir/work/$prompt_id"
fi

if [[ -z "$results_dir" ]]; then
  results_dir="$script_dir/results/$(date -u +%Y-%m-%d)/$prompt_id"
fi

if [[ -z "$out_file" ]]; then
  out_file="$work_dir/src/lib.cairo"
fi

mkdir -p "$results_dir"

log_step "Setting up directories..."
log_info "  Work dir: $work_dir"
log_info "  Results dir: $results_dir"

if [[ $no_scaffold -eq 0 && ! -f "$work_dir/Scarb.toml" ]]; then
  log_step "Scaffolding new Scarb project..."
  "$script_dir/scaffold.sh" "$work_dir"
  log_success "Scaffold complete"
fi

mkdir -p "$(dirname "$out_file")"

schema_path=""
schema_preamble=""
if [[ -n "$schema_arg" ]]; then
  if [[ "$schema_arg" == "default" ]]; then
    schema_path="$script_dir/schema/code-output.schema.json"
  else
    schema_path="$schema_arg"
  fi

  if [[ ! -f "$schema_path" ]]; then
    echo "schema not found: $schema_path" >&2
    exit 2
  fi

  schema_preamble='Return JSON only with shape {"code": string, "notes": string}. Put any caveats in "notes" (empty string ok). Do not include Markdown or code fences.'
fi

prompt_file="$results_dir/prompt.txt"

log_step "Building prompt..."
log_info "  Prompt: $prompt_path"
if [[ ${#skills[@]} -gt 0 ]]; then
  log_info "  Skills (${#skills[@]}): ${skills[*]}"
fi
if [[ -n "$schema_path" ]]; then
  log_info "  Schema: $schema_path"
fi
if [[ -n "$model" ]]; then
  log_info "  Model: $model"
fi

{
  if [[ ${#skills[@]} -gt 0 ]]; then
    for s in "${skills[@]}"; do
      printf '$%s\n' "$s"
    done
    printf '\n'
  fi
  if [[ -n "$schema_preamble" ]]; then
    printf '%s\n\n' "$schema_preamble"
  fi
  cat "$prompt_path"
} > "$prompt_file"
log_success "Prompt saved to $prompt_file"

last_message="$results_dir/assistant_last.txt"
codex_jsonl="$results_dir/codex.jsonl"
codex_stderr="$results_dir/codex.stderr"

start_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

codex_args=()
if [[ $disable_skills -eq 1 ]]; then
  codex_args+=(--disable skills)
fi
codex_args+=(exec - --output-last-message "$last_message" --json)
if [[ -n "$schema_path" ]]; then
  codex_args+=(--output-schema "$schema_path")
fi
if [[ -n "$model" ]]; then
  codex_args+=(--model "$model")
fi
if [[ ${#extra_args[@]} -gt 0 ]]; then
  codex_args+=("${extra_args[@]}")
fi

echo ""
log_step "Running Codex..."
log_info "  Command: codex ${codex_args[*]}"
log_info "  Started at: $start_iso"
echo ""
echo -e "${YELLOW}--- Codex Output ---${NC}"

set +e
codex "${codex_args[@]}" < "$prompt_file" 2> "$codex_stderr" | tee "$codex_jsonl"
codex_status=${PIPESTATUS[0]}
set -e

echo -e "${YELLOW}--- End Codex Output ---${NC}"
echo ""

end_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_info "  Finished at: $end_iso"
if [[ $codex_status -eq 0 ]]; then
  log_success "Codex completed successfully"
else
  log_warn "Codex exited with status $codex_status"
fi

export RUN_PROMPT_ID="$prompt_id"
export RUN_PROMPT_PATH="$prompt_path"
export RUN_PROMPT_USED="$prompt_file"
export RUN_SKILLS="${skills[*]}"
export RUN_DISABLE_SKILLS="$disable_skills"
export RUN_SCHEMA_PATH="$schema_path"
export RUN_WORK_DIR="$work_dir"
export RUN_OUT_FILE="$out_file"
export RUN_RESULTS_DIR="$results_dir"
export RUN_MODEL="$model"
export RUN_CODEX_EXIT="$codex_status"
export RUN_STARTED_AT="$start_iso"
export RUN_ENDED_AT="$end_iso"
export RUN_CODEX_JSONL="$codex_jsonl"
export RUN_CODEX_STDERR="$codex_stderr"
export RUN_LAST_MESSAGE="$last_message"
export RUN_CODEX_ARGS="${codex_args[*]}"

log_step "Writing run metadata..."
python3 "$script_dir/write_run_metadata.py" "$results_dir/run.json"
log_success "Metadata saved to $results_dir/run.json"

if [[ ! -s "$last_message" ]]; then
  log_error "No assistant output written"
  log_info "Check stderr: $codex_stderr"
  exit 1
fi

log_step "Extracting code..."
if [[ -n "$schema_path" ]]; then
  python3 "$script_dir/extract_code.py" "$last_message" "$out_file"
  log_success "Code extracted to $out_file"
else
  cp "$last_message" "$out_file"
  log_success "Output copied to $out_file"
fi

if [[ $no_verify -eq 0 ]]; then
  echo ""
  log_step "Running verification..."
  echo -e "${YELLOW}--- Verification Output ---${NC}"
  "$script_dir/verify.sh" "$work_dir" "$results_dir"
  echo -e "${YELLOW}--- End Verification ---${NC}"
  log_success "Verification complete"
fi

if [[ $codex_status -ne 0 ]]; then
  log_error "Codex exec failed with status $codex_status"
  exit $codex_status
fi

echo ""
log_info "=========================================="
log_success "Run complete!"
log_info "=========================================="
log_info "  Output file: $out_file"
log_info "  Results dir: $results_dir"
echo ""
