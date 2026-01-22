#!/usr/bin/env bash
set -euo pipefail

project_dir="${1:-}"
out_dir="${2:-}"

if [[ -z "$project_dir" || -z "$out_dir" ]]; then
  echo "usage: eval/verify.sh <project_dir> <out_dir>" >&2
  exit 2
fi

if [[ ! -d "$project_dir" ]]; then
  echo "project dir not found: $project_dir" >&2
  exit 2
fi

mkdir -p "$out_dir"
steps_file="$out_dir/steps.jsonl"
: > "$steps_file"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
start_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

record_step() {
  python3 "$script_dir/record_step.py" "$steps_file" "$@"
}

run_step() {
  local step="$1"; shift
  local stdout_path="$out_dir/${step}.out"
  local stderr_path="$out_dir/${step}.err"
  local cmd=("$@")

  if ! command -v "${cmd[0]}" >/dev/null 2>&1; then
    record_step "$step" "${cmd[*]}" "skipped" 127 0 "$stdout_path" "$stderr_path" "command not found"
    return 0
  fi

  local start_ts end_ts duration exit_code status
  start_ts=$(date +%s)
  set +e
  (cd "$project_dir" && "${cmd[@]}") >"$stdout_path" 2>"$stderr_path"
  exit_code=$?
  set -e
  end_ts=$(date +%s)
  duration=$((end_ts - start_ts))

  status="pass"
  if [[ $exit_code -ne 0 ]]; then
    status="fail"
  fi

  record_step "$step" "${cmd[*]}" "$status" "$exit_code" "$duration" "$stdout_path" "$stderr_path" ""
}

has_tests() {
  find "$project_dir" -type f -path "*/tests/*.cairo" -print -quit 2>/dev/null | grep -q .
}

if [[ ! -f "$project_dir/Scarb.toml" ]]; then
  record_step "precheck" "Scarb.toml present" "fail" 2 0 "" "" "Scarb.toml not found"
  end_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 "$script_dir/steps_to_verify.py" "$steps_file" "$out_dir/verify.json" "$start_iso" "$end_iso" "$project_dir"
  echo "verify.json: $out_dir/verify.json"
  exit 0
fi

run_step "format" scarb fmt
run_step "build" scarb build

if has_tests; then
  run_step "test" snforge test
else
  record_step "test" "snforge test" "skipped" 0 0 "" "" "no tests found"
fi

end_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 "$script_dir/steps_to_verify.py" "$steps_file" "$out_dir/verify.json" "$start_iso" "$end_iso" "$project_dir"

echo "verify.json: $out_dir/verify.json"
