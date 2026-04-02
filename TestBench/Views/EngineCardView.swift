import SwiftUI

/// Discriminates between the two benchmark engines for display purposes.
enum EngineType {
    case python  // Python CPU baseline (amber)
    case swift   // Swift + Metal GPU challenger (cyan)

    var label: String {
        switch self {
        case .python: "Baseline · CPU"
        case .swift:  "Challenger · GPU"
        }
    }

    var title: String {
        switch self {
        case .python: "Python\nRow Loop"
        case .swift:  "Swift\nMetal GPU"
        }
    }

    var accent: Color {
        switch self {
        case .python: .pythonAmber
        case .swift:  .swiftCyan
        }
    }
}

/// Displays benchmark results for a single engine with per-task timing bars.
///
/// Shows machine metadata, total time, throughput, and a breakdown of each
/// benchmark task with comparative bar charts against the other engine.
struct EngineCardView: View {
    let type: EngineType
    let result: BenchmarkResult?
    let otherResult: BenchmarkResult?
    var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text(type.label)
                .font(.monoCaption)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(type.accent)

            Text(type.title)
                .font(.displayMed)
                .foregroundStyle(Color.whiteText)

            // Machine info
            if let r = result {
                VStack(alignment: .leading, spacing: 2) {
                    if let cpu = r.cpuModel {
                        Text(cpu).font(.monoCaption).foregroundStyle(Color.dimText)
                    }
                    if let ts = r.timestamp {
                        Text(String(ts.prefix(19)).replacingOccurrences(of: "T", with: " "))
                            .font(.monoCaption).foregroundStyle(Color.mutedText)
                    }
                    if let device = r.device {
                        Text(device).font(.monoCaption).foregroundStyle(Color.dimText)
                    }
                }
            }

            // Summary stats
            if let r = result {
                HStack(spacing: 16) {
                    miniStat("Total", formatMs(r.totalTimeMs), highlight: true)
                    miniStat("Throughput", formatRps(r.throughputRps), highlight: true)
                }
            }

            // Per-task timings
            if let tasks = result?.tasks {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            } else if isRunning {
                ProgressView()
                    .tint(type.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                Text("Tap Run Benchmark")
                    .font(.monoCaption)
                    .foregroundStyle(Color.mutedText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
        }
        .padding(20)
        .background(Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(type.accent).frame(height: 3)
        }
    }

    @ViewBuilder
    private func taskRow(_ task: TaskResult) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(task.name)
                    .font(.monoCaption)
                    .foregroundStyle(Color.dimText)
                    .lineLimit(1)
                Spacer()
                Text(formatMs(task.timeMs))
                    .font(.monoSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(type.accent)
            }
            HStack {
                Text(task.summary)
                    .font(.monoCaption)
                    .foregroundStyle(Color.mutedText)
                Spacer()
                // Bar comparing to other engine's same task
                if let otherTime = otherResult?.tasks.first(where: { $0.name == task.name })?.timeMs,
                   otherTime > 0 {
                    let maxTime = max(task.timeMs, otherTime)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.border).frame(height: 2)
                            Rectangle().fill(type.accent)
                                .frame(width: geo.size.width * task.timeMs / maxTime, height: 2)
                                .animation(.spring(duration: 1.0), value: task.timeMs)
                        }
                    }
                    .frame(width: 60, height: 2)
                }
            }
        }
    }

    private func miniStat(_ label: String, _ value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.monoCaption).foregroundStyle(Color.dimText)
            Text(value).font(.monoSmall).fontWeight(.bold)
                .foregroundStyle(highlight ? type.accent : Color.bodyText)
        }
    }

    /// Adaptive time formatting: ≥1s → "X.Xs", ≥1ms → "X.X ms", <1ms → "X.XXX ms".
    private func formatMs(_ ms: Double) -> String {
        if ms >= 1000 { return String(format: "%.1fs", ms / 1000) }
        if ms >= 1 { return String(format: "%.1f ms", ms) }
        return String(format: "%.3f ms", ms)
    }

    /// Adaptive throughput formatting: ≥1M → "X.XM r/s", ≥1K → "XK r/s", else raw.
    private func formatRps(_ rps: Double) -> String {
        if rps >= 1_000_000 { return String(format: "%.1fM r/s", rps / 1_000_000) }
        if rps >= 1_000 { return String(format: "%.0fK r/s", rps / 1_000) }
        return "\(Int(rps)) r/s"
    }
}
