#!/usr/bin/env bash
set -euo pipefail

work_root="${1:-eval/work}"
results_root="${2:-eval/results/$(date -u +%Y-%m-%d)}"

if [[ ! -d "$work_root" ]]; then
  echo "work root not found: $work_root" >&2
  exit 2
fi

mkdir -p "$results_root"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for dir in "$work_root"/*; do
  [[ -d "$dir" ]] || continue
  prompt_id="$(basename "$dir")"
  out_dir="$results_root/$prompt_id"
  mkdir -p "$out_dir"
  "$script_dir/verify.sh" "$dir" "$out_dir"
done

echo "results: $results_root"
