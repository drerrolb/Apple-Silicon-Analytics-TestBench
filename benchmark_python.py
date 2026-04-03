#!/usr/bin/env python3
"""
ERP Aggregation Benchmark — Python Baseline (CPU)
Kiraa AI
======================================================================

Runs 5 common ERP aggregation tasks over 10M rows using Python
for-loops to demonstrate interpreter overhead vs compiled code.

Tasks:
  1. Total spend by cost centre (group-by → sum)
  2. Top 10 suppliers by spend (group-by → sum → sort)
  3. Anomaly detection (per-row z-score, flag |z| > 3.5)
  4. Plant × cost centre pivot (48-cell cross-tab)
  5. Running total (cumulative sum)

Usage:
    python3 benchmark_python.py                    # Generate 10M rows
    python3 benchmark_python.py --from-csv data.csv # Load from CSV
    python3 benchmark_python.py --verbose           # Show sample outputs
    python3 benchmark_python.py --rows 1000000      # Custom size
"""

import argparse
import datetime
import json
import math
import os
import platform
import sys
import time
import warnings

import numpy as np
import pandas as pd
from tqdm import tqdm

warnings.filterwarnings("ignore")

# ── Config ────────────────────────────────────────────────────────────────────

NUM_ROWS    = 10_000_000
RANDOM_SEED = 42
Z_THRESHOLD = 3.5

COST_CENTRES = [
    "RAW_MATERIALS", "PACKAGING", "LOGISTICS", "LABOUR",
    "OVERHEADS", "CAPEX", "MAINTENANCE", "UTILITIES",
    "PROCUREMENT", "SALES", "MARKETING", "ADMIN"
]
TRANSACTION_TYPES = [
    "PURCHASE_ORDER", "INVOICE_MATCH", "VARIANCE_FLAG",
    "ACCRUAL", "PAYMENT_RUN", "INTERCOMPANY", "CREDIT_NOTE"
]
PLANT_CODES = ["GOLD_COAST", "SYDNEY", "MELBOURNE", "BRISBANE"]

# ── Machine metadata ──────────────────────────────────────────────────────────

def collect_machine_info() -> dict:
    info = {
        "timestamp":      datetime.datetime.now().isoformat(),
        "machine_name":   platform.node(),
        "os_version":     f"{platform.system()} {platform.release()}",
        "cpu_model":      platform.processor() or "Unknown",
        "cpu_count":      os.cpu_count(),
        "python_version": platform.python_version(),
    }
    if platform.system() == "Darwin":
        try:
            import subprocess
            info["cpu_model"] = subprocess.check_output(
                ["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
        except Exception:
            pass
    return info

# ── Data generation ───────────────────────────────────────────────────────────

def generate_data(n_rows, verbose=False):
    """Generate synthetic ERP transactions (deterministic, seed=42)."""
    rng = np.random.default_rng(RANDOM_SEED)

    cost_centre = rng.choice(COST_CENTRES, size=n_rows)
    txn_type = rng.choice(TRANSACTION_TYPES, size=n_rows)
    plant_code = rng.choice(PLANT_CODES, size=n_rows)
    supplier_id = rng.integers(1000, 9999, size=n_rows)

    base_amounts = {cc: rng.uniform(5_000, 500_000) for cc in COST_CENTRES}
    amounts = np.array([
        rng.normal(loc=base_amounts[cc], scale=base_amounts[cc] * 0.15)
        for cc in cost_centre
    ])

    # Inject 0.2% anomalies
    n_anom = int(n_rows * 0.002)
    anom_idx = rng.choice(n_rows, size=n_anom, replace=False)
    amounts[anom_idx] *= rng.choice([8.0, 12.0, -5.0, 15.0], size=n_anom)

    df = pd.DataFrame({
        "amount": amounts,
        "cost_centre": cost_centre,
        "cost_centre_id": [COST_CENTRES.index(cc) for cc in cost_centre],
        "txn_type": txn_type,
        "supplier_id": supplier_id,
        "plant_code": plant_code,
        "plant_code_id": [PLANT_CODES.index(p) for p in plant_code],
    })

    if verbose:
        print(f"\n  Sample data:\n{df.head().to_string(index=False)}")

    return df

def load_csv(path):
    """Load from shared CSV (numeric IDs), map back to names."""
    csv_df = pd.read_csv(path)
    csv_df["cost_centre"] = csv_df["cost_centre_id"].map(
        {i: cc for i, cc in enumerate(COST_CENTRES)})
    csv_df["plant_code"] = csv_df["plant_code_id"].map(
        {i: p for i, p in enumerate(PLANT_CODES)})
    return csv_df

# ── Task 1: Total by cost centre ─────────────────────────────────────────────

def task1_total_by_cost_centre(df, verbose=False):
    """Group by cost centre → sum(amount). Pure Python loop."""
    totals = {}
    for _, row in df.iterrows():
        cc = row["cost_centre"]
        totals[cc] = totals.get(cc, 0.0) + row["amount"]

    if verbose:
        print("\n    Cost centre totals:")
        for cc in COST_CENTRES:
            print(f"      {cc:<18} ${totals.get(cc, 0):>16,.2f}")

    return totals

# ── Task 2: Top 10 suppliers ─────────────────────────────────────────────────

def task2_top_suppliers(df, verbose=False):
    """Group by supplier_id → sum(amount), return top 10."""
    totals = {}
    for _, row in df.iterrows():
        sid = int(row["supplier_id"])
        totals[sid] = totals.get(sid, 0.0) + row["amount"]

    top10 = sorted(totals.items(), key=lambda x: x[1], reverse=True)[:10]

    if verbose:
        print("\n    Top 10 suppliers:")
        for sid, amt in top10:
            print(f"      Supplier {sid}: ${amt:>16,.2f}")

    return top10

# ── Task 3: Z-score anomaly detection ────────────────────────────────────────

def task3_anomaly_detection(df, verbose=False):
    """Per-row z-score: (amount - cc_mean) / cc_std. Count |z| > 3.5."""
    # Compute baselines first (this is fast, done via pandas)
    baselines = {}
    for cc in COST_CENTRES:
        subset = df[df["cost_centre"] == cc]["amount"]
        baselines[cc] = {"mean": float(subset.mean()), "std": float(subset.std())}

    # Score each row in a Python loop
    anomaly_count = 0
    for _, row in df.iterrows():
        bl = baselines[row["cost_centre"]]
        z = (row["amount"] - bl["mean"]) / bl["std"] if bl["std"] > 0 else 0.0
        if abs(z) > Z_THRESHOLD:
            anomaly_count += 1

    if verbose:
        print(f"\n    Baselines used:")
        for cc in COST_CENTRES[:3]:
            bl = baselines[cc]
            print(f"      {cc}: mean=${bl['mean']:,.2f}, std=${bl['std']:,.2f}")
        print(f"      ...")
        print(f"    Anomalies (|z| > {Z_THRESHOLD}): {anomaly_count:,}")

    return anomaly_count, baselines

# ── Task 4: Plant × cost centre pivot ────────────────────────────────────────

def task4_pivot(df, verbose=False):
    """Group by (plant, cost_centre) → sum(amount). 4×12 = 48 cells."""
    pivot = {}
    for _, row in df.iterrows():
        key = (row["plant_code"], row["cost_centre"])
        pivot[key] = pivot.get(key, 0.0) + row["amount"]

    if verbose:
        print(f"\n    Pivot table ({len(pivot)} cells):")
        for plant in PLANT_CODES[:2]:
            for cc in COST_CENTRES[:3]:
                val = pivot.get((plant, cc), 0)
                print(f"      {plant}/{cc}: ${val:>14,.2f}")
            print(f"      ...")

    return pivot

# ── Task 5: Running total ────────────────────────────────────────────────────

def task5_running_total(df, verbose=False):
    """Cumulative sum over all amounts in order."""
    running = 0.0
    for _, row in df.iterrows():
        running += row["amount"]

    if verbose:
        print(f"\n    Final running total: ${running:>20,.2f}")

    return running

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Kiraa AI — ERP Aggregation Benchmark (Python)")
    parser.add_argument("--verbose", "-v", action="store_true")
    parser.add_argument("--rows", type=int, default=NUM_ROWS)
    parser.add_argument("--from-csv", type=str, default=None, metavar="PATH")
    parser.add_argument("--export-csv", type=str, default=None, metavar="PATH",
                        help="Export generated data to CSV for sharing with Swift")
    args = parser.parse_args()

    print("=" * 60)
    print("  Kiraa AI — ERP Aggregation Benchmark")
    print("  Python Baseline (CPU) — Row-by-Row Loops")
    print("=" * 60)

    machine = collect_machine_info()
    print(f"\n  Machine:  {machine['machine_name']}")
    print(f"  CPU:      {machine['cpu_model']}")
    print(f"  Python:   {machine['python_version']}")
    print(f"  OS:       {machine['os_version']}")
    print(f"  Cores:    {machine['cpu_count']}")
    print(f"  Time:     {machine['timestamp']}")

    # Load or generate data
    data_source = None
    data_gen_time_ms = 0

    if args.from_csv:
        data_source = args.from_csv
        print(f"\n  Loading data from {args.from_csv}...")
        t0 = time.perf_counter()
        df = load_csv(args.from_csv)
        load_time = time.perf_counter() - t0
        data_gen_time_ms = load_time * 1000
        print(f"  Loaded {len(df):,} rows in {load_time:.2f}s")
    else:
        data_source = "in-memory (generated)"
        print(f"\n  Generating {args.rows:,} rows (seed={RANDOM_SEED})...")
        t0 = time.perf_counter()
        df = generate_data(args.rows, verbose=args.verbose)
        load_time = time.perf_counter() - t0
        data_gen_time_ms = load_time * 1000
        print(f"  Generated {len(df):,} rows in {load_time:.2f}s")

    n_rows = len(df)
    mem_mb = df.memory_usage(deep=True).sum() / 1_048_576
    print(f"  Memory: {mem_mb:.0f} MB")

    # ── Data summary ─────────────────────────────────────────────────────
    print(f"\n  {'─' * 50}")
    print(f"  Data Summary:")
    print(f"    Source:            {data_source}")
    print(f"    Rows:              {n_rows:,}")
    print(f"    Amount range:      ${df['amount'].min():>14,.2f} to ${df['amount'].max():>14,.2f}")
    print(f"    Amount mean:       ${df['amount'].mean():>14,.2f}")
    print(f"    Amount sum:        ${df['amount'].sum():>14,.2f}")
    print(f"    Unique suppliers:  {df['supplier_id'].nunique():,}")
    print(f"    Cost centres:      {df['cost_centre'].nunique()}")
    print(f"    Plant codes:       {df['plant_code'].nunique()}")
    print(f"  {'─' * 50}")

    # Export to CSV if requested
    if args.export_csv:
        print(f"\n  Exporting {n_rows:,} rows to {args.export_csv}...")
        out = pd.DataFrame({
            "amount": df["amount"],
            "cost_centre_id": df["cost_centre_id"] if "cost_centre_id" in df.columns
                else df["cost_centre"].map({cc: i for i, cc in enumerate(COST_CENTRES)}),
            "txn_type_id": df["txn_type"].map({t: i for i, t in enumerate(TRANSACTION_TYPES)})
                if "txn_type" in df.columns else 0,
            "supplier_id": df["supplier_id"],
            "plant_code_id": df["plant_code_id"] if "plant_code_id" in df.columns
                else df["plant_code"].map({p: i for i, p in enumerate(PLANT_CODES)}),
        })
        out.to_csv(args.export_csv, index=False)
        size_mb = os.path.getsize(args.export_csv) / 1_048_576
        print(f"  Exported {n_rows:,} rows ({size_mb:.1f} MB)")

    # Run tasks
    tasks = [
        ("Total by cost centre",      task1_total_by_cost_centre),
        ("Top 10 suppliers by spend",  task2_top_suppliers),
        ("Z-score anomaly detection",  task3_anomaly_detection),
        ("Plant × cost centre pivot",  task4_pivot),
        ("Running total",              task5_running_total),
    ]

    print(f"\n{'═' * 60}")
    print(f"  Running 5 aggregation tasks ({n_rows:,} rows each)")
    print(f"  Method: Python for-loop (row-by-row, NO vectorization)")
    print(f"{'═' * 60}")

    task_results = []
    total_time = 0.0

    # Collect detailed results for validation
    all_details = {}

    for i, (name, fn) in enumerate(tasks, 1):
        print(f"\n  Task {i}/5: {name}")
        print(f"  Processing {n_rows:,} rows...")
        print(f"  {'·' * 50}")

        t0 = time.perf_counter()
        result = fn(df, verbose=args.verbose)
        elapsed_ms = (time.perf_counter() - t0) * 1000

        total_time += elapsed_ms

        # ── Per-task detailed output ─────────────────────────────────────
        details = {"rows_processed": n_rows}

        if i == 1:
            # Total by cost centre
            totals = result
            summary = f"{len(totals)} groups"
            grand_total = sum(totals.values())
            largest_cc = max(totals, key=totals.get)
            smallest_cc = min(totals, key=totals.get)
            details["totals"] = {cc: round(v, 2) for cc, v in totals.items()}
            details["grand_total"] = round(grand_total, 2)

            print(f"  ✓ Completed in {elapsed_ms:,.1f} ms ({elapsed_ms / 1000:.1f}s)")
            print(f"    Groups:   {len(totals)}")
            print(f"    Largest:  {largest_cc} = ${totals[largest_cc]:>16,.2f}")
            print(f"    Smallest: {smallest_cc} = ${totals[smallest_cc]:>16,.2f}")
            print(f"    Grand total: ${grand_total:>16,.2f}")
            for cc in COST_CENTRES:
                print(f"      {cc:<18} ${totals.get(cc, 0):>16,.2f}")

        elif i == 2:
            # Top 10 suppliers
            top10 = result
            summary = f"top supplier: {top10[0][0]}" if top10 else "none"
            details["top_10"] = [{"supplier_id": int(sid), "total": round(amt, 2)} for sid, amt in top10]

            print(f"  ✓ Completed in {elapsed_ms:,.1f} ms ({elapsed_ms / 1000:.1f}s)")
            print(f"    Top 10 suppliers:")
            for rank, (sid, amt) in enumerate(top10, 1):
                print(f"      #{rank:<3} Supplier {sid}: ${amt:>16,.2f}")

        elif i == 3:
            # Z-score anomaly detection
            anomaly_count, baselines = result
            anomaly_rate = anomaly_count / n_rows * 100
            summary = f"{anomaly_count:,} anomalies"
            details["anomaly_count"] = anomaly_count
            details["anomaly_rate_pct"] = round(anomaly_rate, 4)
            details["z_threshold"] = Z_THRESHOLD
            details["baselines"] = {
                cc: {"mean": round(bl["mean"], 2), "std": round(bl["std"], 2)}
                for cc, bl in baselines.items()
            }

            print(f"  ✓ Completed in {elapsed_ms:,.1f} ms ({elapsed_ms / 1000:.1f}s)")
            print(f"    Z-threshold: {Z_THRESHOLD}")
            print(f"    Anomalies:   {anomaly_count:,} ({anomaly_rate:.4f}%)")
            print(f"    Baselines (mean / std):")
            for cc in COST_CENTRES:
                bl = baselines[cc]
                print(f"      {cc:<18} mean=${bl['mean']:>14,.2f}  std=${bl['std']:>12,.2f}")

        elif i == 4:
            # Plant × cost centre pivot
            pivot = result
            summary = f"{len(pivot)} cells"
            # Compute row/column totals
            plant_totals = {p: 0.0 for p in PLANT_CODES}
            cc_totals = {cc: 0.0 for cc in COST_CENTRES}
            for (plant, cc), val in pivot.items():
                plant_totals[plant] += val
                cc_totals[cc] += val
            details["cells"] = len(pivot)
            details["plant_totals"] = {p: round(v, 2) for p, v in plant_totals.items()}
            details["cc_totals"] = {cc: round(v, 2) for cc, v in cc_totals.items()}

            print(f"  ✓ Completed in {elapsed_ms:,.1f} ms ({elapsed_ms / 1000:.1f}s)")
            print(f"    Cells: {len(pivot)} ({len(PLANT_CODES)} plants × {len(COST_CENTRES)} centres)")
            print(f"    Plant totals:")
            for plant in PLANT_CODES:
                print(f"      {plant:<14} ${plant_totals[plant]:>16,.2f}")
            print(f"    Cost centre totals (top 5):")
            sorted_cc = sorted(cc_totals.items(), key=lambda x: x[1], reverse=True)[:5]
            for cc, val in sorted_cc:
                print(f"      {cc:<18} ${val:>16,.2f}")

        elif i == 5:
            # Running total
            running = result
            summary = f"${running:,.2f}"
            details["running_total"] = round(running, 2)

            print(f"  ✓ Completed in {elapsed_ms:,.1f} ms ({elapsed_ms / 1000:.1f}s)")
            print(f"    Final running total: ${running:>20,.2f}")

        all_details[name] = details

        task_results.append({
            "name": name,
            "time_ms": round(elapsed_ms, 1),
            "summary": summary,
            "rows_processed": n_rows,
            "details": details,
        })

    # ── Results Summary Table ────────────────────────────────────────────
    print(f"\n{'═' * 60}")
    print(f"  RESULTS SUMMARY")
    print(f"{'═' * 60}")
    print(f"  {'Task':<35} {'Time':>10}  {'% Total':>8}")
    print(f"  {'─' * 55}")
    for tr in task_results:
        pct = tr['time_ms'] / total_time * 100 if total_time > 0 else 0
        print(f"  {tr['name']:<35} {tr['time_ms']:>8,.1f} ms  {pct:>6.1f}%")
    print(f"  {'─' * 55}")
    print(f"  {'TOTAL':<35} {total_time:>8,.1f} ms")
    throughput = n_rows / (total_time / 1000) if total_time > 0 else 0
    minutes = total_time / 60000
    print(f"  Throughput: {throughput:,.0f} rec/s (across all tasks)")
    print(f"  Wall time:  {total_time:,.1f} ms ({minutes:.1f}m)")
    print(f"{'═' * 60}")

    # ── Validation Summary ───────────────────────────────────────────────
    anomaly_task = all_details.get("Z-score anomaly detection", {})
    top_supplier_task = all_details.get("Top 10 suppliers by spend", {})
    running_total_task = all_details.get("Running total", {})

    anomaly_count = anomaly_task.get("anomaly_count", 0)
    anomaly_rate_pct = anomaly_task.get("anomaly_rate_pct", 0)
    top_supplier = top_supplier_task.get("top_10", [{}])[0] if top_supplier_task.get("top_10") else {}
    running_total = running_total_task.get("running_total", 0)

    print(f"\n{'═' * 60}")
    print(f"  VALIDATION SUMMARY")
    print(f"{'─' * 60}")
    print(f"    Run timestamp:     {machine['timestamp']}")
    print(f"    Machine:           {machine['machine_name']}")
    print(f"    CPU:               {machine['cpu_model']}")
    print(f"    Python:            {machine['python_version']}")
    print(f"    Data source:       {data_source}")
    print(f"    Rows processed:    {n_rows:,} (per task)")
    print(f"    Seed:              {RANDOM_SEED}")
    print(f"    Z-threshold:       {Z_THRESHOLD}")
    print(f"    Anomalies found:   {anomaly_count:,} ({anomaly_rate_pct:.4f}%)")
    print(f"    Running total:     ${running_total:>20,.2f}")
    if top_supplier:
        print(f"    Top supplier:      {top_supplier.get('supplier_id', '?')} (${top_supplier.get('total', 0):,.2f})")
    print(f"    Peak memory:       {mem_mb:.1f} MB")
    print(f"    Total time:        {total_time:,.1f} ms ({minutes:.1f}m)")
    print(f"    Throughput:        {throughput:,.0f} rec/s")
    print(f"{'─' * 60}")

    # ── Save JSON ────────────────────────────────────────────────────────
    json_path = "benchmark_results_python.json"
    output = {
        "engine": "Python / Row-by-Row Loop (CPU)",
        "device": None,
        "total_time_ms": round(total_time, 1),
        "total_records": n_rows,
        "throughput_rps": round(throughput, 0),
        "tasks": task_results,
        "peak_memory_mb": round(mem_mb, 1),

        # Validation metadata
        "seed": RANDOM_SEED,
        "z_threshold": Z_THRESHOLD,
        "anomaly_rate_config": 0.002,
        "data_source": data_source,
        "data_load_time_ms": round(data_gen_time_ms, 1),
        "json_generated_at": datetime.datetime.now().isoformat(),

        # Machine metadata
        **machine,
    }

    with open(json_path, "w") as f:
        json.dump(output, f, indent=2)

    json_size_kb = os.path.getsize(json_path) / 1024

    print(f"\n    JSON saved:        {json_path} ({json_size_kb:.1f} KB)")
    print(f"    JSON generated:    {output['json_generated_at']}")
    print(f"{'═' * 60}")
    print(f"\n  Done.")

if __name__ == "__main__":
    main()
