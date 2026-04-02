import Foundation

// MARK: - Timing helpers

/// Returns the current monotonic wall-clock time in seconds.
///
/// Uses `CLOCK_UPTIME_RAW` which is not affected by NTP adjustments or system
/// sleep, providing nanosecond resolution. Suitable for measuring elapsed time
/// between two calls (e.g. `let elapsed = highResolutionTime() - start`).
nonisolated func highResolutionTime() -> Double {
    Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000.0
}
