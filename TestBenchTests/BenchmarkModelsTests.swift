import XCTest
@testable import TestBench

/// Tests for BenchmarkResult JSON decoding, encoding, and CodingKeys.
final class BenchmarkModelsTests: XCTestCase {

    func testBenchmarkResult_decodesFromPythonJSON() throws {
        let json = """
        {
          "engine": "Python / Row-by-Row Loop (CPU)",
          "device": null,
          "total_time_ms": 469733.8,
          "total_records": 10000000,
          "throughput_rps": 21289.0,
          "tasks": [
            {"name": "Total by cost centre", "time_ms": 94024.9, "summary": "12 groups"},
            {"name": "Top 10 suppliers by spend", "time_ms": 95349.0, "summary": "top supplier: 1581"}
          ],
          "peak_memory_mb": 1976.4,
          "timestamp": "2026-04-02T17:48:10.702596",
          "machine_name": "Mac.modem",
          "cpu_model": "Apple M4 Max",
          "python_version": "3.14.3",
          "os_version": "Darwin 25.2.0"
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BenchmarkResult.self, from: data)

        XCTAssertEqual(result.engine, "Python / Row-by-Row Loop (CPU)")
        XCTAssertNil(result.device)
        XCTAssertEqual(result.totalTimeMs, 469733.8, accuracy: 0.1)
        XCTAssertEqual(result.totalRecords, 10_000_000)
        XCTAssertEqual(result.throughputRps, 21289.0, accuracy: 0.1)
        XCTAssertEqual(result.tasks.count, 2)
        XCTAssertEqual(result.peakMemoryMB, 1976.4)
        XCTAssertEqual(result.machineName, "Mac.modem")
        XCTAssertEqual(result.cpuModel, "Apple M4 Max")
        XCTAssertEqual(result.pythonVersion, "3.14.3")
        XCTAssertEqual(result.osVersion, "Darwin 25.2.0")
    }

    func testBenchmarkResult_encodeDecode_roundTrip() throws {
        let original = BenchmarkResult(
            engine: "Test Engine",
            device: "Test Device",
            totalTimeMs: 123.4,
            totalRecords: 1000,
            throughputRps: 8103.7,
            peakMemoryMB: 42.0,
            tasks: [
                TaskResult(name: "Task A", timeMs: 50.0, summary: "done"),
                TaskResult(name: "Task B", timeMs: 73.4, summary: "also done")
            ],
            timestamp: "2026-01-01T00:00:00",
            machineName: "test-machine",
            cpuModel: "Test CPU"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BenchmarkResult.self, from: data)

        XCTAssertEqual(decoded.engine, original.engine)
        XCTAssertEqual(decoded.device, original.device)
        XCTAssertEqual(decoded.totalTimeMs, original.totalTimeMs)
        XCTAssertEqual(decoded.totalRecords, original.totalRecords)
        XCTAssertEqual(decoded.tasks.count, original.tasks.count)
        XCTAssertEqual(decoded.tasks[0].name, "Task A")
        XCTAssertEqual(decoded.tasks[1].timeMs, 73.4)
    }

    func testTaskResult_snakeCaseCodingKeys() throws {
        let json = """
        {"name": "Z-score", "time_ms": 1234.5, "summary": "20K anomalies"}
        """
        let data = json.data(using: .utf8)!
        let task = try JSONDecoder().decode(TaskResult.self, from: data)

        XCTAssertEqual(task.name, "Z-score")
        XCTAssertEqual(task.timeMs, 1234.5)
        XCTAssertEqual(task.summary, "20K anomalies")
    }

    func testBenchmarkResult_nullableFields() throws {
        let json = """
        {
          "engine": "test",
          "device": null,
          "total_time_ms": 100,
          "total_records": 10,
          "throughput_rps": 100,
          "peak_memory_mb": null,
          "tasks": []
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(BenchmarkResult.self, from: data)

        XCTAssertNil(result.device)
        XCTAssertNil(result.peakMemoryMB)
        XCTAssertNil(result.timestamp)
        XCTAssertNil(result.machineName)
        XCTAssertNil(result.cpuModel)
        XCTAssertNil(result.pythonVersion)
        XCTAssertNil(result.osVersion)
    }
}
