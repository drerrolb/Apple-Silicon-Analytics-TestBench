import Metal
import Foundation

// MARK: - Metal engine for Task 3 (z-score anomaly detection on GPU)

/// GPU compute pipeline for z-score anomaly detection using Metal.
///
/// Allocates shared-mode buffers (zero-copy on Apple Silicon — CPU and GPU
/// access the same physical memory) sized for one batch of transactions.
/// Baselines and the z-score threshold are uploaded once at init and reused
/// across all subsequent `scoreBatch(_:)` calls.
///
/// Marked `@unchecked Sendable` because all mutable state is written once
/// during `init`; the Metal command queue itself is thread-safe.
final class MetalEngine: @unchecked Sendable {

    private let device:        MTLDevice
    private let commandQueue:  MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let batchSize:     Int

    private let transactionBuffer: MTLBuffer
    private let baselineBuffer:    MTLBuffer
    private let resultBuffer:      MTLBuffer
    private let thresholdBuffer:   MTLBuffer

    /// Create a Metal scoring engine.
    ///
    /// - Parameters:
    ///   - batchSize: Maximum number of transactions per GPU dispatch.
    ///   - baselines: Per-cost-centre mean/stdDev pairs (uploaded to GPU once).
    /// - Throws: `MetalEngineError` if the device, command queue, shader kernel,
    ///   or any buffer allocation fails.
    nonisolated init(batchSize: Int, baselines: [Baseline]) throws {
        self.batchSize = batchSize

        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw MetalEngineError.noDevice
        }
        self.device = dev

        guard let queue = dev.makeCommandQueue() else {
            throw MetalEngineError.noCommandQueue
        }
        self.commandQueue = queue

        // Load the default Metal library (compiled from .metal files in the target)
        // and look up the "scoreTransactions" kernel function.
        guard let library = dev.makeDefaultLibrary(),
              let fn = library.makeFunction(name: "scoreTransactions") else {
            throw MetalEngineError.kernelNotFound
        }
        self.pipelineState = try dev.makeComputePipelineState(function: fn)

        let txnSize    = batchSize * MemoryLayout<Transaction>.stride
        let baseSize   = baselines.count * MemoryLayout<Baseline>.stride
        let resultSize = batchSize * MemoryLayout<ScoredResult>.stride

        // .storageModeShared → zero-copy on Apple Silicon (CPU & GPU share memory).
        guard
            let txnBuf = dev.makeBuffer(length: txnSize, options: .storageModeShared),
            let baseBuf = dev.makeBuffer(bytes: baselines, length: baseSize, options: .storageModeShared),
            let resBuf = dev.makeBuffer(length: resultSize, options: .storageModeShared),
            let thrBuf = dev.makeBuffer(length: MemoryLayout<Float>.stride, options: .storageModeShared)
        else { throw MetalEngineError.bufferAllocation }

        self.transactionBuffer = txnBuf
        self.baselineBuffer    = baseBuf
        self.resultBuffer      = resBuf
        self.thresholdBuffer   = thrBuf

        // Write the z-score threshold into a constant buffer (read by every GPU thread).
        var threshold = Config.zThreshold
        memcpy(thrBuf.contents(), &threshold, MemoryLayout<Float>.stride)
    }

    /// Score a batch of transactions on the GPU.
    ///
    /// Copies `batch` into the transaction buffer, dispatches the Metal compute
    /// kernel, blocks until completion, then reads back anomaly flags.
    ///
    /// - Parameter batch: A slice of transactions (must be ≤ `batchSize`).
    /// - Returns: `(anomalyCount, elapsedSeconds)` where elapsed covers only
    ///   the GPU commit-to-complete window (excludes CPU-side memcpy).
    nonisolated func scoreBatch(_ batch: ArraySlice<Transaction>) -> (Int, Double) {
        let count = batch.count
        batch.withUnsafeBytes { ptr in
            memcpy(transactionBuffer.contents(), ptr.baseAddress!, count * MemoryLayout<Transaction>.stride)
        }

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let enc = cmdBuf.makeComputeCommandEncoder() else { return (0, 0) }

        enc.setComputePipelineState(pipelineState)
        enc.setBuffer(transactionBuffer, offset: 0, index: 0)  // buffer(0): transactions
        enc.setBuffer(baselineBuffer,    offset: 0, index: 1)  // buffer(1): baselines
        enc.setBuffer(resultBuffer,      offset: 0, index: 2)  // buffer(2): scored results
        enc.setBuffer(thresholdBuffer,   offset: 0, index: 3)  // buffer(3): z-threshold

        // Ceiling division: ensures every transaction gets a thread even if count
        // isn't a multiple of the threadgroup width.
        let tgSize = MTLSize(width: min(pipelineState.maxTotalThreadsPerThreadgroup, count), height: 1, depth: 1)
        let tgCount = MTLSize(width: (count + tgSize.width - 1) / tgSize.width, height: 1, depth: 1)
        enc.dispatchThreadgroups(tgCount, threadsPerThreadgroup: tgSize)
        enc.endEncoding()

        // Time only the GPU execution (commit → waitUntilCompleted).
        let t0 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()
        let t1 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)

        // Cast the raw GPU result buffer back to typed ScoredResult pointers
        // so we can read anomaly flags on the CPU side.
        let ptr = resultBuffer.contents().bindMemory(to: ScoredResult.self, capacity: count)
        var anomalies = 0
        for i in 0 ..< count { if ptr[i].isAnomaly == 1 { anomalies += 1 } }

        return (anomalies, Double(t1 - t0) / 1_000_000_000.0)
    }

    /// The human-readable name of the Metal GPU device (e.g. "Apple M4 Max").
    var deviceName: String { device.name }
}

// MARK: - Full 5-task benchmark runner (Swift CPU + Metal GPU)

/// Runs the complete 5-task ERP aggregation benchmark.
///
/// Uses a caseless enum as a namespace (no instances). All five tasks iterate
/// the same `[Transaction]` array; Task 3 uses the Metal GPU when available,
/// falling back to a single-threaded CPU loop otherwise.
///
/// **Tasks:**
/// 1. Total spend by cost centre (group-by → sum into fixed-size array)
/// 2. Top 10 suppliers by spend (hash map accumulation → partial sort)
/// 3. Z-score anomaly detection (GPU batch scoring or CPU fallback)
/// 4. Plant × cost centre pivot (4×12 = 48-cell flat 2D array)
/// 5. Running total (single-pass cumulative sum)
enum SwiftBenchmarkRunner {

    /// Execute all five benchmark tasks and return a combined result.
    ///
    /// - Parameters:
    ///   - transactions: The full dataset to process (typically 10M rows).
    ///   - baselines: Per-cost-centre mean/stdDev pairs for z-score computation.
    ///   - metalEngine: Optional GPU engine. Pass `nil` to force CPU-only scoring.
    ///   - onProgress: Called once before each task starts (tasks 1–5).
    /// - Returns: A `BenchmarkResult` with per-task timings, total throughput,
    ///   and estimated peak memory usage.
    nonisolated static func run(
        transactions: [Transaction],
        baselines: [Baseline],
        metalEngine: MetalEngine?,
        onProgress: @Sendable (BenchmarkProgress) -> Void
    ) -> BenchmarkResult {
        let n = transactions.count
        var tasks = [TaskResult]()
        let nCentres = Config.costCentres.count
        let nPlants  = Config.plantCodes.count

        // ── Task 1: Total by cost centre ────────────────────────────────
        // Accumulates spend into a fixed-size array indexed by costCentreId.
        // O(n) with no hashing overhead since IDs are contiguous 0..<12.
        onProgress(BenchmarkProgress(currentTask: 1, totalTasks: 5, taskName: "Total by cost centre"))
        var ccTotals = [Double](repeating: 0, count: nCentres)
        let t1start = highResolutionTime()
        for txn in transactions {
            ccTotals[Int(txn.costCentreId)] += Double(txn.amount)
        }
        let t1ms = (highResolutionTime() - t1start) * 1000
        tasks.append(TaskResult(name: "Total by cost centre", timeMs: t1ms,
                                summary: "\(nCentres) groups"))

        // ── Task 2: Top 10 suppliers ────────────────────────────────────
        // Uses a hash map because supplier IDs are sparse (1000–9999).
        // Sorts the full map then takes prefix(10) — acceptable for ~9K entries.
        onProgress(BenchmarkProgress(currentTask: 2, totalTasks: 5, taskName: "Top 10 suppliers"))
        var supplierTotals = [UInt32: Double]()
        let t2start = highResolutionTime()
        for txn in transactions {
            supplierTotals[txn.supplierId, default: 0] += Double(txn.amount)
        }
        let top10 = supplierTotals.sorted { $0.value > $1.value }.prefix(10)
        let t2ms = (highResolutionTime() - t2start) * 1000
        let topSid = top10.first.map { "\($0.key)" } ?? "none"
        tasks.append(TaskResult(name: "Top 10 suppliers", timeMs: t2ms,
                                summary: "top: \(topSid)"))

        // ── Task 3: Z-score anomaly detection ───────────────────────────
        // GPU path: dispatches transactions in batches of Config.streamingBatch
        // to the Metal kernel. CPU fallback: single-threaded loop computing
        // z = (amount - mean) / stdDev per transaction.
        onProgress(BenchmarkProgress(currentTask: 3, totalTasks: 5, taskName: "Z-score anomaly detection"))
        let t3start = highResolutionTime()
        var totalAnomalies = 0

        if let engine = metalEngine {
            let batchSize = Config.streamingBatch
            let nBatches = n / batchSize
            // Warm-up: first dispatch compiles the pipeline and primes caches.
            _ = engine.scoreBatch(transactions[0 ..< batchSize])
            for i in 0 ..< nBatches {
                let (anom, _) = engine.scoreBatch(transactions[i * batchSize ..< (i + 1) * batchSize])
                totalAnomalies += anom
            }
        } else {
            // CPU fallback: z = (amount - mean) / stdDev, flag if |z| > threshold.
            // Returns z = 0 when stdDev is 0 (all amounts identical for that cost centre).
            let threshold = Config.zThreshold
            for txn in transactions {
                let bl = baselines[Int(txn.costCentreId)]
                let z = bl.stdDev > 0 ? (txn.amount - bl.mean) / bl.stdDev : 0
                if abs(z) > threshold { totalAnomalies += 1 }
            }
        }
        let t3ms = (highResolutionTime() - t3start) * 1000
        tasks.append(TaskResult(name: "Z-score anomaly detection", timeMs: t3ms,
                                summary: "\(totalAnomalies) anomalies"))

        // ── Task 4: Plant × cost centre pivot ───────────────────────────
        // Flat 2D array [plantId * nCentres + centreId] avoids hash overhead.
        // Produces a 4×12 = 48-cell cross-tab of total spend.
        onProgress(BenchmarkProgress(currentTask: 4, totalTasks: 5, taskName: "Plant × cost centre pivot"))
        var pivot = [Double](repeating: 0, count: nPlants * nCentres)
        let t4start = highResolutionTime()
        for txn in transactions {
            let idx = Int(txn.plantCodeId) * nCentres + Int(txn.costCentreId)
            pivot[idx] += Double(txn.amount)
        }
        let t4ms = (highResolutionTime() - t4start) * 1000
        tasks.append(TaskResult(name: "Plant × cost centre pivot", timeMs: t4ms,
                                summary: "\(nPlants * nCentres) cells"))

        // ── Task 5: Running total ───────────────────────────────────────
        // Single-pass cumulative sum. Uses Double accumulator for precision
        // over 10M Float addends.
        onProgress(BenchmarkProgress(currentTask: 5, totalTasks: 5, taskName: "Running total"))
        var runningTotal = 0.0
        let t5start = highResolutionTime()
        for txn in transactions {
            runningTotal += Double(txn.amount)
        }
        let t5ms = (highResolutionTime() - t5start) * 1000
        tasks.append(TaskResult(name: "Running total", timeMs: t5ms,
                                summary: String(format: "$%.2f", runningTotal)))

        let totalMs = tasks.reduce(0) { $0 + $1.timeMs }
        let txnMB = Double(n * MemoryLayout<Transaction>.stride) / 1_048_576

        return BenchmarkResult(
            engine:        "Swift + Metal (Apple Silicon)",
            device:        metalEngine?.deviceName,
            totalTimeMs:   totalMs,
            totalRecords:  n,
            throughputRps: Double(n) / (totalMs / 1000),
            peakMemoryMB:  txnMB,
            tasks:         tasks
        )
    }
}

// MARK: - Errors

/// Errors that can occur during Metal engine initialization.
enum MetalEngineError: Error, LocalizedError {
    /// No Metal-capable GPU device found on this hardware.
    case noDevice
    /// The Metal device failed to create a command queue.
    case noCommandQueue
    /// The "scoreTransactions" kernel was not found in the default Metal library.
    case kernelNotFound
    /// One or more GPU buffers could not be allocated (likely out of memory).
    case bufferAllocation

    var errorDescription: String? {
        switch self {
        case .noDevice:         "No Metal device found."
        case .noCommandQueue:   "Failed to create command queue."
        case .kernelNotFound:   "Metal kernel not found."
        case .bufferAllocation: "Failed to allocate buffers."
        }
    }
}
