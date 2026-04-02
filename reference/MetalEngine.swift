// MetalEngine.swift
// Kiraa AI — Metal GPU Compute Pipeline
//
// Sets up the Metal device, compiles the compute pipeline from the
// bundled .metal shader, and exposes a single scoreBatch() method.
//
// Key Apple Silicon advantage: MTLStorageMode.shared means the CPU-written
// transaction buffers are directly readable by the GPU — zero copy,
// zero PCIe latency. This is the unified memory architecture at work.

import Metal
import Foundation

final class MetalEngine {

    // ── Metal objects ─────────────────────────────────────────────────────────

    private let device:          MTLDevice
    private let commandQueue:    MTLCommandQueue
    private let pipelineState:   MTLComputePipelineState

    // Persistent buffers — allocated once, reused across all batches
    private let transactionBuffer: MTLBuffer
    private let baselineBuffer:    MTLBuffer
    private let resultBuffer:      MTLBuffer
    private let thresholdBuffer:   MTLBuffer

    private let batchSize: Int

    // ── Init ──────────────────────────────────────────────────────────────────

    init(batchSize: Int, baselines: [Baseline]) throws {
        self.batchSize = batchSize

        // Grab the default Metal device (Apple Silicon GPU)
        guard let dev = MTLCreateSystemDefaultDevice() else {
            throw MetalError.noDevice
        }
        self.device = dev

        guard let queue = dev.makeCommandQueue() else {
            throw MetalError.noCommandQueue
        }
        self.commandQueue = queue

        // Load the compiled Metal library from the app bundle
        let library: MTLLibrary
        if let bundlePath = Bundle.module.path(forResource: "AnomalyScoring", ofType: "metallib") {
            library = try dev.makeLibrary(URL: URL(fileURLWithPath: bundlePath))
        } else {
            // Fallback: compile from source at runtime (development mode)
            library = try dev.makeDefaultLibrary(bundle: Bundle.module)
        }

        guard let kernelFn = library.makeFunction(name: "scoreTransactions") else {
            throw MetalError.kernelNotFound
        }
        self.pipelineState = try dev.makeComputePipelineState(function: kernelFn)

        // ── Allocate shared buffers (CPU writes, GPU reads — zero copy) ───────

        let txnSize     = batchSize * MemoryLayout<Transaction>.stride
        let baseSize    = baselines.count * MemoryLayout<Baseline>.stride
        let resultSize  = batchSize * MemoryLayout<ScoredResult>.stride
        let threshSize  = MemoryLayout<Float>.stride

        guard
            let txnBuf  = dev.makeBuffer(length: txnSize,   options: .storageModeShared),
            let baseBuf = dev.makeBuffer(bytes: baselines,
                                         length: baseSize,
                                         options: .storageModeShared),
            let resBuf  = dev.makeBuffer(length: resultSize, options: .storageModeShared),
            let thrBuf  = dev.makeBuffer(length: threshSize, options: .storageModeShared)
        else {
            throw MetalError.bufferAllocation
        }

        self.transactionBuffer = txnBuf
        self.baselineBuffer    = baseBuf
        self.resultBuffer      = resBuf
        self.thresholdBuffer   = thrBuf

        // Write threshold once
        var threshold = Config.zThreshold
        memcpy(thrBuf.contents(), &threshold, threshSize)
    }

    // ── Score a batch ─────────────────────────────────────────────────────────
    //
    // Returns (anomalyCount, wallTimeSeconds)
    // The GPU work is fully synchronous from the caller's perspective —
    // waitUntilCompleted() blocks until all shader threads have finished.

    func scoreBatch(_ batch: ArraySlice<Transaction>) -> (anomalies: Int, seconds: Double) {
        let count = batch.count

        // Copy batch into the shared buffer — CPU writes, GPU reads directly
        batch.withUnsafeBytes { ptr in
            memcpy(transactionBuffer.contents(), ptr.baseAddress!, count * MemoryLayout<Transaction>.stride)
        }

        guard
            let cmdBuffer = commandQueue.makeCommandBuffer(),
            let encoder   = cmdBuffer.makeComputeCommandEncoder()
        else { return (0, 0) }

        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(transactionBuffer, offset: 0, index: 0)
        encoder.setBuffer(baselineBuffer,    offset: 0, index: 1)
        encoder.setBuffer(resultBuffer,      offset: 0, index: 2)
        encoder.setBuffer(thresholdBuffer,   offset: 0, index: 3)

        // Thread group sizing — use pipeline's recommended width
        let threadGroupSize = MTLSize(
            width:  min(pipelineState.maxTotalThreadsPerThreadgroup, count),
            height: 1,
            depth:  1
        )
        let threadGroups = MTLSize(
            width:  (count + threadGroupSize.width - 1) / threadGroupSize.width,
            height: 1,
            depth:  1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        let t0 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        let t1 = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)

        let elapsed = Double(t1 - t0) / 1_000_000_000.0

        // Read results back — pointer into shared memory, no copy needed
        let resultsPtr = resultBuffer.contents().bindMemory(
            to: ScoredResult.self, capacity: count
        )
        var anomalyCount = 0
        for i in 0 ..< count {
            if resultsPtr[i].isAnomaly == 1 { anomalyCount += 1 }
        }

        return (anomalyCount, elapsed)
    }

    // ── Device info ───────────────────────────────────────────────────────────

    var deviceName: String { device.name }
    var maxThreadsPerGroup: Int { pipelineState.maxTotalThreadsPerThreadgroup }
}

// ── Errors ────────────────────────────────────────────────────────────────────

enum MetalError: Error, LocalizedError {
    case noDevice
    case noCommandQueue
    case kernelNotFound
    case bufferAllocation

    var errorDescription: String? {
        switch self {
        case .noDevice:         return "No Metal device found. Apple Silicon required."
        case .noCommandQueue:   return "Failed to create Metal command queue."
        case .kernelNotFound:   return "Metal kernel 'scoreTransactions' not found in library."
        case .bufferAllocation: return "Failed to allocate Metal buffers."
        }
    }
}
