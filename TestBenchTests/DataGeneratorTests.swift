import XCTest
@testable import TestBench

/// Tests for synthetic data generation, CSV loading, and baseline computation.
final class DataGeneratorTests: XCTestCase {

    // MARK: - generate() tests

    func testGenerate_rowCount() {
        let (txns, _, _) = DataGenerator.generate(rowCount: 1000)
        XCTAssertEqual(txns.count, 1000)
    }

    func testGenerate_costCentreIdsInRange() {
        let (txns, _, _) = DataGenerator.generate(rowCount: 5000)
        let maxId = UInt32(Config.costCentres.count)
        for txn in txns {
            XCTAssertLessThan(txn.costCentreId, maxId,
                              "costCentreId \(txn.costCentreId) out of range")
        }
    }

    func testGenerate_txnTypeIdsInRange() {
        let (txns, _, _) = DataGenerator.generate(rowCount: 5000)
        let maxId = UInt32(Config.transactionTypes.count)
        for txn in txns {
            XCTAssertLessThan(txn.txnTypeId, maxId)
        }
    }

    func testGenerate_plantCodeIdsInRange() {
        let (txns, _, _) = DataGenerator.generate(rowCount: 5000)
        let maxId = UInt32(Config.plantCodes.count)
        for txn in txns {
            XCTAssertLessThan(txn.plantCodeId, maxId)
        }
    }

    func testGenerate_supplierIdsInRange() {
        let (txns, _, _) = DataGenerator.generate(rowCount: 5000)
        for txn in txns {
            XCTAssertGreaterThanOrEqual(txn.supplierId, 1000)
            XCTAssertLessThan(txn.supplierId, 9999)
        }
    }

    func testGenerate_baselinesCount() {
        let (_, ccBaselines, plantBaselines) = DataGenerator.generate(rowCount: 1000)
        XCTAssertEqual(ccBaselines.count, Config.costCentres.count,
                       "Should have one baseline per cost centre")
        XCTAssertEqual(plantBaselines.count, Config.plantCodes.count,
                       "Should have one baseline per plant")
    }

    func testGenerate_baselinesMeanPositive() {
        let (_, ccBaselines, plantBaselines) = DataGenerator.generate(rowCount: 10_000)
        for bl in ccBaselines {
            // Base amounts are 5K–500K, so means should be positive even with anomalies
            XCTAssertGreaterThan(bl.mean, 0, "Cost centre baseline mean should be positive")
        }
        for bl in plantBaselines {
            XCTAssertGreaterThan(bl.mean, 0, "Plant baseline mean should be positive")
        }
    }

    func testGenerate_baselinesStdDevPositive() {
        let (_, ccBaselines, plantBaselines) = DataGenerator.generate(rowCount: 10_000)
        for bl in ccBaselines {
            XCTAssertGreaterThan(bl.stdDev, 0, "Cost centre stdDev should be > 0 with varied data")
        }
        for bl in plantBaselines {
            XCTAssertGreaterThan(bl.stdDev, 0, "Plant stdDev should be > 0 with varied data")
        }
    }

    func testGenerate_deterministic() {
        let (txns1, cc1, _) = DataGenerator.generate(rowCount: 100)
        let (txns2, cc2, _) = DataGenerator.generate(rowCount: 100)

        XCTAssertEqual(txns1.count, txns2.count)
        for i in 0 ..< txns1.count {
            XCTAssertEqual(txns1[i].amount, txns2[i].amount,
                           "Transaction \(i) amount should be deterministic")
            XCTAssertEqual(txns1[i].costCentreId, txns2[i].costCentreId)
            XCTAssertEqual(txns1[i].supplierId, txns2[i].supplierId)
        }
        for i in 0 ..< cc1.count {
            XCTAssertEqual(cc1[i].mean, cc2[i].mean)
            XCTAssertEqual(cc1[i].stdDev, cc2[i].stdDev)
        }
    }

    func testGenerate_anomalyRate() {
        // With 100K rows, expect ~200 anomalies (0.2%). Allow ± 0.1%.
        let rowCount = 100_000
        let (txns, ccBaselines, _) = DataGenerator.generate(rowCount: rowCount)

        // Count transactions beyond 4σ as a proxy for injected anomalies
        var extremeCount = 0
        for txn in txns {
            let bl = ccBaselines[Int(txn.costCentreId)]
            if bl.stdDev > 0 {
                let z = abs((txn.amount - bl.mean) / bl.stdDev)
                if z > 5.0 { extremeCount += 1 }
            }
        }

        let rate = Double(extremeCount) / Double(rowCount)
        // Anomaly rate should be roughly 0.2% ± 0.15% (generous tolerance for the proxy)
        XCTAssertGreaterThan(rate, 0.0005, "Anomaly rate \(rate) too low")
        XCTAssertLessThan(rate, 0.005, "Anomaly rate \(rate) too high")
    }

    // MARK: - loadFromCSV() tests

    func testLoadFromCSV_validFile() throws {
        let csv = """
        amount,cost_centre_id,txn_type_id,supplier_id,plant_code_id
        100.0,0,1,1234,0
        200.0,1,2,5678,1
        300.0,0,3,9012,2
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_valid.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let (txns, ccBaselines, plantBaselines) = try DataGenerator.loadFromCSV(url: url)

        XCTAssertEqual(txns.count, 3)
        XCTAssertEqual(txns[0].amount, 100.0)
        XCTAssertEqual(txns[1].costCentreId, 1)
        XCTAssertEqual(txns[2].plantCodeId, 2)
        XCTAssertEqual(ccBaselines.count, Config.costCentres.count)
        XCTAssertEqual(plantBaselines.count, Config.plantCodes.count)
    }

    func testLoadFromCSV_emptyFile() throws {
        let csv = "amount,cost_centre_id,txn_type_id,supplier_id,plant_code_id\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try DataGenerator.loadFromCSV(url: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("empty"),
                          "Should report CSV is empty")
        }
    }

    func testLoadFromCSV_malformedRowsSkipped() throws {
        let csv = """
        amount,cost_centre_id,txn_type_id,supplier_id,plant_code_id
        100.0,0,1,1234,0
        bad,row
        300.0,0,3,9012,2
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_malformed.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let (txns, _, _) = try DataGenerator.loadFromCSV(url: url)
        XCTAssertEqual(txns.count, 2, "Malformed rows should be skipped")
    }
}
