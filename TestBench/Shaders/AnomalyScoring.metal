// AnomalyScoring.metal
// Kiraa AI — Simple Z-Score Anomaly Detection (GPU)
//
// Each GPU thread scores one transaction independently:
//   z = (amount - cost_centre_mean) / cost_centre_std
//   is_anomaly = |z| > threshold (3.5)
//
// Buffer bindings (must match MetalEngine.swift setBuffer indices):
//   buffer(0): Transaction*  — input transactions (batch)
//   buffer(1): Baseline*     — per-cost-centre mean/std (12 entries)
//   buffer(2): ScoredResult* — output z-scores and anomaly flags
//   buffer(3): float&        — z-score threshold constant (3.5)
//
// Struct layouts must exactly match the Swift-side Transaction, Baseline,
// and ScoredResult structs (24, 8, and 8 bytes respectively).

#include <metal_stdlib>
using namespace metal;

struct Transaction {
    float  amount;
    uint   cost_centre_id;
    uint   txn_type_id;
    uint   supplier_id;
    uint   plant_code_id;
    float  _pad;
};

struct Baseline {
    float mean;
    float std_dev;
};

struct ScoredResult {
    float z_score;
    uint  is_anomaly;
};

kernel void scoreTransactions(
    device const Transaction*  transactions [[ buffer(0) ]],
    device const Baseline*     baselines    [[ buffer(1) ]],
    device       ScoredResult* results      [[ buffer(2) ]],
    constant     float&        z_threshold  [[ buffer(3) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    Transaction txn      = transactions[gid];
    Baseline    baseline = baselines[txn.cost_centre_id];

    float z = (baseline.std_dev > 0.0)
        ? (txn.amount - baseline.mean) / baseline.std_dev
        : 0.0;

    results[gid].z_score    = z;
    results[gid].is_anomaly = (fabs(z) > z_threshold) ? 1u : 0u;
}
