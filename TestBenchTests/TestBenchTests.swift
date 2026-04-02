import XCTest
@testable import TestBench

// MARK: - Metal Struct Alignment Tests

/// Verifies that GPU-layout structs match the Metal shader expectations.
/// Any change to struct layout will break GPU scoring silently — these tests
/// catch that at compile/test time.
final class MetalStructAlignmentTests: XCTestCase {

    func testTransactionStride_is24Bytes() {
        XCTAssertEqual(MemoryLayout<Transaction>.stride, 24,
                       "Transaction stride must be 24 bytes to match Metal shader struct")
    }

    func testTransactionSize_is24Bytes() {
        XCTAssertEqual(MemoryLayout<Transaction>.size, 24)
    }

    func testBaselineStride_is8Bytes() {
        XCTAssertEqual(MemoryLayout<Baseline>.stride, 8)
    }

    func testScoredResultStride_is8Bytes() {
        XCTAssertEqual(MemoryLayout<ScoredResult>.stride, 8)
    }

    func testTransactionFieldOffsets() {
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \.amount), 0)
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \.costCentreId), 4)
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \.txnTypeId), 8)
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \.supplierId), 12)
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \.plantCodeId), 16)
        XCTAssertEqual(MemoryLayout<Transaction>.offset(of: \._pad), 20)
    }

    func testTransactionPadDefaultsToZero() {
        let txn = Transaction(amount: 1, costCentreId: 0, txnTypeId: 0,
                              supplierId: 0, plantCodeId: 0)
        XCTAssertEqual(txn._pad, 0)
    }
}

// MARK: - Config Constants Tests

final class ConfigTests: XCTestCase {

    func testConfig_numRows() {
        XCTAssertEqual(Config.numRows, 10_000_000)
    }

    func testConfig_anomalyRate() {
        XCTAssertEqual(Config.anomalyRate, 0.002, accuracy: 1e-10)
    }

    func testConfig_zThreshold() {
        XCTAssertEqual(Config.zThreshold, 3.5)
    }

    func testConfig_costCentresCount() {
        XCTAssertEqual(Config.costCentres.count, 12)
    }

    func testConfig_transactionTypesCount() {
        XCTAssertEqual(Config.transactionTypes.count, 7)
    }

    func testConfig_plantCodesCount() {
        XCTAssertEqual(Config.plantCodes.count, 4)
    }
}

// MARK: - Timing Helper Tests

final class TimingTests: XCTestCase {

    func testHighResolutionTime_positive() {
        XCTAssertGreaterThan(highResolutionTime(), 0)
    }

    func testHighResolutionTime_monotonic() {
        let t1 = highResolutionTime()
        // Do some trivial work to ensure time passes
        var sum = 0.0
        for i in 0 ..< 10_000 { sum += Double(i) }
        _ = sum
        let t2 = highResolutionTime()
        XCTAssertGreaterThan(t2, t1)
    }
}
