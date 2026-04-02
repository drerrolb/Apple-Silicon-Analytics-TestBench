// AnomalyScoring.metal
// Kiraa AI — Financial Anomaly Detection
//
// Runs entirely on Apple Silicon GPU cores via Metal compute.
// Each thread scores one transaction against its cost-centre baseline.
// Unified memory means the CPU-populated buffers are visible to the GPU
// with zero copy — no PCIe transfer, no latency cliff.

#include <metal_stdlib>
using namespace metal;

// ── Structs (must mirror Swift-side layout exactly) ───────────────────────────

struct Transaction {
    float  amount;
    uint   cost_centre_id;   // 0-11 mapped from string
    uint   txn_type_id;
    uint   supplier_id;
    uint   plant_code_id;
    float  _pad;             // align to 24 bytes
};

struct Baseline {
    float mean;
    float std_dev;
};

struct ScoredResult {
    float z_score;
    uint  is_anomaly;        // 1 = anomaly, 0 = normal
};

// ── Kernel ────────────────────────────────────────────────────────────────────

kernel void scoreTransactions(
    device const Transaction*  transactions [[ buffer(0) ]],
    device const Baseline*     baselines    [[ buffer(1) ]],
    device       ScoredResult* results      [[ buffer(2) ]],
    constant     float&        z_threshold  [[ buffer(3) ]],
    uint gid [[ thread_position_in_grid ]]
) {
    Transaction txn      = transactions[gid];
    Baseline    baseline = baselines[txn.cost_centre_id];

    float z = (txn.amount - baseline.mean) / baseline.std_dev;

    results[gid].z_score    = z;
    results[gid].is_anomaly = (fabs(z) > z_threshold) ? 1u : 0u;
}
