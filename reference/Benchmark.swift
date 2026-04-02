// Benchmark.swift
// Kiraa AI — Streaming Benchmark Harness
//
// Simulates real-time ERP transaction scoring:
//   - 10M transactions pre-generated
//   - 1,000-record batches scored sequentially (mimicking live stream arrival)
//   - Per-batch wall-clock latency recorded
//   - Outputs benchmark_results_swift.json for visualiser comparison

import Foundation

struct BenchmarkResult: Codable {
    var engine:          String
    var device:          String
    var baselineTimeS:   Double
    var streamTimeS:     Double
    var peakMemoryMB:    Double
    var totalBatches:    Int
    var totalRecords:    Int
    var totalAnomalies:  Int
    var throughputRps:   Double
    var avgLatencyMs:    Double
    var p99LatencyMs:    Double
    var minLatencyMs:    Double

    enum CodingKeys: String, CodingKey {
        case engine, device
        case baselineTimeS   = "baseline_time_s"
        case streamTimeS     = "stream_time_s"
        case peakMemoryMB    = "peak_memory_mb"
        case totalBatches    = "total_batches"
        case totalRecords    = "total_records"
        case totalAnomalies  = "total_anomalies"
        case throughputRps   = "throughput_rps"
        case avgLatencyMs    = "avg_latency_ms"
        case p99LatencyMs    = "p99_latency_ms"
        case minLatencyMs    = "min_latency_ms"
    }
}

@main
struct AnomalyBenchmark {

    static func main() async {
        printHeader()

        // ── 1. Generate data ──────────────────────────────────────────────────

        print("Generating \(Config.numRows.formatted()) synthetic ERP transactions...")
        let genStart = now()
        let (transactions, baselines) = DataGenerator.generate()
        let genTime = now() - genStart
        print(String(format: "Data generation: %.2fs  |  Memory: %.0f MB",
                     genTime,
                     Double(transactions.count * MemoryLayout<Transaction>.stride) / 1_048_576))

        // ── 2. Set up Metal engine ────────────────────────────────────────────

        print("\nInitialising Metal compute pipeline...")
        let engine: MetalEngine
        do {
            engine = try MetalEngine(batchSize: Config.streamingBatch, baselines: baselines)
        } catch {
            print("ERROR: \(error.localizedDescription)")
            print("This benchmark requires Apple Silicon (M1 or later).")
            exit(1)
        }
        print("GPU: \(engine.deviceName)")
        print("Max threads/group: \(engine.maxThreadsPerGroup)")

        // ── 3. Warm-up pass (1 batch, not measured) ───────────────────────────

        print("\nWarming up GPU pipeline...")
        let warmupSlice = transactions[0 ..< Config.streamingBatch]
        _ = engine.scoreBatch(warmupSlice)
        print("Warm-up complete.")

        // ── 4. Streaming simulation ───────────────────────────────────────────

        let nBatches = Config.numRows / Config.streamingBatch
        var latencies       = [Double]()
        var totalAnomalies  = 0
        latencies.reserveCapacity(nBatches)

        print("\nStreaming \(nBatches.formatted()) batches × \(Config.streamingBatch) records...")
        let streamStart = now()

        let progressInterval = nBatches / 20   // print every 5%
        for i in 0 ..< nBatches {
            let lo = i * Config.streamingBatch
            let hi = lo + Config.streamingBatch
            let batch = transactions[lo ..< hi]

            let (anomalies, elapsed) = engine.scoreBatch(batch)
            latencies.append(elapsed * 1000)    // store as ms
            totalAnomalies += anomalies

            if i % progressInterval == 0 {
                let pct = Int(Double(i) / Double(nBatches) * 100)
                print(String(format: "  [%3d%%] batch %6d / %d  |  last latency: %.3f ms",
                             pct, i, nBatches, elapsed * 1000))
            }
        }

        let streamTime = now() - streamStart
        print("  [100%] complete")

        // ── 5. Compute statistics ─────────────────────────────────────────────

        let totalRecords  = nBatches * Config.streamingBatch
        let avgLatency    = latencies.reduce(0, +) / Double(latencies.count)
        let minLatency    = latencies.min() ?? 0
        let p99Latency    = percentile(latencies, 0.99)
        let throughput    = Double(totalRecords) / streamTime

        // Approximate peak memory: transaction array + result buffer
        let txnMB    = Double(transactions.count * MemoryLayout<Transaction>.stride) / 1_048_576
        let resMB    = Double(Config.streamingBatch * MemoryLayout<ScoredResult>.stride) / 1_048_576
        let peakMB   = txnMB + resMB

        // ── 6. Print results ──────────────────────────────────────────────────

        print("\n" + String(repeating: "─", count: 52))
        print("  Results")
        print(String(repeating: "─", count: 52))
        printStat("Engine",          "Swift / Metal (Apple Silicon GPU)")
        printStat("Device",          engine.deviceName)
        printStat("Stream time",     String(format: "%.2f s", streamTime))
        printStat("Peak memory",     String(format: "%.0f MB (unified)", peakMB))
        printStat("Total records",   totalRecords.formatted())
        printStat("Total anomalies", totalAnomalies.formatted())
        printStat("Throughput",      String(format: "%.0f rec/s", throughput))
        printStat("Avg latency",     String(format: "%.3f ms", avgLatency))
        printStat("P99 latency",     String(format: "%.3f ms", p99Latency))
        printStat("Min latency",     String(format: "%.3f ms", minLatency))
        print(String(repeating: "─", count: 52))

        // ── 7. Save JSON ──────────────────────────────────────────────────────

        let result = BenchmarkResult(
            engine:         "Swift / Metal (Apple Silicon GPU)",
            device:         engine.deviceName,
            baselineTimeS:  0,          // baselines are baked in at generation time
            streamTimeS:    streamTime,
            peakMemoryMB:   peakMB,
            totalBatches:   nBatches,
            totalRecords:   totalRecords,
            totalAnomalies: totalAnomalies,
            throughputRps:  throughput,
            avgLatencyMs:   avgLatency,
            p99LatencyMs:   p99Latency,
            minLatencyMs:   minLatency
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            let outPath = "benchmark_results_swift.json"
            try? json.write(toFile: outPath, atomically: true, encoding: .utf8)
            print("\nResults saved → \(outPath)")
        }

        print("\nNext: load both JSON files into the visualiser for the full comparison.")
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    static func now() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000.0
    }

    static func percentile(_ values: [Double], _ p: Double) -> Double {
        let sorted = values.sorted()
        let idx    = Int(Double(sorted.count - 1) * p)
        return sorted[idx]
    }

    static func printStat(_ label: String, _ value: String) {
        print(String(format: "  %-18s %@", label, value))
    }

    static func printHeader() {
        print(String(repeating: "═", count: 52))
        print("  Kiraa AI — Financial Anomaly Detection Benchmark")
        print("  Swift / Metal  |  Apple Silicon GPU")
        print(String(repeating: "═", count: 52))
        print()
    }
}
