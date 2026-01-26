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
NC='\033[0m'

log_step()  { echo -e "${CYAN}[STEP $1]${NC} $2"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }

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

validate_build() {
  local work_dir="$1"
  local code_content="$2"
  local error_file="$3"

  # Convert to absolute paths
  work_dir="$(cd "$work_dir" && pwd)"
  error_file="$(make_absolute "$error_file")"

  # Write code to lib.cairo
  echo "$code_content" > "$work_dir/src/lib.cairo"

  # Run scarb build from work directory, capture both stdout and stderr
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
  return $?
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

  while [[ $retry -lt $max_retries ]]; do
    attempt=$((retry + 1))
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
      ((retry++))
      continue
    fi

    # Extract code
    new_code=$(extract_code "$output_file")
    if [[ -z "$new_code" ]]; then
      log_warn "No code in output"
      error_feedback="Output did not contain code (check for \`\`\`cairo blocks)"
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
      accumulated_code="$new_code"
      step_success=true
      break
    else
      log_warn "Validation failed"
      error_feedback=$(cat "$error_file" 2>/dev/null | head -50)
      ((retry++))
    fi
  done

  if [[ "$step_success" == "true" ]]; then
    # Save state
    jq -n --arg step "$((current_step + 1))" --arg code "$accumulated_code" \
      '{"current_step": ($step | tonumber), "accumulated_code": $code}' > "$state_file"

    # Save verified code
    echo "$accumulated_code" > "$state_dir/verified-step-$(printf '%03d' $current_step).cairo"

    ((current_step++))
  else
    log_error "Step $current_step failed after $max_retries attempts"
    exit 1
  fi
done

log_ok "All $total_steps steps completed successfully!"

# Save final code
echo "$accumulated_code" > "$state_dir/final.cairo"
cp "$accumulated_code" "$work_dir/src/lib.cairo" 2>/dev/null || echo "$accumulated_code" > "$work_dir/src/lib.cairo"

log_ok "Final code saved to $state_dir/final.cairo"
exit 0
