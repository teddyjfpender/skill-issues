#!/usr/bin/env bash
#
# step-loop.sh - Incremental step-based code generation
#
# Parses "## Step N" markers from a prompt file and generates code
# one step at a time, validating after each step.
#
# Usage:
#   step-loop.sh --prompt <path> --rubric <path> --work-dir <path> \
#                --state-dir <path> --backend <codex|claude> --model <model> \
#                [--skills <skills>] [--max-retries <n>]
#
# Exit codes:
#   0 - All steps completed successfully
#   1 - Step failed after max retries
#   2 - Configuration error

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_step()  { echo -e "${CYAN}[STEP $1]${NC} $2"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_suggest() { echo -e "${MAGENTA}[SUGGEST]${NC} $1"; }

# ============================================================
# Token Estimation & Context Warnings
# ============================================================

estimate_tokens() {
  local content="$1"
  local chars=$(echo "$content" | wc -c | tr -d ' ')
  echo $((chars / 4))
}

check_context_size() {
  local content="$1"
  local tokens=$(estimate_tokens "$content")

  if [[ $tokens -gt 16000 ]]; then
    log_warn "Context very large (~$tokens tokens). Consider splitting prompts or summarizing."
  elif [[ $tokens -gt 8000 ]]; then
    log_warn "Context size warning: ~$tokens tokens accumulated. May affect generation quality."
  fi
}

# ============================================================
# Backend Recommendation
# ============================================================

recommend_backend() {
  local prompt_content="$1"
  local current_backend="$2"

  # Check for exploratory patterns
  local exploratory_patterns="explore|research|investigate|analyze|understand|study|examine|compare|evaluate"
  local generative_patterns="implement|create|build|write|generate|develop|construct"

  if echo "$prompt_content" | grep -qiE "$exploratory_patterns"; then
    if [[ "$current_backend" == "codex" ]]; then
      log_suggest "Task appears exploratory. Consider using --backend claude for better reasoning."
    fi
  elif echo "$prompt_content" | grep -qiE "$generative_patterns"; then
    if [[ "$current_backend" == "claude" ]]; then
      log_suggest "Task appears generative. Codex backend may be faster for code generation."
    fi
  fi
}

# Find timeout command (macOS uses gtimeout from coreutils)
TIMEOUT_CMD=""
if command -v timeout &> /dev/null; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout &> /dev/null; then
  TIMEOUT_CMD="gtimeout"
fi

run_with_timeout() {
  local timeout_secs="$1"
  shift
  if [[ -n "$TIMEOUT_CMD" ]]; then
    "$TIMEOUT_CMD" "$timeout_secs" "$@"
  else
    # No timeout available, run without
    "$@"
  fi
}

# Script directory
script_dir="$(cd "$(dirname "$0")" && pwd)"

# Source output recovery functions
if [[ -f "$script_dir/recover-output.sh" ]]; then
  source "$script_dir/recover-output.sh"
fi

# Defaults
prompt_path=""
rubric_path=""
work_dir=""
state_dir=""
backend="codex"
model=""
skills=""
max_retries=3
timeout=120
metrics_enabled=1

usage() {
  cat <<EOF
Usage: step-loop.sh [options]

Required:
  --prompt <path>       Path to prompt file with ## Step N markers
  --rubric <path>       Path to rubric file
  --work-dir <path>     Scarb project directory
  --state-dir <path>    Directory for step state/history

Options:
  --backend <backend>   codex or claude (default: codex)
  --model <model>       Model to use
  --skills <skills>     Comma-separated skill names
  --max-retries <n>     Max retries per step (default: 3)
  --timeout <seconds>   Timeout per generation (default: 120)
  --no-metrics          Disable metrics tracking
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt_path="$2"; shift 2 ;;
    --rubric) rubric_path="$2"; shift 2 ;;
    --work-dir) work_dir="$2"; shift 2 ;;
    --state-dir) state_dir="$2"; shift 2 ;;
    --backend) backend="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --skills) skills="$2"; shift 2 ;;
    --max-retries) max_retries="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --no-metrics) metrics_enabled=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) log_error "Unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

# Validate required args
[[ -z "$prompt_path" ]] && { log_error "Missing --prompt"; exit 2; }
[[ -z "$rubric_path" ]] && { log_error "Missing --rubric"; exit 2; }
[[ -z "$work_dir" ]] && { log_error "Missing --work-dir"; exit 2; }
[[ -z "$state_dir" ]] && { log_error "Missing --state-dir"; exit 2; }

# Set default model
if [[ -z "$model" ]]; then
  if [[ "$backend" == "codex" ]]; then
    model="o3"
  else
    model="claude-sonnet-4-20250514"
  fi
fi

# Create state directory
mkdir -p "$state_dir"

# ============================================================
# Step Parsing
# ============================================================

count_steps() {
  grep -c "^## Step [0-9]" "$1" || echo "0"
}

extract_step_content() {
  local prompt_file="$1"
  local step_num="$2"

  # Use Python for reliable step extraction (handles edge cases better than sed/awk on macOS)
  python3 - "$prompt_file" "$step_num" <<'PYEOF'
import sys
import re

prompt_file = sys.argv[1]
step_num = int(sys.argv[2])

with open(prompt_file, 'r') as f:
    content = f.read()

# Find all step markers
step_pattern = re.compile(r'^## Step (\d+)', re.MULTILINE)
matches = list(step_pattern.finditer(content))

# Find the position of our step
start_pos = None
end_pos = len(content)

for i, m in enumerate(matches):
    if int(m.group(1)) == step_num:
        # Start after the header line
        start_pos = content.find('\n', m.start()) + 1
        # End at next step or section boundary
        if i + 1 < len(matches):
            end_pos = matches[i + 1].start()
        else:
            # Look for next ## section that's not a Step
            next_section = re.search(r'^## [A-Z]', content[m.end():], re.MULTILINE)
            if next_section:
                end_pos = m.end() + next_section.start()
        break

if start_pos is not None:
    extracted = content[start_pos:end_pos].strip()
    # Remove trailing --- if present
    extracted = re.sub(r'\n---\s*$', '', extracted)
    print(extracted)
PYEOF
}

extract_preamble() {
  # Extract everything before "## Step 1"
  local prompt_file="$1"
  awk '/^## Step 1/ { exit } { print }' "$prompt_file"
}

# ============================================================
# Skill Loading
# ============================================================

load_skill_content() {
  local skill_name="$1"
  local skill_dir="$script_dir/../../skills/$skill_name"

  if [[ -d "$skill_dir" ]]; then
    # Load SKILL.md if exists
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

# ============================================================
# Code Generation
# ============================================================

build_step_prompt() {
  local step_num="$1"
  local total_steps="$2"
  local step_content="$3"
  local accumulated_code="$4"
  local error_feedback="$5"
  local output_file="$6"

  {
    echo "# Cairo Code Generation - Step $step_num of $total_steps"
    echo ""
    echo "## CRITICAL INSTRUCTIONS - READ FIRST"
    echo ""
    echo "**DO NOT RESEARCH OR EXPLORE THE CODEBASE.** Generate code immediately."
    echo ""
    echo "- You have ALL the information you need in this prompt"
    echo "- DO NOT run grep, rg, find, or any search commands"
    echo "- DO NOT read other files in the project"
    echo "- DO NOT spend time researching import paths - they are provided below"
    echo "- GENERATE CODE IMMEDIATELY based on the requirements"
    echo ""
    echo "If you run more than 2 commands before generating code, you are doing it wrong."
    echo ""

    # Embed skill content directly
    if [[ -n "$skills" ]]; then
      echo "## Cairo Language Reference"
      echo ""
      echo "Use this reference for correct Cairo syntax. DO NOT search for anything else."
      echo ""
      IFS=',' read -ra skill_arr <<< "$skills"
      for s in "${skill_arr[@]}"; do
        load_skill_content "$s"
      done
    fi

    echo "## Common Cairo Imports"
    echo ""
    echo "Import these (they are NOT in prelude):"
    echo '```cairo'
    echo "use core::array::{Array, ArrayTrait};"
    echo "use core::num::traits::{Zero, One};"
    echo '```'
    echo ""
    echo "DO NOT import these (they ARE in the prelude):"
    echo "- Add, Sub, Mul, Div, Neg (arithmetic operators)"
    echo "- Drop, Copy, Clone (memory traits)"
    echo "- PartialEq, PartialOrd (comparison)"
    echo "- Option, Some, None (option type)"
    echo "- Into, TryInto (conversions)"
    echo ""
    echo "## Generate code for THIS STEP ONLY"
    echo ""
    echo "Focus ONLY on Step $step_num. Do NOT skip ahead."
    echo ""

    if [[ -n "$accumulated_code" ]]; then
      echo "## Previously Verified Code (Steps 1-$((step_num-1)))"
      echo ""
      echo "This code has already been validated. Build on it, do not modify it."
      echo ""
      echo '```cairo'
      echo "$accumulated_code"
      echo '```'
      echo ""
    fi

    echo "## Step $step_num Requirements"
    echo ""
    echo "$step_content"
    echo ""

    if [[ -n "$error_feedback" ]]; then
      echo "## Previous Attempt Failed"
      echo ""
      echo "Your previous attempt for this step had errors:"
      echo ""
      echo '```'
      echo "$error_feedback"
      echo '```'
      echo ""
      echo "Fix these issues in your next attempt."
      echo ""
    fi

    echo "## Output Format - MANDATORY"
    echo ""
    if [[ "$backend" == "claude" ]]; then
      echo "**YOU MUST OUTPUT THE COMPLETE lib.cairo FILE IN A SINGLE \`\`\`cairo CODE BLOCK.**"
      echo ""
      echo "DO NOT explain what you would do. DO NOT describe the changes."
      echo "ONLY output the code block. Nothing else."
      echo ""
      echo "The code must include:"
      echo "- All previously verified code (if any)"
      echo "- Your new code for Step $step_num"
      echo ""
      echo "Start your response with \`\`\`cairo and end with \`\`\`"
      echo "Do not add any text before or after the code block."
    else
      echo "Return JSON: {\"code\": \"<complete lib.cairo content>\", \"notes\": \"<any notes>\"}"
      echo ""
      echo "The code field must contain the COMPLETE lib.cairo file including:"
      echo "- All previously verified code"
      echo "- Your new code for Step $step_num"
      echo ""
      echo "Do not include markdown code fences in the code field."
    fi
    echo ""
    echo "## REMINDER: Generate code NOW. Do not search or explore."
  } > "$output_file"
}

run_codex() {
  local prompt_file="$1"
  local output_file="$2"
  local jsonl_file="$3"
  local stderr_file="$4"

  local args=(exec - --output-last-message "$output_file" --json)
  args+=(--output-schema "$script_dir/../schema/code-output.schema.json")

  if [[ -n "$model" ]]; then
    args+=(--model "$model")
  fi

  # Add config options - disable features that slow down generation
  args+=(-c "features.web_search_request=false")
  args+=(-c "features.auto_context=false")  # Disable - we provide all context in prompt

  # Read prompt file directly - skill content is already embedded
  run_with_timeout "$timeout" codex "${args[@]}" < "$prompt_file" 2>"$stderr_file" | tee "$jsonl_file"
  return ${PIPESTATUS[1]}
}

run_claude() {
  local prompt_file="$1"
  local output_file="$2"
  local log_file="$3"
  local stderr_file="$4"

  # Use claude CLI with print mode for fast, non-interactive generation
  local args=(--print)

  if [[ -n "$model" ]]; then
    args+=(--model "$model")
  fi

  # Claude CLI reads from stdin with -p flag
  run_with_timeout "$timeout" claude "${args[@]}" -p "$(cat "$prompt_file")" > "$output_file" 2>"$stderr_file"
  local exit_code=$?

  # Log output
  cp "$output_file" "$log_file" 2>/dev/null || true

  return $exit_code
}

run_generation() {
  local prompt_file="$1"
  local output_file="$2"
  local log_file="$3"
  local stderr_file="$4"

  if [[ "$backend" == "claude" ]]; then
    run_claude "$prompt_file" "$output_file" "$log_file" "$stderr_file"
  else
    run_codex "$prompt_file" "$output_file" "$log_file" "$stderr_file"
  fi
}

extract_code_from_json() {
  local json_file="$1"
  jq -r '.code // empty' "$json_file" 2>/dev/null
}

extract_code_from_markdown() {
  local file="$1"
  # Extract code from ```cairo or ``` fenced blocks (first block found)
  # Try cairo-specific fence first
  local code=$(sed -n '/^```cairo/,/^```$/p' "$file" 2>/dev/null | sed '1d;$d')
  if [[ -n "$code" ]]; then
    echo "$code"
    return
  fi
  # Fallback to generic code block
  code=$(sed -n '/^```$/,/^```$/p' "$file" 2>/dev/null | sed '1d;$d')
  if [[ -n "$code" ]]; then
    echo "$code"
    return
  fi
  # Try any backtick fence
  sed -n '/^```/,/^```$/p' "$file" 2>/dev/null | sed '1d;$d'
}

extract_code() {
  local output_file="$1"

  if [[ "$backend" == "claude" ]]; then
    extract_code_from_markdown "$output_file"
  else
    extract_code_from_json "$output_file"
  fi
}

# ============================================================
# Project Scaffolding
# ============================================================

scaffold_project() {
  local project_dir="$1"

  # Use scarb new to create project structure
  if [[ -d "$project_dir" && -f "$project_dir/Scarb.toml" ]]; then
    log_warn "Project already exists with Scarb.toml, skipping scaffold"
    return 0
  fi

  local parent_dir=$(dirname "$project_dir")
  local dir_name=$(basename "$project_dir")

  # Convert dashes to underscores for valid Cairo package name
  local package_name=$(echo "$dir_name" | tr '-' '_')

  mkdir -p "$parent_dir"

  # Remove existing directory if it exists but has no Scarb.toml
  if [[ -d "$project_dir" ]]; then
    rm -rf "$project_dir"
  fi

  log_info "Scaffolding project '$package_name' at $project_dir..."

  # Create new project with scarb
  # --no-vcs: avoid nested git repos
  # --test-runner=starknet-foundry: includes snforge_std, test scripts, snfoundry.toml
  (cd "$parent_dir" && scarb new "$package_name" --no-vcs --test-runner=starknet-foundry) || {
    log_error "Failed to create project with scarb new"
    return 1
  }

  # Rename directory if package_name differs from dir_name (due to dash->underscore)
  if [[ "$package_name" != "$dir_name" && -d "$parent_dir/$package_name" ]]; then
    mv "$parent_dir/$package_name" "$project_dir"
  fi

  log_ok "Project scaffolded with scarb new"
  return 0
}

verify_project_setup() {
  local work_dir="$1"
  local error_file="$2"

  log_info "Verifying project setup..."

  # Check required files exist (scarb-generated structure)
  if [[ ! -f "$work_dir/Scarb.toml" ]]; then
    log_error "Missing Scarb.toml"
    return 1
  fi

  if [[ ! -f "$work_dir/src/lib.cairo" ]]; then
    log_error "Missing src/lib.cairo"
    return 1
  fi

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Verify scarb fmt --check works (checks formatting config)
  log_info "Checking formatting configuration..."
  if ! (cd "$work_dir" && scarb fmt --check 2>&1) > "$error_file" 2>&1; then
    log_warn "Formatting check failed (non-fatal)"
    # Non-fatal - continue with verification
  fi

  # Verify project builds
  log_info "Verifying project builds..."
  if ! (cd "$work_dir" && scarb build 2>&1) > "$error_file" 2>&1; then
    log_error "Project failed initial build check"
    cat "$error_file"
    return 1
  fi

  log_ok "Project setup verified"
  return 0
}

# ============================================================
# Formatting and Linting
# ============================================================

check_formatting() {
  local work_dir="$1"
  if (cd "$work_dir" && scarb fmt --check 2>&1); then
    log_ok "Formatting check passed"
    return 0
  else
    log_warn "Formatting issues detected (run 'scarb fmt' to fix)"
    return 1
  fi
}

run_linter() {
  local work_dir="$1"
  local output_file="$2"
  if command -v cairo-lint &>/dev/null || (cd "$work_dir" && scarb lint --help &>/dev/null 2>&1); then
    (cd "$work_dir" && scarb lint 2>&1) | tee "$output_file"
    return ${PIPESTATUS[0]}
  else
    log_info "Linter not available, skipping"
    return 0
  fi
}

# ============================================================
# Validation
# ============================================================

make_absolute() {
  local path="$1"
  local dir="$(dirname "$path")"
  local base="$(basename "$path")"

  # Ensure parent directory exists
  mkdir -p "$dir"

  # Get absolute path
  echo "$(cd "$dir" && pwd)/$base"
}

run_syntax_check() {
  local work_dir="$1"
  local code_content="$2"
  local error_file="$3"

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Write code to lib.cairo
  echo "$code_content" > "$work_dir/src/lib.cairo"

  # Run scarb check for fast syntax validation
  (cd "$work_dir" && scarb check 2>&1) > "$error_file" 2>&1
  return $?
}

validate_build() {
  local work_dir="$1"
  local code_content="$2"
  local error_file="$3"

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Write code to lib.cairo
  echo "$code_content" > "$work_dir/src/lib.cairo"

  # Run scarb check first for quick feedback
  log_info "Running syntax check (scarb check)..."
  if ! (cd "$work_dir" && scarb check 2>&1) > "$error_file" 2>&1; then
    log_warn "Syntax check failed - skipping full build"
    return 1
  fi
  log_ok "Syntax check passed"

  # Run full scarb build
  log_info "Running full build (scarb build)..."
  (cd "$work_dir" && scarb build 2>&1) > "$error_file" 2>&1
  return $?
}

validate_tests() {
  local work_dir="$1"
  local error_file="$2"

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Run snforge test from work directory, capture both stdout and stderr
  (cd "$work_dir" && snforge test 2>&1) > "$error_file" 2>&1
  local test_exit=$?

  # Extract and display pass/fail counts
  local passed=$(grep -c "^\[PASS\]" "$error_file" 2>/dev/null || echo 0)
  local failed=$(grep -c "^\[FAIL\]" "$error_file" 2>/dev/null || echo 0)
  local total=$((passed + failed))

  if [[ $total -gt 0 ]]; then
    if [[ $failed -gt 0 ]]; then
      log_warn "Test results: $passed passed, $failed failed (out of $total)"
    else
      log_ok "Test results: $passed passed, $failed failed (out of $total)"
    fi
  fi

  return $test_exit
}

# ============================================================
# Metrics Tracking
# ============================================================

metrics_path=""

init_metrics() {
  if [[ "$metrics_enabled" -ne 1 ]]; then
    return 0
  fi

  metrics_path="$state_dir/metrics.json"

  # Extract IDs from paths
  local prompt_id
  prompt_id="$(basename "$prompt_path" .md)"
  local rubric_id
  rubric_id="$(basename "$rubric_path" .md)"

  # Estimate tokens from prompt content
  local tokens_est
  tokens_est=$(estimate_tokens "$(cat "$prompt_path")")

  python3 "$script_dir/metrics.py" start \
    --prompt-id "$prompt_id" \
    --rubric-id "$rubric_id" \
    --output "$metrics_path" \
    --driver-backend "$backend" \
    --driver-model "$model" \
    --skills "$skills" \
    --steps-total "$total_steps" \
    --max-iterations "$max_retries" \
    --tokens "$tokens_est"
}

record_step_metrics() {
  if [[ "$metrics_enabled" -ne 1 ]] || [[ -z "$metrics_path" ]]; then
    return 0
  fi

  local step_num="$1"
  local status="$2"
  local duration="$3"
  local errors="${4:-}"

  local args=(--metrics-path "$metrics_path" --step-num "$step_num" --status "$status" --duration "$duration")
  if [[ -n "$errors" ]]; then
    args+=(--errors "$errors")
  fi

  python3 "$script_dir/metrics.py" step "${args[@]}"
}

record_iteration_metrics() {
  if [[ "$metrics_enabled" -ne 1 ]] || [[ -z "$metrics_path" ]]; then
    return 0
  fi

  local attempt_num="$1"
  local status="$2"
  local errors="${3:-}"
  local duration="${4:-0}"

  local args=(--metrics-path "$metrics_path" --attempt-num "$attempt_num" --status "$status")
  if [[ -n "$errors" ]]; then
    args+=(--errors "$errors")
  fi
  if [[ "$duration" != "0" ]]; then
    args+=(--duration "$duration")
  fi

  python3 "$script_dir/metrics.py" iteration "${args[@]}"
}

finalize_metrics() {
  if [[ "$metrics_enabled" -ne 1 ]] || [[ -z "$metrics_path" ]]; then
    return 0
  fi

  local status="$1"
  local final_code="${2:-}"

  local args=(--metrics-path "$metrics_path" --status "$status")
  if [[ -n "$final_code" ]]; then
    args+=(--final-code "$final_code")
  fi

  python3 "$script_dir/metrics.py" end "${args[@]}"
}

print_metrics_summary() {
  if [[ "$metrics_enabled" -ne 1 ]] || [[ -z "$metrics_path" ]]; then
    return 0
  fi

  python3 "$script_dir/metrics.py" summary --metrics-path "$metrics_path"
}

# ============================================================
# Main Loop
# ============================================================

total_steps=$(count_steps "$prompt_path")
log_info "Found $total_steps steps in prompt"

if [[ "$total_steps" -eq 0 ]]; then
  log_error "No steps found in prompt (looking for '## Step N' markers)"
  exit 2
fi

# Check for backend recommendation based on prompt content
prompt_content=$(cat "$prompt_path")
recommend_backend "$prompt_content" "$backend"

# Verify or scaffold project setup
setup_error_file="$state_dir/setup-errors.txt"
mkdir -p "$state_dir"

if [[ ! -f "$work_dir/Scarb.toml" ]]; then
  log_warn "No Scarb.toml found - scaffolding project"
  scaffold_project "$work_dir"
fi

if ! verify_project_setup "$work_dir" "$setup_error_file"; then
  log_error "Project setup verification failed. Check $setup_error_file"
  exit 2
fi

# Initialize metrics tracking
init_metrics

# Load or initialize state
state_file="$state_dir/step-state.json"
if [[ -f "$state_file" ]]; then
  current_step=$(jq -r '.current_step // 1' "$state_file")
  accumulated_code=$(jq -r '.accumulated_code // ""' "$state_file")
  log_info "Resuming from step $current_step"
else
  current_step=1
  accumulated_code=""
  echo '{"current_step": 1, "accumulated_code": ""}' > "$state_file"
fi

# Process each step
while [[ $current_step -le $total_steps ]]; do
  log_step "$current_step" "Processing step $current_step of $total_steps"

  step_dir="$state_dir/step-$(printf '%03d' $current_step)"
  mkdir -p "$step_dir"

  # Extract step content
  step_content=$(extract_step_content "$prompt_path" "$current_step")

  # Determine validation type based on step content
  if echo "$step_content" | grep -qi "snforge test\|tests pass"; then
    validation_type="test"
  else
    validation_type="build"
  fi

  retry=0
  error_feedback=""
  step_success=false
  step_start_time=$(date +%s)

  # Check context size before generation
  if [[ -n "$accumulated_code" ]]; then
    check_context_size "$accumulated_code"
  fi

  while [[ $retry -lt $max_retries ]]; do
    attempt=$((retry + 1))
    attempt_start_time=$(date +%s)
    log_info "Attempt $attempt of $max_retries"

    attempt_dir="$step_dir/attempt-$(printf '%03d' $attempt)"
    mkdir -p "$attempt_dir"

    # Build step prompt
    prompt_file="$attempt_dir/prompt.txt"
    build_step_prompt "$current_step" "$total_steps" "$step_content" \
                      "$accumulated_code" "$error_feedback" "$prompt_file"

    # Generate code
    if [[ "$backend" == "claude" ]]; then
      output_file="$attempt_dir/output.md"
      log_file="$attempt_dir/claude.log"
    else
      output_file="$attempt_dir/output.json"
      log_file="$attempt_dir/codex.jsonl"
    fi
    stderr_file="$attempt_dir/stderr.txt"

    log_info "Generating code..."
    set +e
    run_generation "$prompt_file" "$output_file" "$log_file" "$stderr_file"
    gen_exit=$?
    set -e

    if [[ $gen_exit -ne 0 ]] || [[ ! -s "$output_file" ]]; then
      log_warn "Generation failed (exit: $gen_exit)"
      error_feedback="Code generation failed or timed out"
      attempt_end_time=$(date +%s)
      attempt_duration=$((attempt_end_time - attempt_start_time))
      record_iteration_metrics "$attempt" "failed" "[\"Generation failed (exit: $gen_exit)\"]" "$attempt_duration"
      ((retry++))
      continue
    fi

    # Extract code
    new_code=$(extract_code "$output_file")
    if [[ -z "$new_code" ]]; then
      # Try recovery strategies if recover_output function is available
      if type -t recover_output &>/dev/null; then
        log_warn "Standard extraction failed, attempting recovery..."
        new_code=$(recover_output "$output_file")
        if [[ -n "$new_code" ]]; then
          log_ok "Recovery successful"
        fi
      fi
    fi
    if [[ -z "$new_code" ]]; then
      log_warn "No code in output (recovery also failed)"
      error_feedback="Output did not contain code (check for \`\`\`cairo blocks)"
      attempt_end_time=$(date +%s)
      attempt_duration=$((attempt_end_time - attempt_start_time))
      record_iteration_metrics "$attempt" "failed" "[\"No code extracted from output\"]" "$attempt_duration"
      ((retry++))
      continue
    fi

    # Save generated code
    echo "$new_code" > "$attempt_dir/code.cairo"

    # Validate
    error_file="$attempt_dir/errors.txt"
    log_info "Validating ($validation_type)..."

    set +e
    if [[ "$validation_type" == "test" ]]; then
      # First build, then test
      validate_build "$work_dir" "$new_code" "$error_file"
      build_exit=$?
      if [[ $build_exit -eq 0 ]]; then
        validate_tests "$work_dir" "$error_file"
        val_exit=$?
      else
        val_exit=$build_exit
      fi
    else
      validate_build "$work_dir" "$new_code" "$error_file"
      val_exit=$?
    fi
    set -e

    if [[ $val_exit -eq 0 ]]; then
      log_ok "Step $current_step passed validation!"

      # Run formatting check (non-blocking, just warn)
      log_info "Checking code formatting..."
      fmt_file="$attempt_dir/formatting.txt"
      check_formatting "$work_dir" > "$fmt_file" 2>&1 || true

      # Run linter if available (non-blocking, just warn)
      log_info "Running linter..."
      lint_file="$attempt_dir/lint.txt"
      run_linter "$work_dir" "$lint_file" || log_warn "Lint warnings detected (see $lint_file)"

      accumulated_code="$new_code"
      step_success=true

      # Record successful iteration
      attempt_end_time=$(date +%s)
      attempt_duration=$((attempt_end_time - attempt_start_time))
      record_iteration_metrics "$attempt" "success" "" "$attempt_duration"

      break
    else
      log_warn "Validation failed"
      error_feedback=$(cat "$error_file" 2>/dev/null | head -50)

      # Record failed iteration
      attempt_end_time=$(date +%s)
      attempt_duration=$((attempt_end_time - attempt_start_time))
      # Escape for JSON (basic escaping)
      escaped_feedback=$(echo "$error_feedback" | head -1 | tr -d '\n' | sed 's/"/\\"/g')
      record_iteration_metrics "$attempt" "failed" "[\"$escaped_feedback\"]" "$attempt_duration"

      ((retry++))
    fi
  done

  if [[ "$step_success" == "true" ]]; then
    # Record step completion metrics
    step_end_time=$(date +%s)
    step_duration=$((step_end_time - step_start_time))
    record_step_metrics "$current_step" "completed" "$step_duration"

    # Save state
    jq -n --arg step "$((current_step + 1))" --arg code "$accumulated_code" \
      '{"current_step": ($step | tonumber), "accumulated_code": $code}' > "$state_file"

    # Save verified code
    echo "$accumulated_code" > "$state_dir/verified-step-$(printf '%03d' $current_step).cairo"

    ((current_step++))
  else
    # Record step failure metrics
    step_end_time=$(date +%s)
    step_duration=$((step_end_time - step_start_time))
    record_step_metrics "$current_step" "failed" "$step_duration" "[\"Max retries exceeded\"]"

    log_error "Step $current_step failed after $max_retries attempts"

    # Finalize metrics with failure
    finalize_metrics "fail"
    print_metrics_summary

    exit 1
  fi
done

log_ok "All $total_steps steps completed successfully!"

# Save final code
final_code_path="$state_dir/final.cairo"
echo "$accumulated_code" > "$final_code_path"
cp "$accumulated_code" "$work_dir/src/lib.cairo" 2>/dev/null || echo "$accumulated_code" > "$work_dir/src/lib.cairo"

log_ok "Final code saved to $final_code_path"

# Finalize and display metrics
finalize_metrics "pass" "$final_code_path"
print_metrics_summary

exit 0
