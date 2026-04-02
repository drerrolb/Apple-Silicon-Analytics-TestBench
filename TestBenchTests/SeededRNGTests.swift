import XCTest
@testable import TestBench

/// Tests for the Splitmix64 deterministic RNG and Box-Muller Gaussian transform.
final class SeededRNGTests: XCTestCase {

    func testDeterminism_sameSeedProducesSameSequence() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 42)

        for _ in 0 ..< 1000 {
            XCTAssertEqual(rng1.next(), rng2.next())
        }
    }

    func testDeterminism_differentSeedsProduceDifferentSequence() {
        var rng1 = SeededRNG(seed: 42)
        var rng2 = SeededRNG(seed: 99)

        XCTAssertNotEqual(rng1.next(), rng2.next(),
                          "Different seeds should produce different first values")
    }

    func testGaussianRandom_meanAndStdDev() {
        var rng = SeededRNG(seed: 42)
        let targetMean = 1000.0
        let targetStd = 100.0
        let n = 100_000

        var samples = [Double]()
        samples.reserveCapacity(n)
        for _ in 0 ..< n {
            samples.append(gaussianRandom(mean: targetMean, std: targetStd, rng: &rng))
        }

        let sampleMean = samples.reduce(0, +) / Double(n)
        let sampleVariance = samples.reduce(0) { $0 + ($1 - sampleMean) * ($1 - sampleMean) } / Double(n - 1)
        let sampleStd = sqrt(sampleVariance)

        // Mean within 1% of target
        XCTAssertEqual(sampleMean, targetMean, accuracy: targetMean * 0.01,
                       "Sample mean \(sampleMean) should be within 1% of \(targetMean)")
        // StdDev within 5% of target
        XCTAssertEqual(sampleStd, targetStd, accuracy: targetStd * 0.05,
                       "Sample stddev \(sampleStd) should be within 5% of \(targetStd)")
    }

    func testGaussianRandom_zeroStdDev() {
        var rng = SeededRNG(seed: 42)
        // With std=0, Box-Muller's z0 * 0 = 0, so result should always be exactly the mean.
        for _ in 0 ..< 100 {
            let val = gaussianRandom(mean: 500.0, std: 0.0, rng: &rng)
            XCTAssertEqual(val, 500.0, accuracy: 1e-10)
        }
    }

    func testSplitmix64_noZeroCycle() {
        var rng = SeededRNG(seed: 42)
        for i in 0 ..< 10_000 {
            let val = rng.next()
            XCTAssertNotEqual(val, 0, "Value at index \(i) should not be 0")
        }
    }
}
