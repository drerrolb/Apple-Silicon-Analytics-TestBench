// DataGenerator.swift
// Kiraa AI — Synthetic ERP Data Generation
//
// Mirrors the Python benchmark's data generation exactly:
// same cost centres, same transaction types, same anomaly injection rate.
// Uses Swift's SystemRandomNumberGenerator for speed.

import Foundation

// ── Constants ─────────────────────────────────────────────────────────────────

enum Config {
    static let numRows        = 10_000_000
    static let streamingBatch = 1_000
    static let anomalyRate    = 0.002
    static let zThreshold     = Float(3.5)

    static let costCentres: [String] = [
        "RAW_MATERIALS", "PACKAGING",    "LOGISTICS",   "LABOUR",
        "OVERHEADS",     "CAPEX",        "MAINTENANCE", "UTILITIES",
        "PROCUREMENT",   "SALES",        "MARKETING",   "ADMIN"
    ]

    static let transactionTypes: [String] = [
        "PURCHASE_ORDER", "INVOICE_MATCH", "VARIANCE_FLAG",
        "ACCRUAL",        "PAYMENT_RUN",   "INTERCOMPANY",  "CREDIT_NOTE"
    ]

    static let plantCodes: [String] = [
        "GOLD_COAST", "SYDNEY", "MELBOURNE", "BRISBANE"
    ]
}

// ── GPU-layout Transaction (matches Metal struct exactly) ─────────────────────

struct Transaction {
    var amount:         Float
    var costCentreId:   UInt32
    var txnTypeId:      UInt32
    var supplierId:     UInt32
    var plantCodeId:    UInt32
    var _pad:           Float = 0   // align to 24 bytes
}

struct Baseline {
    var mean:   Float
    var stdDev: Float
}

struct ScoredResult {
    var zScore:    Float
    var isAnomaly: UInt32
}

// ── Data Generator ────────────────────────────────────────────────────────────

struct DataGenerator {

    // Per-cost-centre base amounts (matches Python's uniform(5000, 500000))
    static let baseAmounts: [Float] = {
        // Seeded deterministically so Python and Swift datasets are comparable
        var rng = SeededRNG(seed: 42)
        return (0 ..< Config.costCentres.count).map { _ in
            Float.random(in: 5_000 ... 500_000, using: &rng)
        }
    }()

    static func generate() -> ([Transaction], [Baseline]) {
        var rng = SeededRNG(seed: 42)

        // Compute baselines first (mean = baseAmount, std = baseAmount * 0.15)
        let baselines: [Baseline] = baseAmounts.map { base in
            Baseline(mean: base, stdDev: base * 0.15)
        }

        let nRows     = Config.numRows
        let nCentres  = UInt32(Config.costCentres.count)
        let nTypes    = UInt32(Config.transactionTypes.count)
        let nPlants   = UInt32(Config.plantCodes.count)
        let nAnomalies = Int(Double(nRows) * Config.anomalyRate)

        // Generate all transactions
        var transactions = [Transaction](repeating: Transaction(
            amount: 0, costCentreId: 0, txnTypeId: 0,
            supplierId: 0, plantCodeId: 0
        ), count: nRows)

        for i in 0 ..< nRows {
            let ccId    = UInt32.random(in: 0 ..< nCentres,  using: &rng)
            let base    = baseAmounts[Int(ccId)]
            let std     = base * 0.15
            let amount  = Float(gaussianRandom(mean: Double(base), std: Double(std), rng: &rng))

            transactions[i] = Transaction(
                amount:       amount,
                costCentreId: ccId,
                txnTypeId:    UInt32.random(in: 0 ..< nTypes,  using: &rng),
                supplierId:   UInt32.random(in: 1000 ..< 9999, using: &rng),
                plantCodeId:  UInt32.random(in: 0 ..< nPlants, using: &rng)
            )
        }

        // Inject anomalies (same multipliers as Python: 8, 12, -5, 15)
        let multipliers: [Float] = [8.0, 12.0, -5.0, 15.0]
        var anomalyIndices = Set<Int>()
        while anomalyIndices.count < nAnomalies {
            anomalyIndices.insert(Int.random(in: 0 ..< nRows, using: &rng))
        }
        for idx in anomalyIndices {
            let mult = multipliers[Int.random(in: 0 ..< multipliers.count, using: &rng)]
            transactions[idx].amount *= mult
        }

        return (transactions, baselines)
    }
}

// ── Seeded RNG (LCG, fast, deterministic) ────────────────────────────────────

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        // Splitmix64
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// Box-Muller transform for normally distributed amounts
func gaussianRandom(mean: Double, std: Double, rng: inout SeededRNG) -> Double {
    let u1 = Double(rng.next()) / Double(UInt64.max)
    let u2 = Double(rng.next()) / Double(UInt64.max)
    let z0 = sqrt(-2.0 * log(max(u1, 1e-10))) * cos(2.0 * .pi * u2)
    return mean + std * z0
}
