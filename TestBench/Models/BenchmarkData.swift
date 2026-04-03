import Foundation

/// Detailed intermediate results from a benchmark run, used for charting.
///
/// Captures the actual computed values from each of the 5 benchmark tasks
/// (cost centre totals, supplier rankings, anomaly stats, pivot values,
/// running total) that `SwiftBenchmarkRunner` computes but `BenchmarkResult`
/// only stores as summary strings.
struct BenchmarkData: Sendable {

    /// Total spend per cost centre (12 entries).
    var costCentreTotals: [CostCentreTotal]

    /// Top 10 suppliers ranked by total spend.
    var topSuppliers: [SupplierTotal]

    /// Z-score anomaly detection results.
    var anomalyCount: Int
    var baselines: [BaselineStat]

    /// Plant x cost centre pivot values (48 entries).
    var pivotValues: [PivotCell]

    /// Plant-level totals (4 entries).
    var plantTotals: [PlantTotal]

    /// Final cumulative sum over all transactions.
    var runningTotal: Double

    // MARK: - Sub-types for chart data

    struct CostCentreTotal: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let total: Double
    }

    struct SupplierTotal: Identifiable, Sendable {
        var id: UInt32 { supplierId }
        let supplierId: UInt32
        let total: Double
        let rank: Int
    }

    struct BaselineStat: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let mean: Float
        let stdDev: Float
    }

    struct PivotCell: Identifiable, Sendable {
        var id: String { "\(plant)-\(centre)" }
        let plant: String
        let centre: String
        let total: Double
    }

    struct PlantTotal: Identifiable, Sendable {
        var id: String { name }
        let name: String
        let total: Double
    }
}

/// A single data point for comparing task timings between engines.
struct TaskComparison: Identifiable {
    var id: String { "\(task)-\(engine)" }
    let task: String
    let engine: String
    let timeMs: Double
}
