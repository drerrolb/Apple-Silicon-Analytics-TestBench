#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# Kiraa AI — Benchmark Runner (Shared Data Pipeline)
# ══════════════════════════════════════════════════════════════════════════════
#
# Single entry point that ensures Python and Swift use IDENTICAL data:
#
#   1. Generate shared CSV (generate_data.py, deterministic seed=42)
#   2. Run Python benchmark against that CSV
#   3. Copy CSV + JSON results into iOS app bundle (Resources/)
#
# This guarantees both engines process the same transactions and produce
# comparable results (same running totals, same anomaly counts, same top
# suppliers).
#
# Usage:
#   ./run_benchmark.sh                    # Full pipeline (10M rows)
#   ./run_benchmark.sh --rows 1000000     # Custom row count
#   ./run_benchmark.sh --verbose          # Detailed Python output
#   ./run_benchmark.sh --skip-generate    # Reuse existing CSV
#
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
CSV_FILE="$SCRIPT_DIR/benchmark_data.csv"
RESULTS_JSON="$SCRIPT_DIR/benchmark_results_python.json"
APP_RESOURCES="$SCRIPT_DIR/TestBench/Resources"

# Parse our custom flags (pass remaining args to benchmark_python.py)
SKIP_GENERATE=false
ROWS=10000000
BENCHMARK_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --skip-generate)
            SKIP_GENERATE=true
            ;;
        *)
            BENCHMARK_ARGS+=("$arg")
            # Extract --rows value if present
            if [[ "$prev_arg" == "--rows" ]]; then
                ROWS="$arg"
            fi
            prev_arg="$arg"
            ;;
    esac
done

echo "══════════════════════════════════════════════════════════"
echo "  Kiraa AI — Benchmark Runner"
echo "  Shared Data Pipeline (Python + Swift)"
echo "══════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Set up Python virtual environment ────────────────────────────────

if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "  Created at $VENV_DIR"
else
    echo "  Virtual environment exists at $VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pandas numpy tqdm
echo "  Python:  $(python3 --version 2>&1)"
echo "  pandas:  $(python3 -c 'import pandas; print(pandas.__version__)')"
echo "  numpy:   $(python3 -c 'import numpy; print(numpy.__version__)')"
echo ""

# ── Step 2: Generate shared CSV ──────────────────────────────────────────────

if [ "$SKIP_GENERATE" = true ] && [ -f "$CSV_FILE" ]; then
    echo "  Reusing existing CSV: $CSV_FILE"
    echo "  Size: $(du -h "$CSV_FILE" | cut -f1)"
    echo ""
else
    echo "  Generating shared dataset..."
    echo "──────────────────────────────────────────────────────────"
    python3 "$SCRIPT_DIR/generate_data.py" --rows "$ROWS" --output "$CSV_FILE"
    echo "──────────────────────────────────────────────────────────"
    echo ""
fi

# ── Step 3: Run Python benchmark against shared CSV ──────────────────────────

echo "  Running Python benchmark on shared CSV..."
echo "══════════════════════════════════════════════════════════"
echo ""

python3 "$SCRIPT_DIR/benchmark_python.py" --from-csv "$CSV_FILE" "${BENCHMARK_ARGS[@]}"

echo ""

# ── Step 4: Copy results to iOS app bundle ───────────────────────────────────

echo "══════════════════════════════════════════════════════════"
echo "  Copying results to iOS app bundle..."
echo "──────────────────────────────────────────────────────────"

mkdir -p "$APP_RESOURCES"

if [ -f "$RESULTS_JSON" ]; then
    cp "$RESULTS_JSON" "$APP_RESOURCES/benchmark_results_python.json"
    echo "  JSON:  $APP_RESOURCES/benchmark_results_python.json"
fi

if [ -f "$CSV_FILE" ]; then
    cp "$CSV_FILE" "$APP_RESOURCES/benchmark_data.csv"
    echo "  CSV:   $APP_RESOURCES/benchmark_data.csv"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Pipeline complete."
echo ""
echo "  Both engines will now use identical data:"
echo "    - Python results: benchmark_results_python.json"
echo "    - Shared data:    benchmark_data.csv"
echo ""
echo "  Rebuild the Xcode project to include updated resources."
echo "══════════════════════════════════════════════════════════"
