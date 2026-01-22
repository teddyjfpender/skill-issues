#!/usr/bin/env bash
set -euo pipefail

dest_dir="${1:-}"
template_dir="${2:-}"

if [[ -z "$dest_dir" ]]; then
  echo "usage: eval/scaffold.sh <dest_dir> [template_dir]" >&2
  exit 2
fi

if [[ -n "$template_dir" ]]; then
  if [[ ! -d "$template_dir" ]]; then
    echo "template dir not found: $template_dir" >&2
    exit 2
  fi
  mkdir -p "$dest_dir"
  cp -R "$template_dir"/. "$dest_dir"/
  echo "scaffolded from template: $dest_dir"
  exit 0
fi

if ! command -v scarb >/dev/null 2>&1; then
  echo "scarb not found; install Scarb or pass a template dir" >&2
  exit 2
fi

test_runner="${SCARB_INIT_TEST_RUNNER:-none}"
base_name="$(basename "$dest_dir")"
pkg_name="$(echo "$base_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_]+/_/g; s/^_+//; s/_+$//')"
if [[ -z "$pkg_name" ]]; then
  pkg_name="pkg"
fi
if [[ "$pkg_name" =~ ^[0-9] ]]; then
  pkg_name="pkg_${pkg_name}"
fi

scarb_args=(--no-vcs --test-runner "$test_runner" --name "$pkg_name")

if [[ -d "$dest_dir" ]]; then
  if [[ -f "$dest_dir/Scarb.toml" ]]; then
    echo "Scarb project already exists: $dest_dir"
    python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_scarb_toml.py" "$dest_dir/Scarb.toml"
    exit 0
  fi
  mkdir -p "$dest_dir"
  (cd "$dest_dir" && scarb init "${scarb_args[@]}")
  python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_scarb_toml.py" "$dest_dir/Scarb.toml"
  echo "scaffolded Scarb project (init): $dest_dir"
  exit 0
fi

scarb new "${scarb_args[@]}" "$dest_dir"
python3 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ensure_scarb_toml.py" "$dest_dir/Scarb.toml"

echo "scaffolded Scarb project: $dest_dir"
