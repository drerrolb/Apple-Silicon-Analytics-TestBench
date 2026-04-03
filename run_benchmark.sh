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
#   4. Print validation summary from JSON for verification
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
prev_arg=""

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

# ── Step 5: Post-pipeline validation from JSON ──────────────────────────────

if [ -f "$RESULTS_JSON" ]; then
    JSON_SIZE=$(du -h "$RESULTS_JSON" | cut -f1)
    CSV_SIZE="N/A"
    if [ -f "$CSV_FILE" ]; then
        CSV_SIZE=$(du -h "$CSV_FILE" | cut -f1)
    fi

    echo "══════════════════════════════════════════════════════════"
    echo "  PIPELINE VALIDATION"
    echo "──────────────────────────────────────────────────────────"

    python3 -c "
import json, sys
with open('$RESULTS_JSON') as f:
    d = json.load(f)

ts = d.get('timestamp', d.get('json_generated_at', 'unknown'))
total = d.get('total_time_ms', 0)
records = d.get('total_records', 0)
throughput = d.get('throughput_rps', 0)
tasks = d.get('tasks', [])
memory = d.get('peak_memory_mb', 0)
seed = d.get('seed', '?')
source = d.get('data_source', '?')
machine = d.get('machine_name', '?')
cpu = d.get('cpu_model', '?')

# Extract key validation values from task details
anomalies = 0
running_total = 0
top_supplier = '?'
for t in tasks:
    details = t.get('details', {})
    if 'anomaly_count' in details:
        anomalies = details['anomaly_count']
    if 'running_total' in details:
        running_total = details['running_total']
    if 'top_10' in details and details['top_10']:
        top_supplier = f\"{details['top_10'][0]['supplier_id']} (\${details['top_10'][0]['total']:,.2f})\"

minutes = total / 60000

print(f'    Timestamp:       {ts}')
print(f'    Machine:         {machine}')
print(f'    CPU:             {cpu}')
print(f'    Data source:     {source}')
print(f'    Seed:            {seed}')
print(f'    Records:         {records:,}')
print(f'    Total time:      {total:,.1f} ms ({minutes:.1f}m)')
print(f'    Throughput:      {throughput:,.0f} rec/s')
print(f'    Tasks:           {len(tasks)}')
print(f'    Anomalies:       {anomalies:,}')
print(f'    Running total:   \${running_total:,.2f}')
print(f'    Top supplier:    {top_supplier}')
print(f'    Peak memory:     {memory:.1f} MB')
print()
print(f'    Per-task breakdown:')
for t in tasks:
    pct = t['time_ms'] / total * 100 if total > 0 else 0
    print(f'      {t[\"name\"]:<35} {t[\"time_ms\"]:>10,.1f} ms ({pct:.1f}%)')
"

    echo ""
    echo "    JSON file:       $RESULTS_JSON ($JSON_SIZE)"
    echo "    CSV file:        $CSV_FILE ($CSV_SIZE)"
    echo "──────────────────────────────────────────────────────────"
fi

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Pipeline complete."
echo ""
echo "  Both engines will now use identical data."
echo "  Rebuild the Xcode project to include updated resources."
echo "══════════════════════════════════════════════════════════"
