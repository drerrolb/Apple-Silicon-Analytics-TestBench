import XCTest
@testable import TestBench

/// Tests for SwiftBenchmarkRunner using the CPU fallback path (metalEngine: nil).
///
/// Uses small, controlled datasets to verify each of the 5 benchmark tasks
/// produces correct results. Metal GPU is not available in the simulator,
/// so all tests exercise the CPU code path.
final class BenchmarkRunnerTests: XCTestCase {

    /// Create a controlled set of transactions for testing.
    private func makeTestTransactions() -> ([Transaction], [Baseline]) {
        // 12 transactions, one per cost centre, with known amounts
        let amounts: [Float] = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200]
        var txns = [Transaction]()
        for (i, amount) in amounts.enumerated() {
            txns.append(Transaction(
                amount: amount,
                costCentreId: UInt32(i % Config.costCentres.count),
                txnTypeId: 0,
                supplierId: UInt32(1000 + i),
                plantCodeId: UInt32(i % Config.plantCodes.count)
            ))
        }

        // Simple baselines: mean=650, stdDev=100 for all cost centres
        let baselines = (0 ..< Config.costCentres.count).map { _ in
            Baseline(mean: 650, stdDev: 100)
        }

        return (txns, baselines)
    }

    private func runBenchmark(transactions: [Transaction], baselines: [Baseline]) -> BenchmarkResult {
        let (result, _) = SwiftBenchmarkRunner.run(
            transactions: transactions,
            baselines: baselines,
            metalEngine: nil
        ) { _ in }
        return result
    }

    func testRun_returns5Tasks() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertEqual(result.tasks.count, 5)
    }

    func testRun_taskNames() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)

        let expectedNames = [
            "Total by cost centre",
            "Top 10 suppliers",
            "Z-score anomaly detection",
            "Plant × cost centre pivot",
            "Running total"
        ]
        XCTAssertEqual(result.tasks.map(\.name), expectedNames)
    }

    func testRun_totalByCostCentre_12Groups() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertEqual(result.tasks[0].summary, "12 groups")
    }

    func testRun_top10Suppliers() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        // Supplier 1011 (index 11) has amount 1200 — the highest
        XCTAssertTrue(result.tasks[1].summary.contains("1011"),
                      "Top supplier should be 1011, got: \(result.tasks[1].summary)")
    }

    func testRun_zScoreDetectsKnownAnomaly() {
        // Create one extreme outlier: amount = mean + 10σ
        var txns = [Transaction(
            amount: 650 + 10 * 100,  // z = 10.0, well above threshold
            costCentreId: 0, txnTypeId: 0, supplierId: 1000, plantCodeId: 0
        )]
        // Add some normal transactions
        for i in 1 ..< 100 {
            txns.append(Transaction(
                amount: 650,  // z = 0
                costCentreId: 0, txnTypeId: 0,
                supplierId: UInt32(1000 + i), plantCodeId: 0
            ))
        }
        let baselines = (0 ..< Config.costCentres.count).map { _ in
            Baseline(mean: 650, stdDev: 100)
        }

        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertTrue(result.tasks[2].summary.contains("1"),
                      "Should detect at least 1 anomaly, got: \(result.tasks[2].summary)")
    }

    func testRun_zScoreZeroStdDev_noCrash() {
        let txns = [Transaction(
            amount: 999, costCentreId: 0, txnTypeId: 0,
            supplierId: 1000, plantCodeId: 0
        )]
        // All baselines have stdDev = 0 → z should be 0, no anomaly
        let baselines = (0 ..< Config.costCentres.count).map { _ in
            Baseline(mean: 500, stdDev: 0)
        }

        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertTrue(result.tasks[2].summary.contains("0 anomalies"),
                      "Zero stdDev should yield 0 anomalies, got: \(result.tasks[2].summary)")
    }

    func testRun_pivotReturns48Cells() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertEqual(result.tasks[3].summary, "48 cells")
    }

    func testRun_runningTotal() {
        // amounts: 100 + 200 + ... + 1200 = 7800
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertTrue(result.tasks[4].summary.contains("7800.00"),
                      "Running total should be $7800.00, got: \(result.tasks[4].summary)")
    }

    func testRun_emptyTransactions_noCrash() {
        let baselines = (0 ..< Config.costCentres.count).map { _ in
            Baseline(mean: 0, stdDev: 0)
        }
        let result = runBenchmark(transactions: [], baselines: baselines)
        XCTAssertEqual(result.tasks.count, 5, "Should still produce 5 task results")
        XCTAssertEqual(result.totalRecords, 0)
    }

    func testRun_singleTransaction() {
        let txns = [Transaction(
            amount: 42, costCentreId: 0, txnTypeId: 0,
            supplierId: 1000, plantCodeId: 0
        )]
        let baselines = (0 ..< Config.costCentres.count).map { _ in
            Baseline(mean: 42, stdDev: 10)
        }

        let result = runBenchmark(transactions: txns, baselines: baselines)
        XCTAssertEqual(result.tasks.count, 5)
        XCTAssertEqual(result.totalRecords, 1)
    }

    func testRun_progressCallbackFired5Times() {
        let (txns, baselines) = makeTestTransactions()
        var progressCalls = [Int]()

        _ = SwiftBenchmarkRunner.run(
            // Returns (BenchmarkResult, BenchmarkData) — discard both here
            transactions: txns,
            baselines: baselines,
            metalEngine: nil
        ) { progress in
            progressCalls.append(progress.currentTask)
        }

        XCTAssertEqual(progressCalls, [1, 2, 3, 4, 5])
    }

    func testRun_timingsAreNonNegative() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)
        for task in result.tasks {
            XCTAssertGreaterThanOrEqual(task.timeMs, 0,
                                        "Task '\(task.name)' has negative timing")
        }
    }

    func testRun_throughputCalculation() {
        let (txns, baselines) = makeTestTransactions()
        let result = runBenchmark(transactions: txns, baselines: baselines)

        if result.totalTimeMs > 0 {
            let expected = Double(result.totalRecords) / (result.totalTimeMs / 1000)
            XCTAssertEqual(result.throughputRps, expected, accuracy: 0.01)
        }
    }
}
