#!/usr/bin/env bash
#
# recover-output.sh - Output format recovery functions
#
# Based on improvement doc 022 (output-format-enforcement.md)
# Provides functions to recover and validate LLM output format
# when extraction fails.
#
# Usage:
#   source "$script_dir/recover-output.sh"
#   recovered=$(recover_output "$raw_output")
#
# Functions:
#   recover_missing_fence     - Wrap raw Cairo code in fences
#   extract_largest_block     - Extract largest code block from multiple
#   validate_output_format    - Check if output has valid cairo code block
#   test_format_compliance    - Run all checks and output report
#   recover_output            - Main function, attempts all recovery strategies

# ============================================================
# Recovery Functions
# ============================================================

# recover_missing_fence()
# If output has no ```cairo block but looks like Cairo code
# (starts with `use core::` or `pub `), wrap it in fences.
#
# Arguments:
#   $1 - Raw output content (string)
#
# Output:
#   Recovered content with fences (or original if no recovery needed)
#
recover_missing_fence() {
  local content="$1"

  # If already has code fences, return as-is
  if echo "$content" | grep -q '```'; then
    echo "$content"
    return 0
  fi

  # Check if content looks like Cairo code
  if echo "$content" | grep -qE '^(use core::|pub |mod |fn |impl |trait |struct |enum )'; then
    # Wrap in cairo fences
    printf '%s\n%s\n%s\n' '```cairo' "$content" '```'
    return 0
  fi

  # No recovery possible
  echo "$content"
  return 1
}

# extract_largest_block()
# If multiple code blocks exist, extract the largest one.
#
# Arguments:
#   $1 - Content with multiple code blocks (string)
#
# Output:
#   Content of the largest code block (without fence markers)
#
extract_largest_block() {
  local content="$1"

  # Use Python for reliable multi-block extraction
  python3 - "$content" <<'PYEOF'
import sys
import re

content = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()

# Find all code blocks (```cairo ... ``` or ``` ... ```)
# Pattern matches fenced code blocks
pattern = re.compile(r'```(?:cairo)?\s*\n(.*?)```', re.DOTALL)
matches = pattern.findall(content)

if not matches:
    # No blocks found, return empty
    sys.exit(1)

# Find the largest block
largest = max(matches, key=len)
print(largest.strip())
PYEOF
}

# validate_output_format()
# Check if output has valid cairo code block.
#
# Arguments:
#   $1 - File path to output file
#   $2 - Backend type (claude or codex) - optional, defaults to claude
#
# Returns:
#   0 for valid format, 1 for invalid
#
# Output:
#   Error message if invalid (on stderr)
#
validate_output_format() {
  local output_file="$1"
  local backend="${2:-claude}"

  if [[ ! -f "$output_file" ]]; then
    echo "File not found: $output_file" >&2
    return 1
  fi

  if [[ "$backend" == "claude" ]]; then
    # Check for cairo code block
    if ! grep -q '```cairo' "$output_file"; then
      # Try generic code block
      if ! grep -q '```' "$output_file"; then
        echo "Missing code block" >&2
        return 1
      fi
    fi

    # Check block is not empty
    local code
    code=$(sed -n '/```cairo/,/```$/p' "$output_file" 2>/dev/null | sed '1d;$d')
    if [[ -z "$code" ]]; then
      # Try generic fence
      code=$(sed -n '/```/,/```$/p' "$output_file" 2>/dev/null | sed '1d;$d')
    fi

    if [[ -z "$code" ]]; then
      echo "Empty code block" >&2
      return 1
    fi

    return 0

  else
    # Codex backend - check for valid JSON
    if ! jq -e '.code' "$output_file" > /dev/null 2>&1; then
      echo "Invalid JSON or missing 'code' field" >&2
      return 1
    fi

    # Check code field is not empty
    local code
    code=$(jq -r '.code // ""' "$output_file" 2>/dev/null)
    if [[ -z "$code" ]]; then
      echo "Empty code field in JSON" >&2
      return 1
    fi

    return 0
  fi
}

# test_format_compliance()
# Run all format checks and output a report.
#
# Arguments:
#   $1 - File path to output file (or - for stdin)
#
# Output:
#   Compliance report to stdout
#
# Returns:
#   0 if all checks pass, 1 if any fail
#
test_format_compliance() {
  local input="$1"
  local content
  local all_pass=0

  if [[ "$input" == "-" ]]; then
    content=$(cat)
  elif [[ -f "$input" ]]; then
    content=$(cat "$input")
  else
    content="$input"
  fi

  echo "=== Format Compliance Report ==="
  echo ""

  # Test 1: Has cairo block
  if echo "$content" | grep -q '```cairo'; then
    echo "[PASS] Has \`\`\`cairo block"
  elif echo "$content" | grep -q '```'; then
    echo "[WARN] Has generic code block (not \`\`\`cairo)"
  else
    echo "[FAIL] Missing code block"
    all_pass=1
  fi

  # Test 2: Starts with code block (no preamble)
  local first_line
  first_line=$(echo "$content" | head -1 | tr -d '\r')
  if [[ "$first_line" == '```cairo' ]]; then
    echo "[PASS] Starts with \`\`\`cairo (no preamble)"
  elif [[ "$first_line" == '```' ]]; then
    echo "[WARN] Starts with generic fence"
  else
    echo "[FAIL] Has preamble text before code block"
    all_pass=1
  fi

  # Test 3: Ends with code block (no postamble)
  local last_line
  last_line=$(echo "$content" | tail -1 | tr -d '\r')
  if [[ "$last_line" == '```' ]]; then
    echo "[PASS] Ends with \`\`\` (no postamble)"
  else
    echo "[FAIL] Has postamble text after code block"
    all_pass=1
  fi

  # Test 4: Content looks like Cairo code
  local code_content
  code_content=$(echo "$content" | sed -n '/```/,/```$/p' | sed '1d;$d')
  if echo "$code_content" | grep -qE '^(use |pub |fn |impl |trait |struct |enum |mod )'; then
    echo "[PASS] Content looks like Cairo code"
  else
    echo "[WARN] Content may not be valid Cairo code"
  fi

  echo ""
  if [[ $all_pass -eq 0 ]]; then
    echo "Result: COMPLIANT"
  else
    echo "Result: NON-COMPLIANT"
  fi

  return $all_pass
}

# recover_output()
# Main function that attempts all recovery strategies and outputs the best result.
#
# Arguments:
#   $1 - Raw output content (string or file path)
#
# Output:
#   Recovered Cairo code (without fence markers), or empty if unrecoverable
#
# Returns:
#   0 if recovery successful, 1 if no code could be extracted
#
recover_output() {
  local input="$1"
  local content

  # Handle file path or raw content
  if [[ -f "$input" ]]; then
    content=$(cat "$input")
  else
    content="$input"
  fi

  # Strategy 1: Try standard extraction (cairo-specific fence)
  local extracted
  extracted=$(echo "$content" | sed -n '/^```cairo/,/^```$/p' 2>/dev/null | sed '1d;$d')
  if [[ -n "$extracted" ]]; then
    echo "$extracted"
    return 0
  fi

  # Strategy 2: Try generic fence extraction
  extracted=$(echo "$content" | sed -n '/^```/,/^```$/p' 2>/dev/null | sed '1d;$d')
  if [[ -n "$extracted" ]]; then
    echo "$extracted"
    return 0
  fi

  # Strategy 3: If multiple blocks exist, extract the largest
  if echo "$content" | grep -c '```' | grep -q '[2-9]'; then
    extracted=$(extract_largest_block "$content")
    if [[ -n "$extracted" ]]; then
      echo "$extracted"
      return 0
    fi
  fi

  # Strategy 4: Try to recover missing fences
  local recovered
  recovered=$(recover_missing_fence "$content")
  if [[ "$recovered" != "$content" ]]; then
    # Fences were added, extract the code
    extracted=$(echo "$recovered" | sed -n '/^```cairo/,/^```$/p' 2>/dev/null | sed '1d;$d')
    if [[ -n "$extracted" ]]; then
      echo "$extracted"
      return 0
    fi
  fi

  # Strategy 5: Last resort - if content looks like Cairo, return it directly
  if echo "$content" | grep -qE '^(use core::|pub |mod |fn |impl )'; then
    # Filter out any obvious non-code lines (explanations)
    echo "$content" | grep -vE '^(I |The |This |Here |Note:|//.*implementing|//.*changes)'
    return 0
  fi

  # No recovery possible
  return 1
}

# ============================================================
# Self-test (when run directly)
# ============================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being run directly, not sourced

  case "${1:-}" in
    --test)
      echo "Running self-tests..."
      echo ""

      # Test 1: Standard cairo block
      echo "Test 1: Standard cairo block"
      test_content=$'```cairo\nuse core::array::Array;\npub fn test() {}\n```'
      result=$(recover_output "$test_content")
      if [[ "$result" == *"use core::array::Array"* ]]; then
        echo "  PASS"
      else
        echo "  FAIL: $result"
      fi

      # Test 2: Missing fences
      echo "Test 2: Missing fences (raw Cairo)"
      test_content=$'use core::array::Array;\npub fn test() {}'
      result=$(recover_output "$test_content")
      if [[ "$result" == *"use core::array::Array"* ]]; then
        echo "  PASS"
      else
        echo "  FAIL: $result"
      fi

      # Test 3: Multiple blocks
      echo "Test 3: Multiple blocks (extract largest)"
      test_content=$'```cairo\nsmall\n```\n\n```cairo\nuse core::array::Array;\npub fn test() {\n  let x = 1;\n}\n```'
      result=$(recover_output "$test_content")
      if [[ "$result" == *"let x = 1"* ]]; then
        echo "  PASS"
      else
        echo "  FAIL: $result"
      fi

      # Test 4: Format compliance
      echo "Test 4: Format compliance check"
      test_content=$'```cairo\nuse core::array::Array;\n```'
      echo "$test_content" | test_format_compliance - > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
        echo "  PASS"
      else
        echo "  FAIL"
      fi

      echo ""
      echo "Self-tests complete."
      ;;

    --validate)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 --validate <file>" >&2
        exit 1
      fi
      validate_output_format "$2" "${3:-claude}"
      ;;

    --compliance)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 --compliance <file>" >&2
        exit 1
      fi
      test_format_compliance "$2"
      ;;

    --recover)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 --recover <file>" >&2
        exit 1
      fi
      recover_output "$2"
      ;;

    --help|-h|"")
      cat <<EOF
recover-output.sh - Output format recovery functions

Usage:
  Source this file:
    source recover-output.sh
    recovered=\$(recover_output "\$raw_output")

  Or run directly:
    $0 --test                    Run self-tests
    $0 --validate <file> [backend]  Validate output format
    $0 --compliance <file>       Run format compliance check
    $0 --recover <file>          Attempt to recover code from file

Functions (when sourced):
  recover_missing_fence <content>   Wrap raw Cairo in fences
  extract_largest_block <content>   Extract largest code block
  validate_output_format <file>     Check format validity (0=valid, 1=invalid)
  test_format_compliance <file>     Output compliance report
  recover_output <content|file>     Main recovery function
EOF
      ;;

    *)
      echo "Unknown command: $1" >&2
      echo "Use --help for usage." >&2
      exit 1
      ;;
  esac
fi
