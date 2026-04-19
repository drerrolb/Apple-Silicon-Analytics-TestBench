import SwiftUI

/// Tab 5: Detailed explanation of each benchmark task, why Swift+Metal wins,
/// and side-by-side comparison of how each engine approaches the workload.
struct DeepDiveView: View {
    @Bindable var viewModel: BenchmarkViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass == .compact }

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 24) {
                tabHeader("Deep Dive")

                introSection

                taskCard(
                    number: 1,
                    name: "Total by Cost Centre",
                    what: "Group 10M transactions by cost centre ID (12 groups) and sum the amounts.",
                    pythonApproach: "Python iterates each row with df.iterrows(), creating a pandas Series object per row. Each row does a dict lookup and float addition through the interpreter's eval loop.",
                    swiftApproach: "Swift compiles to a tight ARM64 loop: one array index + one Double addition per iteration. No object allocation, no interpreter overhead, no dynamic dispatch.",
                    whyFaster: "Compiled native loop vs interpreted bytecode. No per-row object creation. Direct memory access vs pandas Series wrapper.",
                    icon: "list.bullet.rectangle",
                    accent: .swiftCyan
                )

                taskCard(
                    number: 2,
                    name: "Top 10 Suppliers",
                    what: "Group by supplier ID (~9,000 unique), sum amounts, sort descending, take top 10.",
                    pythonApproach: "df.iterrows() again — each row creates a Series, extracts supplier_id via string key lookup, accumulates in a Python dict. Then sorted() on all items.",
                    swiftApproach: "Hash map accumulation with UInt32 keys (no string hashing). Native sort on ~9K entries. The entire operation is a compiled tight loop.",
                    whyFaster: "UInt32 key hashing is 5-10× faster than Python string-keyed dict. Compiled sort vs interpreted sort. No per-row Series allocation.",
                    icon: "trophy",
                    accent: .swiftCyan
                )

                taskCard(
                    number: 3,
                    name: "Z-Score Anomaly Detection",
                    what: "For each of 10M rows: look up the cost centre baseline (mean, stdDev), compute z = (amount - mean) / stdDev, flag if |z| > 3.5.",
                    pythonApproach: "Per-row interpreter loop: dict lookup for baseline, two float subtractions, one division, one abs(), one comparison. Each operation goes through Python's dynamic dispatch.",
                    swiftApproach: "Metal GPU kernel: 1,000 transactions per dispatch, each scored by a parallel GPU thread. On Apple Silicon, thousands of threads execute simultaneously with zero-copy shared memory.",
                    whyFaster: "Massive parallelism: GPU scores 1,000 transactions simultaneously vs Python's one-at-a-time serial loop. On Apple Silicon, the GPU has dedicated compute units optimised for this exact pattern.",
                    icon: "exclamationmark.triangle",
                    accent: .kiraaAccent
                )

                taskCard(
                    number: 4,
                    name: "Plant × Cost Centre Pivot",
                    what: "Cross-tabulate 4 plants × 12 cost centres = 48 cells, summing transaction amounts.",
                    pythonApproach: "df.iterrows() with tuple-key dict: (plant, cost_centre) → sum. Each row creates a Series, extracts two fields, builds a tuple key, does a dict get/set.",
                    swiftApproach: "Flat array indexed by plantId × 12 + centreId. One multiply, one add, one array index per row. No hashing, no tuple allocation, no dict overhead.",
                    whyFaster: "Array index (O(1) with no hashing) vs dict with tuple keys. No per-row object allocation. Compiled arithmetic vs interpreted bytecode.",
                    icon: "tablecells",
                    accent: .swiftCyan
                )

                taskCard(
                    number: 5,
                    name: "Running Total",
                    what: "Cumulative sum: iterate all 10M amounts and accumulate into a single total.",
                    pythonApproach: "df.iterrows() loop with running += row['amount']. Each iteration: create Series, extract field by string key, Python float addition through eval loop.",
                    swiftApproach: "Single compiled loop: one Double addition per iteration. The compiler can vectorise this with SIMD instructions on Apple Silicon.",
                    whyFaster: "The simplest possible loop — but Python pays ~100× overhead per iteration due to Series creation, string key lookup, and interpreter dispatch. Swift compiles to ~2 instructions per row.",
                    icon: "sum",
                    accent: .swiftCyan
                )

                overallSection

                if viewModel.bothComplete {
                    comparisonTable
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.opacity(0.01))
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Five identical tasks. Same data. Two engines.")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Color.whiteText)

            Text("Each task processes all 10,000,000 ERP transactions. Python uses row-by-row for-loops (the common pandas df.iterrows() pattern). Swift uses compiled native code with Metal GPU acceleration for the compute-intensive anomaly detection.")
                .font(.monoCaption)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                legendDot(color: .pythonAmber, label: "Python / pandas iterrows()")
                legendDot(color: .swiftCyan, label: "Swift + Metal GPU")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
    }

    // MARK: - Task Card

    private func taskCard(
        number: Int,
        name: String,
        what: String,
        pythonApproach: String,
        swiftApproach: String,
        whyFaster: String,
        icon: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TASK \(number)")
                        .font(.monoCaption)
                        .tracking(2)
                        .foregroundStyle(accent)
                    Text(name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.whiteText)
                }

                Spacer()

                // Show speedup if results available
                if let speedup = taskSpeedup(index: number - 1) {
                    Text(String(format: "%.0f×", speedup))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                }
            }

            // What it does
            Text(what)
                .font(.monoCaption)
                .foregroundStyle(Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)

            // Side-by-side approaches (stack on iPhone)
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 8) {
                        approachBox(
                            engine: "Python",
                            text: pythonApproach,
                            accent: .pythonAmber,
                            time: pythonTaskTime(index: number - 1)
                        )

                        approachBox(
                            engine: "Swift+Metal",
                            text: swiftApproach,
                            accent: .swiftCyan,
                            time: swiftTaskTime(index: number - 1)
                        )
                    }
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        approachBox(
                            engine: "Python",
                            text: pythonApproach,
                            accent: .pythonAmber,
                            time: pythonTaskTime(index: number - 1)
                        )

                        approachBox(
                            engine: "Swift+Metal",
                            text: swiftApproach,
                            accent: .swiftCyan,
                            time: swiftTaskTime(index: number - 1)
                        )
                    }
                }
            }

            // Why faster
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(Color.kiraaAccent)
                Text(whyFaster)
                    .font(.monoCaption)
                    .foregroundStyle(Color.dimText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.surface)
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
    }

    private func approachBox(engine: String, text: String, accent: Color, time: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(engine)
                    .font(.monoCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
                Spacer()
                if let time {
                    Text(time)
                        .font(.monoCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(accent)
                }
            }

            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.dimText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(accent.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        }
    }

    // MARK: - Overall Section

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Why Swift + Metal Wins")

            VStack(alignment: .leading, spacing: 10) {
                bulletPoint(
                    title: "Compiled vs Interpreted",
                    text: "Swift compiles to native ARM64 machine code. Python interprets bytecode through an eval loop with dynamic type checks on every operation."
                )
                bulletPoint(
                    title: "Zero Object Allocation",
                    text: "Swift iterates structs in contiguous memory. Python's iterrows() creates a new Series object per row — 10M temporary objects for 10M rows."
                )
                bulletPoint(
                    title: "GPU Parallelism",
                    text: "Metal dispatches 1,000+ threads simultaneously for z-score scoring. Python processes one transaction at a time through the GIL."
                )
                bulletPoint(
                    title: "Memory Efficiency",
                    text: "Swift uses 24-byte packed structs with shared-mode Metal buffers (zero-copy on Apple Silicon). Python DataFrames store each column as a separate numpy array with object overhead."
                )
                bulletPoint(
                    title: "Static Dispatch",
                    text: "Swift resolves all method calls at compile time. Python looks up every attribute, method, and operator at runtime through __getattr__ and descriptor protocols."
                )
            }
        }
        .padding(16)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
    }

    private func bulletPoint(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.monoCaption)
                .fontWeight(.bold)
                .foregroundStyle(Color.swiftCyan)
            Text(text)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.dimText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Head-to-Head")

            if let py = viewModel.pythonResult, let gpu = viewModel.gpuResult {
                VStack(spacing: 0) {
                    tableRow(label: "Engine", python: py.engine, swift: gpu.engine, isHeader: true)
                    tableRow(label: "Total Time", python: formatMs(py.totalTimeMs), swift: formatMs(gpu.totalTimeMs))
                    tableRow(label: "Throughput", python: formatRps(py.throughputRps), swift: formatRps(gpu.throughputRps))
                    tableRow(label: "Records", python: formatRows(py.totalRecords), swift: formatRows(gpu.totalRecords))

                    ForEach(0..<min(py.tasks.count, gpu.tasks.count), id: \.self) { i in
                        tableRow(
                            label: py.tasks[i].name,
                            python: formatMs(py.tasks[i].timeMs),
                            swift: formatMs(gpu.tasks[i].timeMs)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
    }

    private func tableRow(label: String, python: String, swift: String, isHeader: Bool = false) -> some View {
        let valueWidth: CGFloat = isCompact ? 60 : 80
        return HStack(spacing: 6) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(isHeader ? .bold : .regular)
                .foregroundStyle(isHeader ? Color.whiteText : Color.dimText)
                .lineLimit(isCompact ? 2 : 1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(python)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(isHeader ? .bold : .regular)
                .foregroundStyle(Color.pythonAmber)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: valueWidth, alignment: .trailing)

            Text(swift)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(isHeader ? .bold : .regular)
                .foregroundStyle(Color.swiftCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: valueWidth, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHeader ? Color.border.opacity(0.3) : Color.clear)
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.dimText)
        }
    }

    private func taskSpeedup(index: Int) -> Double? {
        guard let py = viewModel.pythonResult, let gpu = viewModel.gpuResult,
              index < py.tasks.count, index < gpu.tasks.count,
              gpu.tasks[index].timeMs > 0 else { return nil }
        return py.tasks[index].timeMs / gpu.tasks[index].timeMs
    }

    private func pythonTaskTime(index: Int) -> String? {
        guard let py = viewModel.pythonResult, index < py.tasks.count else { return nil }
        return formatMs(py.tasks[index].timeMs)
    }

    private func swiftTaskTime(index: Int) -> String? {
        guard let gpu = viewModel.gpuResult, index < gpu.tasks.count else { return nil }
        return formatMs(gpu.tasks[index].timeMs)
    }

    private func formatMs(_ ms: Double) -> String {
        if ms >= 1000 { return String(format: "%.1fs", ms / 1000) }
        if ms >= 1 { return String(format: "%.1f ms", ms) }
        return String(format: "%.3f ms", ms)
    }

    private func formatRps(_ rps: Double) -> String {
        if rps >= 1_000_000 { return String(format: "%.1fM r/s", rps / 1_000_000) }
        if rps >= 1_000 { return String(format: "%.0fK r/s", rps / 1_000) }
        return "\(Int(rps)) r/s"
    }

    private func formatRows(_ count: Int) -> String {
        if count >= 1_000_000 { return "\(count / 1_000_000)M" }
        if count >= 1_000 { return "\(count / 1_000)K" }
        return "\(count)"
    }
}
