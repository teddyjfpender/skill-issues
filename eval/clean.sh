#!/bin/bash
# Clean up work and results directories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "$SCRIPT_DIR/work" "$SCRIPT_DIR/results"

echo "Cleaned work/ and results/ directories"
