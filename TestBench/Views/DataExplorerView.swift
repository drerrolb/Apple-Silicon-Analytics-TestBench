import SwiftUI
import Charts

/// Tab 3: Interactive data exploration with Swift Charts.
///
/// Visualises the actual transaction data computed during the GPU benchmark:
/// cost centre totals, top suppliers, anomaly stats, plant distribution,
/// and baseline comparisons.
struct DataExplorerView: View {
    @Bindable var viewModel: BenchmarkViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass == .compact }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tabHeader("Data Explorer")

                if let data = viewModel.gpuData {
                    costCentreChart(data: data)
                    topSuppliersChart(data: data)
                    plantDistributionChart(data: data)
                    baselineChart(data: data)
                    summaryStats(data: data)
                } else {
                    emptyState("Run the benchmark to explore transaction data")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.opacity(0.01))
    }

    // MARK: - Cost Centre Totals (Vertical Bar)

    private func costCentreChart(data: BenchmarkData) -> some View {
        let sorted = data.costCentreTotals.sorted { $0.total > $1.total }

        return VStack(alignment: .leading, spacing: 12) {
            chartTitle("Spend by Cost Centre")
            chartSubtitle("\(sorted.count) departments — sorted by total spend")

            Chart(sorted) { item in
                BarMark(
                    x: .value("Centre", abbreviate(item.name)),
                    y: .value("Total ($)", item.total)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.swiftCyan.opacity(0.6), .kiraaAccent],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatDollar(v))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.dimText)
                }
            }
            .frame(height: 260)
        }
        .chartCard()
    }

    // MARK: - Top 10 Suppliers (Horizontal Bar)

    private func topSuppliersChart(data: BenchmarkData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Top 10 Suppliers")
            chartSubtitle("Ranked by total spend")

            Chart(data.topSuppliers) { supplier in
                BarMark(
                    x: .value("Spend", supplier.total),
                    y: .value("Supplier", "#\(supplier.rank) · \(supplier.supplierId)")
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.neonViolet, .kiraaAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 8) {
                    Text(formatDollar(supplier.total))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.bodyText)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatDollar(v))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.dimText)
                }
            }
            .frame(height: isCompact ? 260 : 320)
        }
        .chartCard()
    }

    // MARK: - Plant Distribution (Donut)

    private func plantDistributionChart(data: BenchmarkData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Spend by Plant Location")
            chartSubtitle("4 Australian plants")

            let donutChart = Chart(data.plantTotals) { plant in
                SectorMark(
                    angle: .value("Total", plant.total),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(plantColor(plant.name))
                .cornerRadius(4)
            }
            .frame(width: isCompact ? 150 : 180, height: isCompact ? 150 : 180)

            let legend = VStack(alignment: .leading, spacing: 8) {
                let grandTotal = data.plantTotals.reduce(0) { $0 + $1.total }
                ForEach(data.plantTotals) { plant in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(plantColor(plant.name))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(plant.name)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                                .foregroundStyle(Color.bodyText)
                            Text(String(format: "%.1f%%", plant.total / grandTotal * 100))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                        }
                    }
                }
            }

            if isCompact {
                VStack(spacing: 16) {
                    donutChart
                        .frame(maxWidth: .infinity)
                    legend
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 24) {
                    donutChart
                    legend
                    Spacer()
                }
            }
        }
        .chartCard()
    }

    // MARK: - Baseline Comparison (Mean ± Std)

    private func baselineChart(data: BenchmarkData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Cost Centre Baselines")
            chartSubtitle("Mean amount ± standard deviation (used for z-score)")

            Chart(data.baselines) { bl in
                // Mean bar
                BarMark(
                    x: .value("Centre", abbreviate(bl.name)),
                    y: .value("Mean", Double(bl.mean))
                )
                .foregroundStyle(Color.swiftCyan.opacity(0.5))
                .cornerRadius(3)

                // Error bars: mean ± stdDev
                RuleMark(
                    x: .value("Centre", abbreviate(bl.name)),
                    yStart: .value("Low", Double(bl.mean - bl.stdDev)),
                    yEnd: .value("High", Double(bl.mean + bl.stdDev))
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.kiraaAccent)

                // Mean point
                PointMark(
                    x: .value("Centre", abbreviate(bl.name)),
                    y: .value("Mean", Double(bl.mean))
                )
                .symbolSize(20)
                .foregroundStyle(Color.whiteText)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatDollar(v))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.dimText)
                }
            }
            .frame(height: 260)
        }
        .chartCard()
    }

    // MARK: - Summary Stats

    private func summaryStats(data: BenchmarkData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Data Summary")

            let stats: [(String, String)] = [
                ("Running Total", String(format: "$%,.2f", data.runningTotal)),
                ("Anomalies Detected", "\(data.anomalyCount.formatted())"),
                ("Anomaly Rate", String(format: "%.4f%%", Double(data.anomalyCount) / Double(viewModel.gpuResult?.totalRecords ?? 1) * 100)),
                ("Cost Centres", "\(data.costCentreTotals.count)"),
                ("Plant Locations", "\(data.plantTotals.count)"),
                ("Pivot Cells", "\(data.pivotValues.count)"),
            ]

            let gridColumns: [GridItem] = isCompact
                ? [GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(stats, id: \.0) { label, value in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.dimText)
                        Text(value)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.kiraaAccent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .chartCard()
    }

    // MARK: - Helpers

    private func abbreviate(_ name: String) -> String {
        switch name {
        case "RAW_MATERIALS": return "RAW"
        case "PACKAGING":     return "PACK"
        case "LOGISTICS":     return "LOG"
        case "LABOUR":        return "LAB"
        case "OVERHEADS":     return "OVER"
        case "CAPEX":         return "CAP"
        case "MAINTENANCE":   return "MAINT"
        case "UTILITIES":     return "UTIL"
        case "PROCUREMENT":   return "PROC"
        case "SALES":         return "SALES"
        case "MARKETING":     return "MKT"
        case "ADMIN":         return "ADMIN"
        default:              return String(name.prefix(4))
        }
    }

    private func plantColor(_ name: String) -> Color {
        switch name {
        case "GOLD_COAST": return .kiraaAccent
        case "SYDNEY":     return .swiftCyan
        case "MELBOURNE":  return .neonViolet
        case "BRISBANE":   return .pythonAmber
        default:           return .dimText
        }
    }

    private func formatDollar(_ value: Double) -> String {
        if abs(value) >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        } else if abs(value) >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if abs(value) >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}
