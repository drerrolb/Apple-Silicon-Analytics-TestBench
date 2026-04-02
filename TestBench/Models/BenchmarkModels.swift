import Foundation

// MARK: - Config

/// Application-wide constants for the benchmark.
///
/// Uses a caseless enum (no instances) as a namespace — the standard Swift
/// pattern for grouping related constants.
enum Config {
    /// Total number of transactions to generate (default dataset size).
    static let numRows        = 10_000_000
    /// Number of transactions per Metal GPU dispatch.
    static let streamingBatch = 1_000
    /// Fraction of rows injected as anomalies during data generation (0.2%).
    static let anomalyRate    = 0.002
    /// Z-score threshold for anomaly flagging. Transactions with |z| > 3.5 are anomalies.
    static let zThreshold: Float = 3.5

    /// The 12 ERP cost centre categories. Array index = `costCentreId`.
    static let costCentres = [
        "RAW_MATERIALS", "PACKAGING",    "LOGISTICS",   "LABOUR",
        "OVERHEADS",     "CAPEX",        "MAINTENANCE", "UTILITIES",
        "PROCUREMENT",   "SALES",        "MARKETING",   "ADMIN"
    ]

    /// The 7 transaction types. Array index = `txnTypeId`.
    static let transactionTypes = [
        "PURCHASE_ORDER", "INVOICE_MATCH", "VARIANCE_FLAG",
        "ACCRUAL",        "PAYMENT_RUN",   "INTERCOMPANY",  "CREDIT_NOTE"
    ]

    /// The 4 plant locations (Australian cities). Array index = `plantCodeId`.
    static let plantCodes = [
        "GOLD_COAST", "SYDNEY", "MELBOURNE", "BRISBANE"
    ]
}

// MARK: - GPU-layout structs (must match Metal shader exactly)

/// A single ERP transaction record, laid out for GPU consumption.
///
/// **Struct alignment:** 24 bytes total. The `_pad` field ensures the stride
/// matches the Metal shader's `Transaction` struct exactly. Changing field
/// order or removing `_pad` will break GPU scoring.
///
/// Marked `@unchecked Sendable` because it's a plain value type with no
/// reference semantics — safe to share across threads.
struct Transaction: @unchecked Sendable {
    var amount:       Float    // offset 0,  4 bytes
    var costCentreId: UInt32   // offset 4,  4 bytes
    var txnTypeId:    UInt32   // offset 8,  4 bytes
    var supplierId:   UInt32   // offset 12, 4 bytes
    var plantCodeId:  UInt32   // offset 16, 4 bytes
    var _pad:         Float = 0 // offset 20, 4 bytes → total 24 bytes
}

/// Per-group statistical baseline (mean and standard deviation).
///
/// One `Baseline` per cost centre (12 total) and per plant (4 total).
/// Stored as Float for direct use in Metal buffers.
struct Baseline: @unchecked Sendable {
    var mean:   Float
    var stdDev: Float
}

/// GPU output for one scored transaction.
///
/// `isAnomaly` is stored as `UInt32` (0 or 1) rather than `Bool` because
/// Metal shaders use `uint` — there is no native boolean type in MSL.
struct ScoredResult {
    var zScore:    Float
    var isAnomaly: UInt32
}

// MARK: - Task Result (per-task timing)

/// Timing and summary for a single benchmark task.
///
/// Uses snake_case `CodingKeys` to match the JSON format produced by
/// `benchmark_python.py`, enabling direct comparison in the dashboard.
struct TaskResult: Codable, Sendable, Identifiable {
    var id: String { name }
    var name:    String
    var timeMs:  Double
    var summary: String

    enum CodingKeys: String, CodingKey {
        case name
        case timeMs  = "time_ms"
        case summary
    }
}

// MARK: - Benchmark Result

/// Complete output from a single benchmark run (either Python or Swift+Metal).
///
/// Includes per-task timings, aggregate throughput, and optional machine metadata.
/// The metadata fields (`timestamp`, `machineName`, `cpuModel`, `pythonVersion`,
/// `osVersion`) are populated by the Python benchmark script and are nil for
/// Swift-generated results.
struct BenchmarkResult: Codable, Sendable {
    var engine:        String
    var device:        String?
    var totalTimeMs:   Double
    var totalRecords:  Int
    var throughputRps: Double
    var peakMemoryMB:  Double?
    var tasks:         [TaskResult]

    // Machine metadata (populated by Python benchmark script)
    var timestamp:     String?
    var machineName:   String?
    var cpuModel:      String?
    var pythonVersion: String?
    var osVersion:     String?

    enum CodingKeys: String, CodingKey {
        case engine, device, tasks, timestamp
        case totalTimeMs   = "total_time_ms"
        case totalRecords  = "total_records"
        case throughputRps = "throughput_rps"
        case peakMemoryMB  = "peak_memory_mb"
        case machineName   = "machine_name"
        case cpuModel      = "cpu_model"
        case pythonVersion = "python_version"
        case osVersion     = "os_version"
    }
}

// MARK: - Progress

/// Reports benchmark progress to the UI layer during a run.
struct BenchmarkProgress: Sendable {
    /// Current task number (1-based, e.g. 1 through 5).
    var currentTask: Int
    /// Total number of tasks in the benchmark (always 5).
    var totalTasks: Int
    /// Human-readable name of the current task.
    var taskName: String
}
