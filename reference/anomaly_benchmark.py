"""
Financial Anomaly Detection Benchmark
Kiraa AI — Python Baseline (CPU)
------------------------------------------------------
Simulates 10M rows of ERP transactional data across
cost centres and runs z-score anomaly detection with
real-time streaming simulation.

Usage:
    pip install pandas numpy tqdm
    python anomaly_benchmark.py
"""

import time
import json
import warnings
import numpy as np
import pandas as pd
from tqdm import tqdm

warnings.filterwarnings("ignore")

# ── Config ────────────────────────────────────────────────────────────────────

NUM_ROWS          = 10_000_000   # 5 years of ERP transactions
STREAMING_BATCH   = 1_000        # records per real-time batch
ANOMALY_RATE      = 0.002        # 0.2% anomaly injection rate
RANDOM_SEED       = 42
Z_THRESHOLD       = 3.5          # standard deviations for anomaly flag

COST_CENTRES = [
    "RAW_MATERIALS", "PACKAGING", "LOGISTICS", "LABOUR",
    "OVERHEADS", "CAPEX", "MAINTENANCE", "UTILITIES",
    "PROCUREMENT", "SALES", "MARKETING", "ADMIN"
]

TRANSACTION_TYPES = [
    "PURCHASE_ORDER", "INVOICE_MATCH", "VARIANCE_FLAG",
    "ACCRUAL", "PAYMENT_RUN", "INTERCOMPANY", "CREDIT_NOTE"
]

# ── Data Generation ───────────────────────────────────────────────────────────

def generate_erp_data(n_rows: int, seed: int = RANDOM_SEED) -> pd.DataFrame:
    """Generate synthetic ERP transaction data mimicking a mid-market manufacturer."""
    rng = np.random.default_rng(seed)

    cost_centre = rng.choice(COST_CENTRES, size=n_rows)
    txn_type    = rng.choice(TRANSACTION_TYPES, size=n_rows)

    # Base amounts per cost centre (different scales, as in real ERPs)
    base_amounts = {cc: rng.uniform(5_000, 500_000) for cc in COST_CENTRES}
    amounts = np.array([
        rng.normal(loc=base_amounts[cc], scale=base_amounts[cc] * 0.15)
        for cc in cost_centre
    ])

    # Inject anomalies
    n_anomalies = int(n_rows * ANOMALY_RATE)
    anomaly_idx = rng.choice(n_rows, size=n_anomalies, replace=False)
    amounts[anomaly_idx] *= rng.choice([8.0, 12.0, -5.0, 15.0], size=n_anomalies)

    timestamps = pd.date_range(
        start="2019-01-01", periods=n_rows, freq="26s"   # ~10M txns over 5yrs
    )

    return pd.DataFrame({
        "timestamp":    timestamps,
        "cost_centre":  cost_centre,
        "txn_type":     txn_type,
        "amount":       amounts,
        "supplier_id":  rng.integers(1000, 9999, size=n_rows),
        "plant_code":   rng.choice(["GOLD_COAST", "SYDNEY", "MELBOURNE", "BRISBANE"], size=n_rows),
    })

# ── Anomaly Detection ─────────────────────────────────────────────────────────

def compute_baselines(df: pd.DataFrame) -> pd.DataFrame:
    """Compute per-cost-centre mean and std for z-score calculation."""
    return (
        df.groupby("cost_centre")["amount"]
        .agg(["mean", "std"])
        .rename(columns={"mean": "baseline_mean", "std": "baseline_std"})
        .reset_index()
    )

def score_batch(batch: pd.DataFrame, baselines: pd.DataFrame) -> pd.DataFrame:
    """Apply z-score anomaly scoring to a batch of transactions."""
    merged = batch.merge(baselines, on="cost_centre", how="left")
    merged["z_score"] = (merged["amount"] - merged["baseline_mean"]) / merged["baseline_std"]
    merged["is_anomaly"] = merged["z_score"].abs() > Z_THRESHOLD
    return merged

def run_streaming_simulation(df: pd.DataFrame, baselines: pd.DataFrame,
                              batch_size: int = STREAMING_BATCH) -> dict:
    """Simulate real-time transaction stream, scoring each batch."""
    n_batches      = len(df) // batch_size
    total_anomalies = 0
    latencies      = []

    for i in tqdm(range(n_batches), desc="  Streaming batches", unit="batch",
                  ncols=80, colour="cyan"):
        batch = df.iloc[i * batch_size : (i + 1) * batch_size].copy()

        t0     = time.perf_counter()
        scored = score_batch(batch, baselines)
        t1     = time.perf_counter()

        latencies.append((t1 - t0) * 1000)   # ms
        total_anomalies += scored["is_anomaly"].sum()

    return {
        "total_batches":    n_batches,
        "total_records":    n_batches * batch_size,
        "total_anomalies":  int(total_anomalies),
        "throughput_rps":   round((n_batches * batch_size) / (sum(latencies) / 1000), 0),
        "avg_latency_ms":   round(float(np.mean(latencies)), 3),
        "p99_latency_ms":   round(float(np.percentile(latencies, 99)), 3),
        "min_latency_ms":   round(float(np.min(latencies)), 3),
    }

# ── Benchmark ─────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Kiraa AI — Financial Anomaly Detection Benchmark")
    print("  Python Baseline (CPU)")
    print("=" * 60)

    print(f"\nGenerating {NUM_ROWS:,} synthetic ERP transactions...")
    t0       = time.perf_counter()
    df       = generate_erp_data(NUM_ROWS)
    gen_time = time.perf_counter() - t0
    print(f"Data generation: {gen_time:.2f}s  |  "
          f"Memory: {df.memory_usage(deep=True).sum() / 1_048_576:.0f} MB")

    print("\nComputing baselines...")
    t0            = time.perf_counter()
    baselines     = compute_baselines(df)
    baseline_time = time.perf_counter() - t0
    print(f"Baseline computed in {baseline_time:.2f}s")

    print("\nRunning streaming simulation...")
    results     = run_streaming_simulation(df, baselines)
    stream_time = sum([]) or results["avg_latency_ms"] * results["total_batches"] / 1000

    peak_mb = df.memory_usage(deep=True).sum() / 1_048_576

    output = {
        "engine":          "Python / pandas (CPU)",
        "baseline_time_s": round(baseline_time, 3),
        "stream_time_s":   round(results["total_batches"] * results["avg_latency_ms"] / 1000, 1),
        "peak_memory_mb":  round(peak_mb, 1),
        **results
    }

    print("\nResults:")
    for k, v in output.items():
        print(f"  {k:<22} {v}")

    with open("benchmark_results_python.json", "w") as f:
        json.dump(output, f, indent=2)

    print("\nResults saved → benchmark_results_python.json")
    print("Next: run the Swift / Metal benchmark.")

if __name__ == "__main__":
    main()
