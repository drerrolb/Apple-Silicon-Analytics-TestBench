#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# Kiraa AI — Generate Shared Benchmark Data
# ══════════════════════════════════════════════════════════════════════════════
#
# Generates the shared benchmark_data.csv deterministically (seed=42).
# This CSV is the single source of truth — both Python and Swift engines
# read from it to ensure identical data and consistent results.
#
# The CSV is also copied into the iOS app bundle (TestBench/Resources/)
# so Swift loads it at runtime.
#
# Usage:
#   ./generate_data.sh                  # Default: 10M rows
#   ./generate_data.sh 1000000          # Custom row count
#
# For the full pipeline (generate + Python benchmark + copy):
#   ./run_benchmark.sh
#
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
ROWS="${1:-10000000}"
CSV_FILE="$SCRIPT_DIR/benchmark_data.csv"
APP_RESOURCES="$SCRIPT_DIR/TestBench/Resources"

echo "══════════════════════════════════════════════════════════"
echo "  Kiraa AI — Generate Shared Benchmark Data"
echo "══════════════════════════════════════════════════════════"
echo ""

# Set up venv if needed
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pandas numpy

echo "  Rows:   $(printf "%'d" "$ROWS")"
echo "  Output: $CSV_FILE"
echo ""

python3 "$SCRIPT_DIR/generate_data.py" --rows "$ROWS" --output "$CSV_FILE"

# Copy to iOS app bundle
echo ""
mkdir -p "$APP_RESOURCES"
cp "$CSV_FILE" "$APP_RESOURCES/benchmark_data.csv"
echo "  Copied to $APP_RESOURCES/benchmark_data.csv"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Next steps:"
echo "    ./run_benchmark.sh --skip-generate   # Run Python on this data"
echo "    Open Xcode → Build → Run             # Swift loads the same CSV"
echo "══════════════════════════════════════════════════════════"
