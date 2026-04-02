import XCTest
@testable import TestBench

/// Tests for BenchmarkViewModel state management and computed properties.
final class BenchmarkViewModelTests: XCTestCase {

    func testInitialState() {
        let vm = BenchmarkViewModel()
        XCTAssertFalse(vm.isRunning)
        XCTAssertEqual(vm.statusMessage, "Ready")
        XCTAssertEqual(vm.progress, 0.0)
        XCTAssertEqual(vm.currentTask, "")
        XCTAssertNil(vm.gpuResult)
        // pythonResult may or may not be nil depending on whether the JSON is bundled
    }

    func testSpeedup_nilWhenNoGpuResult() {
        let vm = BenchmarkViewModel()
        vm.pythonResult = BenchmarkResult(
            engine: "Python", totalTimeMs: 1000, totalRecords: 10,
            throughputRps: 10, tasks: []
        )
        vm.gpuResult = nil
        XCTAssertNil(vm.speedup)
    }

    func testSpeedup_nilWhenNoPythonResult() {
        let vm = BenchmarkViewModel()
        vm.pythonResult = nil
        vm.gpuResult = BenchmarkResult(
            engine: "Swift", totalTimeMs: 100, totalRecords: 10,
            throughputRps: 100, tasks: []
        )
        XCTAssertNil(vm.speedup)
    }

    func testSpeedup_calculatesCorrectly() throws {
        let vm = BenchmarkViewModel()
        vm.pythonResult = BenchmarkResult(
            engine: "Python", totalTimeMs: 1000, totalRecords: 10,
            throughputRps: 10, tasks: []
        )
        vm.gpuResult = BenchmarkResult(
            engine: "Swift", totalTimeMs: 100, totalRecords: 10,
            throughputRps: 100, tasks: []
        )
        let speedup = try XCTUnwrap(vm.speedup)
        XCTAssertEqual(speedup, 10.0, accuracy: 1e-10)
    }

    func testSpeedup_nilWhenGpuTimeZero() {
        let vm = BenchmarkViewModel()
        vm.pythonResult = BenchmarkResult(
            engine: "Python", totalTimeMs: 1000, totalRecords: 10,
            throughputRps: 10, tasks: []
        )
        vm.gpuResult = BenchmarkResult(
            engine: "Swift", totalTimeMs: 0, totalRecords: 10,
            throughputRps: 0, tasks: []
        )
        XCTAssertNil(vm.speedup, "Division by zero should return nil")
    }

    func testBothComplete_falseWhenPartial() {
        let vm = BenchmarkViewModel()
        vm.pythonResult = BenchmarkResult(
            engine: "Python", totalTimeMs: 100, totalRecords: 10,
            throughputRps: 100, tasks: []
        )
        vm.gpuResult = nil
        XCTAssertFalse(vm.bothComplete)
    }

    func testBothComplete_trueWhenBothSet() {
        let vm = BenchmarkViewModel()
        vm.pythonResult = BenchmarkResult(
            engine: "Python", totalTimeMs: 100, totalRecords: 10,
            throughputRps: 100, tasks: []
        )
        vm.gpuResult = BenchmarkResult(
            engine: "Swift", totalTimeMs: 10, totalRecords: 10,
            throughputRps: 1000, tasks: []
        )
        XCTAssertTrue(vm.bothComplete)
    }

    func testRunBenchmark_guardsWhenRunning() {
        let vm = BenchmarkViewModel()
        vm.isRunning = true
        let previousStatus = vm.statusMessage

        vm.runBenchmark()  // Should be a no-op

        // Status should not change to "Running..." since guard blocked it
        XCTAssertEqual(vm.statusMessage, previousStatus)
    }
}
