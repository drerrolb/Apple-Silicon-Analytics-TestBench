import XCTest
@testable import TestBench

/// Tests for z-score anomaly detection logic (CPU fallback path).
///
/// These test the exact same formula used by the Metal shader and the
/// SwiftBenchmarkRunner CPU fallback: z = (amount - mean) / stdDev,
/// anomaly = |z| > 3.5.
final class ZScoreTests: XCTestCase {

    /// Helper: compute z-score using the same logic as SwiftBenchmarkRunner CPU fallback.
    private func computeZScore(amount: Float, mean: Float, stdDev: Float) -> Float {
        stdDev > 0 ? (amount - mean) / stdDev : 0
    }

    private func isAnomaly(amount: Float, mean: Float, stdDev: Float) -> Bool {
        abs(computeZScore(amount: amount, mean: mean, stdDev: stdDev)) > Config.zThreshold
    }

    func testZScore_knownPositive() {
        // amount=150, mean=100, std=10 → z = (150-100)/10 = 5.0
        let z = computeZScore(amount: 150, mean: 100, stdDev: 10)
        XCTAssertEqual(z, 5.0, accuracy: 1e-5)
    }

    func testZScore_knownNegative() {
        // amount=50, mean=100, std=10 → z = (50-100)/10 = -5.0
        let z = computeZScore(amount: 50, mean: 100, stdDev: 10)
        XCTAssertEqual(z, -5.0, accuracy: 1e-5)
    }

    func testZScore_exactlyAtThreshold_notAnomaly() {
        // z = 3.5 exactly → |z| > 3.5 is FALSE (strict inequality)
        let mean: Float = 100
        let std: Float = 10
        let amount = mean + Config.zThreshold * std  // z = 3.5 exactly
        XCTAssertFalse(isAnomaly(amount: amount, mean: mean, stdDev: std),
                       "z = 3.5 exactly should NOT be flagged (strict >)")
    }

    func testZScore_justAboveThreshold_isAnomaly() {
        let mean: Float = 100
        let std: Float = 10
        let amount = mean + 3.51 * std  // z = 3.51 > 3.5
        XCTAssertTrue(isAnomaly(amount: amount, mean: mean, stdDev: std))
    }

    func testZScore_zeroStdDev_returnsZero() {
        // When stdDev = 0, z should be 0 → not anomaly
        let z = computeZScore(amount: 999, mean: 100, stdDev: 0)
        XCTAssertEqual(z, 0)
        XCTAssertFalse(isAnomaly(amount: 999, mean: 100, stdDev: 0))
    }

    func testZScore_normalTransaction_notAnomaly() {
        // amount close to mean → z < 3.5
        let mean: Float = 100_000
        let std: Float = 15_000
        let amount: Float = 110_000  // z = 10000/15000 ≈ 0.67
        XCTAssertFalse(isAnomaly(amount: amount, mean: mean, stdDev: std))
    }

    func testZScore_extremeNegativeAnomaly() {
        // Negative anomaly (amount * -5x multiplier)
        let mean: Float = 100_000
        let std: Float = 15_000
        let amount: Float = -500_000  // z = -600000/15000 = -40
        XCTAssertTrue(isAnomaly(amount: amount, mean: mean, stdDev: std))
    }
}
