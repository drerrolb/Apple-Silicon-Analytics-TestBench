import Foundation

// MARK: - Seeded RNG (Splitmix64, fast, deterministic)

/// Deterministic pseudo-random number generator using the Splitmix64 algorithm.
///
/// Used with seed 42 throughout data generation to produce reproducible datasets.
/// **Note:** This is *not* the same algorithm as Python's `numpy.random.default_rng(42)` (PCG64).
/// Results only match between Python and Swift when both load from the same shared CSV.
///
/// Marked `@unchecked Sendable` because instances are only used within a single
/// generation call (never shared across threads).
struct SeededRNG: RandomNumberGenerator, @unchecked Sendable {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    /// Advance state and return the next pseudo-random UInt64.
    ///
    /// Uses the Splitmix64 mixing function: increment by the golden-ratio-derived
    /// constant `0x9e3779b97f4a7c15`, then apply three xorshift-multiply stages
    /// to avalanche all bits.
    mutating func next() -> UInt64 {
        // Golden-ratio constant: floor(2^64 / φ) where φ = (1+√5)/2
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

/// Generate a normally distributed random value using the Box-Muller transform.
///
/// Converts two uniform random samples into a standard normal variate, then
/// scales by `mean` and `std`.
///
/// - Parameters:
///   - mean: Centre of the distribution.
///   - std: Standard deviation. Pass 0 to always return `mean`.
///   - rng: Deterministic RNG instance (consumes 2 values per call).
/// - Returns: A normally distributed Double.
nonisolated func gaussianRandom(mean: Double, std: Double, rng: inout SeededRNG) -> Double {
    let u1 = Double(rng.next()) / Double(UInt64.max)
    let u2 = Double(rng.next()) / Double(UInt64.max)
    // Guard against log(0) — clamp u1 to a minimum positive value.
    let z0 = sqrt(-2.0 * log(max(u1, 1e-10))) * cos(2.0 * .pi * u2)
    return mean + std * z0
}

// MARK: - Data Generator

/// Generates or loads synthetic ERP transaction data for benchmarking.
///
/// Provides two paths:
/// - `loadFromCSV(url:)` — loads from a shared CSV (ensures Python/Swift data parity)
/// - `generate(rowCount:)` — creates data in-memory with deterministic RNG (seed 42)
///
/// Both paths compute statistical baselines (mean/stdDev per cost centre and plant)
/// using Bessel's correction (ddof=1) to match Python's `pandas.DataFrame.std()`.
enum DataGenerator {

    /// Per-cost-centre base amounts, generated deterministically from seed 42.
    /// Each cost centre gets a random base in the range $5,000–$500,000.
    /// Transaction amounts are then drawn from a Gaussian with this base as the mean.
    static let baseAmounts: [Float] = {
        var rng = SeededRNG(seed: 42)
        return (0 ..< Config.costCentres.count).map { _ in
            Float.random(in: 5_000 ... 500_000, using: &rng)
        }
    }()

    /// Load transactions from a shared CSV file exported by `generate_data.py`.
    ///
    /// Expected CSV columns: `amount, cost_centre_id, txn_type_id, supplier_id, plant_code_id`.
    /// Rows with fewer than 5 fields are silently skipped.
    ///
    /// Baselines are computed inline from the loaded data using Bessel's correction
    /// (ddof=1) so that z-scores match Python's pandas-based computation.
    ///
    /// - Parameter url: Path to the CSV file.
    /// - Returns: `(transactions, costCentreBaselines, plantBaselines)`
    /// - Throws: If the file can't be read or contains only a header row.
    nonisolated static func loadFromCSV(url: URL) throws -> ([Transaction], [Baseline], [Baseline]) {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)

        guard lines.count > 1 else {
            throw NSError(domain: "DataGenerator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "CSV is empty"])
        }

        let rowCount = lines.count - 1  // skip header
        var transactions = [Transaction]()
        transactions.reserveCapacity(rowCount)

        let nPlants = Config.plantCodes.count

        // Double accumulators avoid Float precision loss over millions of rows.
        var ccSums    = [Double](repeating: 0, count: Config.costCentres.count)
        var ccSqSums  = [Double](repeating: 0, count: Config.costCentres.count)
        var ccCounts  = [Int](repeating: 0, count: Config.costCentres.count)
        var plantSums   = [Double](repeating: 0, count: nPlants)
        var plantSqSums = [Double](repeating: 0, count: nPlants)
        var plantCounts = [Int](repeating: 0, count: nPlants)

        for i in 1 ..< lines.count {
            let fields = lines[i].split(separator: ",")
            guard fields.count >= 5 else { continue }  // skip malformed rows

            let amount      = Float(fields[0]) ?? 0
            let ccId        = UInt32(fields[1]) ?? 0
            let txnTypeId   = UInt32(fields[2]) ?? 0
            let supplierId  = UInt32(fields[3]) ?? 0
            let plantCodeId = UInt32(fields[4]) ?? 0

            transactions.append(Transaction(
                amount: amount,
                costCentreId: ccId,
                txnTypeId: txnTypeId,
                supplierId: supplierId,
                plantCodeId: plantCodeId
            ))

            let a = Double(amount)
            let cc = Int(ccId)
            let pl = Int(plantCodeId)

            ccSums[cc]      += a
            ccSqSums[cc]    += a * a
            ccCounts[cc]    += 1
            plantSums[pl]   += a
            plantSqSums[pl] += a * a
            plantCounts[pl] += 1
        }

        // Compute baselines using Bessel's correction: variance = Σ(x-μ)² / (n-1)
        // Algebraically equivalent to: (Σx² - n·μ²) / (n-1)
        var ccBaselines = [Baseline]()
        for c in 0 ..< Config.costCentres.count {
            let n = Double(ccCounts[c])
            let mean = n > 0 ? ccSums[c] / n : 0
            let variance = n > 1 ? (ccSqSums[c] - n * mean * mean) / (n - 1) : 0
            ccBaselines.append(Baseline(mean: Float(mean), stdDev: Float(sqrt(max(variance, 0)))))
        }

        var plantBaselines = [Baseline]()
        for p in 0 ..< nPlants {
            let n = Double(plantCounts[p])
            let mean = n > 0 ? plantSums[p] / n : 0
            let variance = n > 1 ? (plantSqSums[p] - n * mean * mean) / (n - 1) : 0
            plantBaselines.append(Baseline(mean: Float(mean), stdDev: Float(sqrt(max(variance, 0)))))
        }

        return (transactions, ccBaselines, plantBaselines)
    }

    /// Generate synthetic ERP transactions in-memory.
    ///
    /// For each transaction: assigns a random cost centre, draws an amount from a
    /// Gaussian distribution (mean = cost centre base amount, stdDev = 15% of base),
    /// then assigns random transaction type, supplier ID, and plant code.
    ///
    /// After generation, injects anomalies into 0.2% of rows by multiplying their
    /// amount by one of [8×, 12×, -5×, 15×] — creating extreme outliers in both
    /// positive and negative directions.
    ///
    /// Baselines are computed from the *final* data (post-anomaly injection) to
    /// match how Python computes them on the full DataFrame.
    ///
    /// - Parameter rowCount: Number of transactions to generate (default: 10M).
    /// - Returns: `(transactions, costCentreBaselines, plantBaselines)`
    nonisolated static func generate(rowCount: Int = Config.numRows) -> ([Transaction], [Baseline], [Baseline]) {
        var rng = SeededRNG(seed: 42)

        let nCentres  = UInt32(Config.costCentres.count)
        let nTypes    = UInt32(Config.transactionTypes.count)
        let nPlants   = UInt32(Config.plantCodes.count)
        let nAnomalies = Int(Double(rowCount) * Config.anomalyRate)

        var transactions = [Transaction](repeating: Transaction(
            amount: 0, costCentreId: 0, txnTypeId: 0,
            supplierId: 0, plantCodeId: 0
        ), count: rowCount)

        for i in 0 ..< rowCount {
            let ccId   = UInt32.random(in: 0 ..< nCentres, using: &rng)
            let base   = baseAmounts[Int(ccId)]
            let std    = base * 0.15  // 15% of base amount as standard deviation
            let amount = Float(gaussianRandom(mean: Double(base), std: Double(std), rng: &rng))
            let plantId = UInt32.random(in: 0 ..< nPlants, using: &rng)

            transactions[i] = Transaction(
                amount:       amount,
                costCentreId: ccId,
                txnTypeId:    UInt32.random(in: 0 ..< nTypes, using: &rng),
                supplierId:   UInt32.random(in: 1000 ..< 9999, using: &rng),
                plantCodeId:  plantId
            )
        }

        // Inject anomalies: use a Set to avoid duplicate indices, then multiply
        // each selected transaction's amount by a random extreme multiplier.
        // Multipliers create outliers in both directions: [8×, 12×, 15×] positive,
        // [-5×] negative (sign reversal).
        let multipliers: [Float] = [8.0, 12.0, -5.0, 15.0]
        var anomalyIndices = Set<Int>()
        while anomalyIndices.count < nAnomalies {
            anomalyIndices.insert(Int.random(in: 0 ..< rowCount, using: &rng))
        }
        for idx in anomalyIndices {
            let mult = multipliers[Int.random(in: 0 ..< multipliers.count, using: &rng)]
            transactions[idx].amount *= mult
        }

        // Compute baselines empirically from final data (post-anomaly injection),
        // matching Python's compute_baselines() which runs on the full DataFrame.
        let (ccBaselines, plantBaselines) = computeBaselines(from: transactions, nCentres: Int(nCentres), nPlants: Int(nPlants))

        return (transactions, ccBaselines, plantBaselines)
    }

    /// Compute empirical mean and standard deviation baselines from transaction data.
    ///
    /// Uses a single-pass algorithm collecting Σx and Σx² per group, then derives
    /// variance as `(Σx² - n·μ²) / (n-1)` (Bessel's correction, ddof=1).
    ///
    /// Double accumulators prevent catastrophic cancellation when summing millions
    /// of Float amounts. Results are converted back to Float for Metal buffer compatibility.
    ///
    /// - Parameters:
    ///   - transactions: The full dataset to compute statistics from.
    ///   - nCentres: Number of cost centre groups (12).
    ///   - nPlants: Number of plant code groups (4).
    /// - Returns: `(costCentreBaselines, plantBaselines)` with one `Baseline` per group.
    private nonisolated static func computeBaselines(
        from transactions: [Transaction], nCentres: Int, nPlants: Int
    ) -> ([Baseline], [Baseline]) {
        var ccSums    = [Double](repeating: 0, count: nCentres)
        var ccSqSums  = [Double](repeating: 0, count: nCentres)
        var ccCounts  = [Int](repeating: 0, count: nCentres)
        var plantSums   = [Double](repeating: 0, count: nPlants)
        var plantSqSums = [Double](repeating: 0, count: nPlants)
        var plantCounts = [Int](repeating: 0, count: nPlants)

        for txn in transactions {
            let a  = Double(txn.amount)
            let cc = Int(txn.costCentreId)
            let pl = Int(txn.plantCodeId)

            ccSums[cc]      += a
            ccSqSums[cc]    += a * a
            ccCounts[cc]    += 1
            plantSums[pl]   += a
            plantSqSums[pl] += a * a
            plantCounts[pl] += 1
        }

        // Bessel's correction (ddof=1): divide by (n-1) instead of n.
        // This matches pandas .std() default and provides an unbiased estimator.
        var ccBaselines = [Baseline]()
        for c in 0 ..< nCentres {
            let n = Double(ccCounts[c])
            let mean = n > 0 ? ccSums[c] / n : 0
            let variance = n > 1 ? (ccSqSums[c] - n * mean * mean) / (n - 1) : 0
            ccBaselines.append(Baseline(mean: Float(mean), stdDev: Float(sqrt(max(variance, 0)))))
        }

        var plantBaselines = [Baseline]()
        for p in 0 ..< nPlants {
            let n = Double(plantCounts[p])
            let mean = n > 0 ? plantSums[p] / n : 0
            let variance = n > 1 ? (plantSqSums[p] - n * mean * mean) / (n - 1) : 0
            plantBaselines.append(Baseline(mean: Float(mean), stdDev: Float(sqrt(max(variance, 0)))))
        }

        return (ccBaselines, plantBaselines)
    }
}
