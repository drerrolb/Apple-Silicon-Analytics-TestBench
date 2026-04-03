import SwiftUI
import Metal

/// Orchestrates the benchmark lifecycle and manages UI state.
///
/// On initialisation, attempts to load pre-computed Python benchmark results
/// from a bundled JSON file. When the user taps "Run Benchmark", generates
/// (or loads) transaction data, creates a `MetalEngine`, runs the 5-task
/// benchmark via `SwiftBenchmarkRunner`, and publishes results to the UI.
@Observable
final class BenchmarkViewModel {

    var isRunning     = false
    var statusMessage = "Ready"
    var progress      = 0.0
    var currentTask   = ""

    var gpuResult: BenchmarkResult?
    var pythonResult: BenchmarkResult?

    /// Detailed intermediate data from the GPU benchmark run (for charting).
    var gpuData: BenchmarkData?

    var gpuAvailable: Bool = false

    /// Performance multiplier: Python total time ÷ GPU total time.
    /// Returns nil if either result is missing or GPU time is zero (avoid division by zero).
    var speedup: Double? {
        guard let py = pythonResult, let gpu = gpuResult,
              gpu.totalTimeMs > 0 else { return nil }
        return py.totalTimeMs / gpu.totalTimeMs
    }

    /// True when both Python and GPU results are available for comparison.
    var bothComplete: Bool { pythonResult != nil && gpuResult != nil }

    init() {
        self.gpuAvailable = MTLCreateSystemDefaultDevice() != nil
        loadPythonResults()
    }

    /// Load pre-computed Python benchmark results from the app bundle.
    ///
    /// Looks for `benchmark_results_python.json` in the bundle (copied there by
    /// `run_benchmark.sh`). Silently no-ops if the file is missing — the dashboard
    /// will show the Python card as empty until results are available.
    func loadPythonResults() {
        if let url = Bundle.main.url(forResource: "benchmark_results_python", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let result = try? JSONDecoder().decode(BenchmarkResult.self, from: data) {
            pythonResult = result
        }
    }

    /// Run the full 5-task Swift + Metal benchmark.
    ///
    /// Execution sequence:
    /// 1. Guard: no-op if already running or no Metal GPU available.
    /// 2. Try to load data from a bundled CSV (shared with Python); fall back to
    ///    in-memory generation via `DataGenerator.generate()`.
    /// 3. Create a `MetalEngine` with the computed baselines.
    /// 4. Run `SwiftBenchmarkRunner.run()` on a detached task (off MainActor).
    /// 5. Publish results back to MainActor for UI update.
    ///
    /// Uses `Task.detached { [self] }` to avoid running the benchmark on MainActor.
    /// Captures `self` strongly because the task must outlive the calling scope —
    /// results are published via `MainActor.run` at the end.
    func runBenchmark() {
        guard !isRunning, gpuAvailable else { return }

        isRunning = true
        gpuResult = nil
        gpuData = nil
        progress = 0
        currentTask = "Generating data..."
        statusMessage = "Running..."

        Task.detached { [self] in
            let transactions: [Transaction]
            let ccBaselines: [Baseline]
            let plantBaselines: [Baseline]

            // Prefer the shared CSV (ensures Python/Swift data parity) over
            // in-memory generation (which uses a different RNG algorithm).
            if let csvURL = Bundle.main.url(forResource: "benchmark_data", withExtension: "csv") {
                do {
                    (transactions, ccBaselines, plantBaselines) = try DataGenerator.loadFromCSV(url: csvURL)
                } catch {
                    (transactions, ccBaselines, plantBaselines) = DataGenerator.generate(rowCount: Config.numRows)
                }
            } else {
                (transactions, ccBaselines, plantBaselines) = DataGenerator.generate(rowCount: Config.numRows)
            }

            var metalEngine: MetalEngine?
            do {
                metalEngine = try MetalEngine(batchSize: Config.streamingBatch, baselines: ccBaselines)
            } catch {
                await MainActor.run {
                    self.statusMessage = "Metal error: \(error.localizedDescription)"
                    self.isRunning = false
                }
                return
            }

            let (result, data) = SwiftBenchmarkRunner.run(
                transactions: transactions,
                baselines: ccBaselines,
                metalEngine: metalEngine
            ) { progress in
                Task { @MainActor in
                    self.progress = Double(progress.currentTask) / Double(progress.totalTasks)
                    self.currentTask = "Task \(progress.currentTask)/\(progress.totalTasks): \(progress.taskName)"
                }
            }

            await MainActor.run {
                self.gpuResult = result
                self.gpuData = data
                self.progress = 1.0
                self.isRunning = false
                self.currentTask = ""
                if let s = self.speedup {
                    self.statusMessage = String(format: "Complete — %.0f× faster", s)
                } else {
                    self.statusMessage = "Complete"
                }
            }
        }
    }
}
