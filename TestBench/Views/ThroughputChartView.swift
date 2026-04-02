import SwiftUI

/// Head-to-head horizontal bar chart comparing records-per-second throughput.
struct ThroughputChartView: View {
    let pythonResult: BenchmarkResult?
    let gpuResult: BenchmarkResult?

    private var maxThroughput: Double {
        max(pythonResult?.throughputRps ?? 0, gpuResult?.throughputRps ?? 0)
    }

    var body: some View {
        VStack(spacing: 18) {
            barRow(label: "Python\nRow Loop", value: pythonResult?.throughputRps, accent: .pythonAmber)
            barRow(label: "Swift\nMetal GPU", value: gpuResult?.throughputRps, accent: .swiftCyan)
        }
    }

    @ViewBuilder
    private func barRow(label: String, value: Double?, accent: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.monoCaption)
                .foregroundStyle(Color.dimText)
                .frame(width: 70, alignment: .trailing)
                .multilineTextAlignment(.trailing)

            GeometryReader { geo in
                let pct = value.map { maxThroughput > 0 ? $0 / maxThroughput : 0 } ?? 0
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.border)
                    Rectangle().fill(accent)
                        .frame(width: geo.size.width * pct)
                        .animation(.spring(duration: 1.2), value: pct)
                        .overlay(alignment: .leading) {
                            if let v = value {
                                Text(formatRps(v))
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.appBackground)
                                    .padding(.leading, 8)
                            }
                        }
                }
            }
            .frame(height: 28)

            Text(value.map { formatRps($0) } ?? "—")
                .font(.monoCaption)
                .foregroundStyle(Color.bodyText)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func formatRps(_ rps: Double) -> String {
        if rps >= 1_000_000 { return String(format: "%.1fM r/s", rps / 1_000_000) }
        if rps >= 1_000 { return String(format: "%.0fK r/s", rps / 1_000) }
        return "\(Int(rps)) r/s"
    }
}
