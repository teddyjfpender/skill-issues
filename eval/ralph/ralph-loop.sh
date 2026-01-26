#!/usr/bin/env bash
set -euo pipefail

# Ralph Loop - Multi-agent Cairo code generation with driver/reviewer co-piloting
#
# This script orchestrates iterative code generation using two AI agents:
# - Driver: Generates Cairo code based on prompt and feedback
# - Reviewer: Validates code against rubric before expensive build/test
#
# Usage:
#   ralph-loop.sh --prompt <id> --rubric <id> [options]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_driver() { echo -e "${MAGENTA}[DRIVER]${NC} $1"; }
log_reviewer() { echo -e "${CYAN}[REVIEWER]${NC} $1"; }

# Timeout wrapper - uses GNU timeout if available, otherwise runs without timeout
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
fi

run_with_timeout() {
  local secs="$1"
  shift
  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$secs" "$@"
  else
    # No timeout available, run directly
    "$@"
  fi
}

usage() {
  cat <<'USAGE'
Usage: ralph-loop.sh --prompt <id|path> --rubric <id|path> [options]

Required:
  --prompt <id|path>           Prompt file ID or path
  --rubric <id|path>           Rubric file ID or path

Driver Options:
  --driver-backend <backend>   Backend for driver: codex or claude (default: codex)
  --driver-model <model>       Model for driver (default: gpt-5.2-codex for codex, claude-opus-4-5 for claude)
  --driver-skills <skills>     Comma-separated skills for driver

Reviewer Options:
  --reviewer-backend <backend> Backend for reviewer: codex or claude (default: codex)
  --reviewer-model <model>     Model for reviewer (default: gpt-5.2-codex for codex, claude-opus-4-5 for claude)
  --reviewer-skills <skills>   Comma-separated skills for reviewer

Loop Options:
  --max-attempts <n>           Maximum attempts (default: 5)
  --timeout <seconds>          Timeout per step (default: 120)
  --pre-validate               Enable Cairo pre-validation

Directory Options:
  --ralph-dir <path>           Ralph state directory (default: .ralph/<prompt-id>)
  --work-dir <path>            Scarb project directory (default: eval/work/<prompt-id>)

Other:
  --help, -h                   Show this help

Exit Codes:
  0 - Success (code passes all checks)
  1 - Max attempts exhausted
  2 - Unfixable problem (reviewer verdict)
  3 - Configuration error
USAGE
}

# Default values
prompt_arg=""
rubric_arg=""
driver_backend="codex"
driver_model=""
driver_skills=""
reviewer_backend="codex"
reviewer_model=""
reviewer_skills=""
max_attempts=5
timeout=120
pre_validate=0
ralph_dir=""
work_dir=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt_arg="$2"; shift 2 ;;
    --rubric) rubric_arg="$2"; shift 2 ;;
    --driver-backend) driver_backend="$2"; shift 2 ;;
    --driver-model) driver_model="$2"; shift 2 ;;
    --driver-skills) driver_skills="$2"; shift 2 ;;
    --reviewer-backend) reviewer_backend="$2"; shift 2 ;;
    --reviewer-model) reviewer_model="$2"; shift 2 ;;
    --reviewer-skills) reviewer_skills="$2"; shift 2 ;;
    --max-attempts) max_attempts="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --pre-validate) pre_validate=1; shift ;;
    --ralph-dir) ralph_dir="$2"; shift 2 ;;
    --work-dir) work_dir="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) log_error "Unknown argument: $1"; usage >&2; exit 3 ;;
  esac
done

# Validate required arguments
if [[ -z "$prompt_arg" ]]; then
  log_error "Missing --prompt"
  usage >&2
  exit 3
fi

if [[ -z "$rubric_arg" ]]; then
  log_error "Missing --rubric"
  usage >&2
  exit 3
fi

# Set default models based on backend if not specified
if [[ -z "$driver_model" ]]; then
  if [[ "$driver_backend" == "codex" ]]; then
    driver_model="gpt-5.2-codex"
  elif [[ "$driver_backend" == "claude" ]]; then
    driver_model="claude-opus-4-5"
  fi
fi

if [[ -z "$reviewer_model" ]]; then
  if [[ "$reviewer_backend" == "codex" ]]; then
    reviewer_model="gpt-5.2-codex"
  elif [[ "$reviewer_backend" == "claude" ]]; then
    reviewer_model="claude-opus-4-5"
  fi
fi

# Resolve paths
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval_dir="$(dirname "$script_dir")"

# Resolve prompt path
prompt_path=""
if [[ -f "$prompt_arg" ]]; then
  prompt_path="$prompt_arg"
else
  prompt_path="$eval_dir/prompts/$prompt_arg.md"
fi
if [[ ! -f "$prompt_path" ]]; then
  log_error "Prompt not found: $prompt_path"
  exit 3
fi

# Resolve rubric path
rubric_path=""
if [[ -f "$rubric_arg" ]]; then
  rubric_path="$rubric_arg"
else
  rubric_path="$eval_dir/rubric/$rubric_arg.md"
fi
if [[ ! -f "$rubric_path" ]]; then
  log_error "Rubric not found: $rubric_path"
  exit 3
fi

# Extract prompt ID
prompt_id="$(basename "$prompt_path")"
prompt_id="${prompt_id%.md}"

# Set default directories
if [[ -z "$ralph_dir" ]]; then
  ralph_dir=".ralph/$prompt_id"
fi
if [[ -z "$work_dir" ]]; then
  work_dir="$eval_dir/work/$prompt_id"
fi

# Schema paths
code_schema="$eval_dir/schema/code-output.schema.json"
review_schema="$script_dir/schema/review-output.schema.json"

# History path
history_path="$ralph_dir/history.json"

echo ""
log_info "=========================================="
log_info "  Ralph Loop: $prompt_id"
log_info "=========================================="
echo ""
log_info "Configuration:"
log_info "  Prompt: $prompt_path"
log_info "  Rubric: $rubric_path"
log_info "  Max attempts: $max_attempts"
log_info "  Driver: $driver_backend${driver_model:+ ($driver_model)}${driver_skills:+ [skills: $driver_skills]}"
log_info "  Reviewer: $reviewer_backend${reviewer_model:+ ($reviewer_model)}${reviewer_skills:+ [skills: $reviewer_skills]}"
log_info "  Ralph dir: $ralph_dir"
log_info "  Work dir: $work_dir"
echo ""

# Create directories
mkdir -p "$ralph_dir/attempts"
mkdir -p "$work_dir"

# Scaffold if needed
if [[ ! -f "$work_dir/Scarb.toml" ]]; then
  log_step "Scaffolding Scarb project..."
  "$eval_dir/scaffold.sh" "$work_dir"
  log_success "Scaffold complete"
fi

# Initialize history
log_step "Initializing history..."
config_json=$(cat <<EOF
{
  "prompt_path": "$prompt_path",
  "rubric_path": "$rubric_path",
  "max_attempts": $max_attempts,
  "driver_backend": "$driver_backend",
  "driver_model": "$driver_model",
  "driver_skills": $(echo "$driver_skills" | jq -R 'split(",") | map(select(length > 0))'),
  "reviewer_backend": "$reviewer_backend",
  "reviewer_model": "$reviewer_model",
  "reviewer_skills": $(echo "$reviewer_skills" | jq -R 'split(",") | map(select(length > 0))'),
  "pre_validate": $([ "$pre_validate" -eq 1 ] && echo "true" || echo "false"),
  "timeout": $timeout
}
EOF
)
python3 "$script_dir/update-history.py" init "$history_path" "$prompt_id" --config "$config_json"
log_success "History initialized"

# Function to run an AI backend
run_backend() {
  local backend="$1"
  local model="$2"
  local skills="$3"
  local schema="$4"
  local prompt_file="$5"
  local output_file="$6"
  local jsonl_file="$7"
  local stderr_file="$8"

  local args=()

  if [[ "$backend" == "codex" ]]; then
    # Build codex arguments
    args=(exec - --output-last-message "$output_file" --json)
    if [[ -n "$schema" ]]; then
      args+=(--output-schema "$schema")
    fi
    if [[ -n "$model" ]]; then
      args+=(--model "$model")
    fi

    # Add skills as $skill-name prefixes to prompt
    local full_prompt=""
    if [[ -n "$skills" ]]; then
      IFS=',' read -ra skill_arr <<< "$skills"
      for s in "${skill_arr[@]}"; do
        full_prompt+="\$${s}"$'\n'
      done
      full_prompt+=$'\n'
    fi
    full_prompt+="$(cat "$prompt_file")"

    # Run codex
    echo "$full_prompt" | run_with_timeout "$timeout" codex "${args[@]}" 2>"$stderr_file" | tee "$jsonl_file"
    return ${PIPESTATUS[1]}

  elif [[ "$backend" == "claude" ]]; then
    # Build claude arguments
    args=(--print --output-format json)
    if [[ -n "$model" ]]; then
      args+=(--model "$model")
    fi

    # Add skills
    if [[ -n "$skills" ]]; then
      IFS=',' read -ra skill_arr <<< "$skills"
      for s in "${skill_arr[@]}"; do
        args+=(--allowedTools "\$${s}")
      done
    fi

    # Run claude
    local prompt_text
    prompt_text="$(cat "$prompt_file")"
    run_with_timeout "$timeout" claude "${args[@]}" "$prompt_text" > "$output_file" 2>"$stderr_file"
    return $?
  else
    log_error "Unknown backend: $backend"
    return 1
  fi
}

# Function to extract code from output
extract_code() {
  local output_file="$1"
  local code_file="$2"

  python3 "$eval_dir/extract_code.py" "$output_file" "$code_file"
}

# Function to parse reviewer output
parse_review() {
  local output_file="$1"

  # Extract JSON from output (handle possible markdown wrapping)
  local content
  content="$(cat "$output_file")"

  # Try to extract JSON if wrapped in code blocks
  if echo "$content" | grep -q '```json'; then
    content="$(echo "$content" | sed -n '/```json/,/```/p' | sed '1d;$d')"
  elif echo "$content" | grep -q '```'; then
    content="$(echo "$content" | sed -n '/```/,/```/p' | sed '1d;$d')"
  fi

  # Parse and extract verdict
  echo "$content" | jq -r '.verdict // "INVALID"'
}

# Main loop
for attempt in $(seq 1 "$max_attempts"); do
  attempt_dir="$ralph_dir/attempts/$(printf '%03d' "$attempt")"
  mkdir -p "$attempt_dir"

  echo ""
  log_info "=========================================="
  log_info "  Attempt $attempt of $max_attempts"
  log_info "=========================================="
  echo ""

  # Start attempt in history
  python3 "$script_dir/update-history.py" start-attempt "$history_path" "$attempt"

  # === DRIVER PHASE ===
  log_driver "Building driver prompt..."
  driver_prompt="$attempt_dir/driver_prompt.txt"
  python3 "$script_dir/build-driver-prompt.py" \
    --prompt "$prompt_path" \
    --rubric "$rubric_path" \
    --history "$history_path" \
    --attempt "$attempt" \
    --max-attempts "$max_attempts" \
    --output "$driver_prompt"

  log_driver "Generating code..."
  driver_output="$attempt_dir/driver_output.json"
  driver_jsonl="$attempt_dir/driver.jsonl"
  driver_stderr="$attempt_dir/driver.stderr"

  set +e
  run_backend "$driver_backend" "$driver_model" "$driver_skills" "$code_schema" \
    "$driver_prompt" "$driver_output" "$driver_jsonl" "$driver_stderr"
  driver_exit=$?
  set -e

  if [[ $driver_exit -ne 0 ]] || [[ ! -s "$driver_output" ]]; then
    log_error "Driver failed (exit: $driver_exit)"
    python3 "$script_dir/update-history.py" set-driver "$history_path" "$attempt" \
      --exit-code "$driver_exit"
    python3 "$script_dir/update-history.py" set-feedback "$history_path" "$attempt" \
      --source "build" --summary "Driver generation failed" \
      --errors '["Driver did not produce output"]'
    python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
    continue
  fi

  # Extract code
  code_file="$attempt_dir/code.cairo"
  extract_code "$driver_output" "$code_file"
  log_success "Code generated: $code_file"

  # Record driver result
  python3 "$script_dir/update-history.py" set-driver "$history_path" "$attempt" \
    --code-path "$code_file" --exit-code "$driver_exit"

  # === REVIEWER PHASE ===
  log_reviewer "Building reviewer prompt..."
  reviewer_prompt="$attempt_dir/reviewer_prompt.txt"
  python3 "$script_dir/build-reviewer-prompt.py" \
    --code "$code_file" \
    --rubric "$rubric_path" \
    --prompt "$prompt_path" \
    --output "$reviewer_prompt"

  log_reviewer "Validating code..."
  reviewer_output="$attempt_dir/reviewer_output.json"
  reviewer_jsonl="$attempt_dir/reviewer.jsonl"
  reviewer_stderr="$attempt_dir/reviewer.stderr"

  set +e
  run_backend "$reviewer_backend" "$reviewer_model" "$reviewer_skills" "$review_schema" \
    "$reviewer_prompt" "$reviewer_output" "$reviewer_jsonl" "$reviewer_stderr"
  reviewer_exit=$?
  set -e

  if [[ $reviewer_exit -ne 0 ]] || [[ ! -s "$reviewer_output" ]]; then
    log_warn "Reviewer failed (exit: $reviewer_exit), proceeding to verification"
    verdict="VALID"  # Assume valid if reviewer fails
  else
    verdict="$(parse_review "$reviewer_output")"
  fi

  log_reviewer "Verdict: $verdict"

  # Record review result
  if [[ -s "$reviewer_output" ]]; then
    issues="$(cat "$reviewer_output" | jq -c '.issues // []' 2>/dev/null || echo '[]')"
    notes="$(cat "$reviewer_output" | jq -r '.notes // ""' 2>/dev/null || echo '')"
    python3 "$script_dir/update-history.py" set-review "$history_path" "$attempt" \
      --verdict "$verdict" --issues "$issues" --notes "$notes"
  fi

  # Handle review verdict
  if [[ "$verdict" == "UNFIXABLE" ]]; then
    log_error "Reviewer determined problem is unfixable"
    python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
    python3 "$script_dir/update-history.py" finish "$history_path" --status unfixable
    exit 2
  fi

  if [[ "$verdict" == "INVALID" ]]; then
    log_warn "Reviewer found issues, skipping verification"
    # Extract feedback from reviewer
    issues_text="$(cat "$reviewer_output" | jq -r '.issues[]? | "\(.severity): \(.description)"' 2>/dev/null || echo 'Review failed')"
    hints="$(cat "$reviewer_output" | jq -c '[.issues[]? | .suggestion // empty]' 2>/dev/null || echo '[]')"
    python3 "$script_dir/update-history.py" set-feedback "$history_path" "$attempt" \
      --source "reviewer" --summary "Code review found issues" \
      --errors "[\"$issues_text\"]" --hints "$hints"
    python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
    continue
  fi

  # === VERIFICATION PHASE ===
  log_step "Running verification..."

  # Copy code to work directory
  cp "$code_file" "$work_dir/src/lib.cairo"

  # Run verify.sh
  verify_dir="$attempt_dir"
  set +e
  "$eval_dir/verify.sh" "$work_dir" "$verify_dir"
  verify_exit=$?
  set -e

  verify_json="$verify_dir/verify.json"
  if [[ ! -f "$verify_json" ]]; then
    log_error "Verification did not produce verify.json"
    python3 "$script_dir/update-history.py" set-verify "$history_path" "$attempt" \
      --status "fail" --failed-steps '["unknown"]'
    python3 "$script_dir/update-history.py" set-feedback "$history_path" "$attempt" \
      --source "build" --summary "Verification did not complete"
    python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
    continue
  fi

  # Parse verify results
  verify_status="$(jq -r '.status' "$verify_json")"
  failed_steps="$(jq -c '.failed_steps' "$verify_json")"

  log_info "Verify status: $verify_status"
  if [[ "$verify_status" == "fail" ]]; then
    log_warn "Failed steps: $failed_steps"
  fi

  # Record verify result
  python3 "$script_dir/update-history.py" set-verify "$history_path" "$attempt" \
    --status "$verify_status" --failed-steps "$failed_steps" --path "$verify_json"

  # Check for success
  if [[ "$verify_status" == "pass" ]]; then
    log_success "=========================================="
    log_success "  SUCCESS on attempt $attempt!"
    log_success "=========================================="

    # Copy final code
    cp "$code_file" "$ralph_dir/final.cairo"
    log_success "Final code: $ralph_dir/final.cairo"

    python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
    python3 "$script_dir/update-history.py" finish "$history_path" --status success --successful-attempt "$attempt"
    exit 0
  fi

  # Extract feedback for next attempt
  log_step "Extracting feedback..."
  feedback_json="$attempt_dir/feedback.json"
  python3 "$script_dir/extract-feedback.py" --verify-json "$verify_json" --output "$feedback_json"

  # Record feedback
  source="$(jq -r '.source' "$feedback_json")"
  summary="$(jq -r '.summary' "$feedback_json")"
  errors="$(jq -c '.errors' "$feedback_json")"
  hints="$(jq -c '.actionable_hints' "$feedback_json")"
  python3 "$script_dir/update-history.py" set-feedback "$history_path" "$attempt" \
    --source "$source" --summary "$summary" --errors "$errors" --hints "$hints"

  python3 "$script_dir/update-history.py" end-attempt "$history_path" "$attempt"
done

# Max attempts exhausted
echo ""
log_error "=========================================="
log_error "  FAILURE: Max attempts ($max_attempts) exhausted"
log_error "=========================================="

python3 "$script_dir/update-history.py" finish "$history_path" --status failure
exit 1
