#!/usr/bin/env python3
"""
Generate Benchmark Data CSV
Kiraa AI — Shared dataset for Python vs Swift+Metal comparison
======================================================================

Generates the 10M row benchmark_data.csv deterministically (seed=42).
Both Python and Swift read this file for fair scoring comparison.

Usage:
    python3 generate_data.py                  # Default: 10M rows
    python3 generate_data.py --rows 1000000   # Custom row count
    python3 generate_data.py --output data.csv # Custom output path
"""

import argparse
import os
import time

import numpy as np
import pandas as pd

# ── Config (must match benchmark_python.py and Swift Config exactly) ─────────

RANDOM_SEED = 42
ANOMALY_RATE = 0.002
DEFAULT_ROWS = 10_000_000

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


def generate(n_rows: int, output_path: str):
    print(f"Generating {n_rows:,} rows (seed={RANDOM_SEED})...")
    t0 = time.perf_counter()

    rng = np.random.default_rng(RANDOM_SEED)

    # Assign categories
    cost_centre = rng.choice(COST_CENTRES, size=n_rows)
    txn_type = rng.choice(TRANSACTION_TYPES, size=n_rows)
    plant_code = rng.choice(PLANT_CODES, size=n_rows)
    supplier_id = rng.integers(1000, 9999, size=n_rows)

    # Generate amounts (normal distribution per cost centre)
    base_amounts = {cc: rng.uniform(5_000, 500_000) for cc in COST_CENTRES}
    amounts = np.array([
        rng.normal(loc=base_amounts[cc], scale=base_amounts[cc] * 0.15)
        for cc in cost_centre
    ])

    # Inject anomalies (0.2%)
    n_anomalies = int(n_rows * ANOMALY_RATE)
    anomaly_idx = rng.choice(n_rows, size=n_anomalies, replace=False)
    amounts[anomaly_idx] *= rng.choice([8.0, 12.0, -5.0, 15.0], size=n_anomalies)

    gen_time = time.perf_counter() - t0
    print(f"  Generated in {gen_time:.1f}s")

    # Map strings to integer IDs (matches Swift enum ordering)
    cc_to_id = {cc: i for i, cc in enumerate(COST_CENTRES)}
    txn_to_id = {t: i for i, t in enumerate(TRANSACTION_TYPES)}
    plant_to_id = {p: i for i, p in enumerate(PLANT_CODES)}

    print(f"Writing CSV to {output_path}...")
    t0 = time.perf_counter()

    df = pd.DataFrame({
        "amount": amounts,
        "cost_centre_id": [cc_to_id[cc] for cc in cost_centre],
        "txn_type_id": [txn_to_id[t] for t in txn_type],
        "supplier_id": supplier_id,
        "plant_code_id": [plant_to_id[p] for p in plant_code],
    })
    df.to_csv(output_path, index=False)

    write_time = time.perf_counter() - t0
    file_mb = os.path.getsize(output_path) / 1_048_576

    print(f"  Written in {write_time:.1f}s")
    print(f"  File size: {file_mb:.0f} MB")
    print(f"  Rows: {n_rows:,}")
    print(f"  Columns: amount, cost_centre_id, txn_type_id, supplier_id, plant_code_id")
    print(f"\nDone. Use with:")
    print(f"  python3 benchmark_python.py --from-csv {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate benchmark_data.csv for Python vs Swift+Metal comparison")
    parser.add_argument("--rows", type=int, default=DEFAULT_ROWS,
                        help=f"Number of rows (default: {DEFAULT_ROWS:,})")
    parser.add_argument("--output", "-o", type=str, default="benchmark_data.csv",
                        help="Output file path (default: benchmark_data.csv)")
    args = parser.parse_args()

    generate(args.rows, args.output)


if __name__ == "__main__":
    main()
