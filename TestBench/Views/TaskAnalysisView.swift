import SwiftUI
import Charts

/// Tab 2: Per-task timing comparison charts.
///
/// Shows grouped bar chart comparing Python vs GPU per task,
/// a donut chart of time distribution, and per-task speedup bars.
struct TaskAnalysisView: View {
    @Bindable var viewModel: BenchmarkViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tabHeader("Task Analysis")

                if viewModel.bothComplete {
                    timingComparisonChart
                    speedupPerTaskChart
                    timeDistributionChart
                } else {
                    emptyState("Run the benchmark to see task analysis")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.opacity(0.01))
    }

    // MARK: - Timing Comparison (Grouped Bar)

    private var timingComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Task Timing Comparison")
            chartSubtitle("Python (CPU) vs Swift+Metal (GPU) — log scale")

            Chart(taskComparisons) { item in
                BarMark(
                    x: .value("Task", shortName(item.task)),
                    y: .value("Time (ms)", max(item.timeMs, 0.01))
                )
                .foregroundStyle(item.engine == "Python" ? Color.pythonAmber : Color.swiftCyan)
                .position(by: .value("Engine", item.engine))
                .cornerRadius(3)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let ms = value.as(Double.self) {
                            Text(formatMs(ms))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.dimText)
                }
            }
            .chartLegend(position: .top, alignment: .trailing)
            .frame(height: 280)
            .chartBackground { _ in Color.clear }
        }
        .chartCard()
    }

    // MARK: - Speedup Per Task (Horizontal Bars)

    private var speedupPerTaskChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("Speedup per Task")
            chartSubtitle("Python time / GPU time")

            if let py = viewModel.pythonResult, let gpu = viewModel.gpuResult {
                let speedups = taskSpeedups(py: py, gpu: gpu)

                Chart(speedups, id: \.task) { item in
                    BarMark(
                        x: .value("Speedup", item.speedup),
                        y: .value("Task", item.task)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.swiftCyan, .kiraaAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                    .annotation(position: .trailing, spacing: 8) {
                        Text(String(format: "%.0f×", item.speedup))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.kiraaAccent)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))×")
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
                .frame(height: 220)
            }
        }
        .chartCard()
    }

    // MARK: - Time Distribution (Donut)

    private var timeDistributionChart: some View {
        HStack(alignment: .top, spacing: 2) {
            donutChart(title: "Python", result: viewModel.pythonResult, accent: .pythonAmber)
            donutChart(title: "GPU", result: viewModel.gpuResult, accent: .swiftCyan)
        }
    }

    private func donutChart(title: String, result: BenchmarkResult?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            chartTitle("\(title) Time Split")

            if let tasks = result?.tasks, let total = result?.totalTimeMs, total > 0 {
                Chart(tasks) { task in
                    SectorMark(
                        angle: .value("Time", task.timeMs),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(taskColor(task.name, accent: accent))
                    .cornerRadius(3)
                }
                .frame(height: 180)

                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tasks) { task in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(taskColor(task.name, accent: accent))
                                .frame(width: 6, height: 6)
                            Text(shortName(task.name))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.dimText)
                            Spacer()
                            Text(String(format: "%.1f%%", task.timeMs / total * 100))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Color.bodyText)
                        }
                    }
                }
            }
        }
        .chartCard()
    }

    // MARK: - Data Helpers

    private var taskComparisons: [TaskComparison] {
        var items = [TaskComparison]()
        if let py = viewModel.pythonResult {
            for task in py.tasks {
                items.append(TaskComparison(task: task.name, engine: "Python", timeMs: task.timeMs))
            }
        }
        if let gpu = viewModel.gpuResult {
            for task in gpu.tasks {
                items.append(TaskComparison(task: task.name, engine: "GPU", timeMs: task.timeMs))
            }
        }
        return items
    }

    private struct TaskSpeedup {
        let task: String
        let speedup: Double
    }

    private func taskSpeedups(py: BenchmarkResult, gpu: BenchmarkResult) -> [TaskSpeedup] {
        py.tasks.compactMap { pyTask in
            guard let gpuTask = gpu.tasks.first(where: { $0.name == pyTask.name }),
                  gpuTask.timeMs > 0 else { return nil }
            return TaskSpeedup(task: shortName(pyTask.name), speedup: pyTask.timeMs / gpuTask.timeMs)
        }
    }

    // MARK: - Styling Helpers

    private func shortName(_ name: String) -> String {
        switch name {
        case "Total by cost centre":     return "Cost Centre"
        case "Top 10 suppliers":         return "Top Suppliers"
        case "Z-score anomaly detection": return "Anomaly"
        case "Plant × cost centre pivot": return "Pivot"
        case "Running total":            return "Running Total"
        default:
            if let bySpend = name.range(of: " by spend") {
                return String(name[..<bySpend.lowerBound])
            }
            return name
        }
    }

    private func taskColor(_ name: String, accent: Color) -> Color {
        let names = ["Total by cost centre", "Top 10 suppliers", "Z-score anomaly detection",
                     "Plant × cost centre pivot", "Running total",
                     "Top 10 suppliers by spend"]
        let colors: [Color] = [.swiftCyan, .kiraaAccent, .danger, .neonViolet, .pythonAmber, .kiraaAccent]
        if let idx = names.firstIndex(of: name), idx < colors.count {
            return colors[idx]
        }
        return accent
    }

    private func formatMs(_ ms: Double) -> String {
        if ms >= 1000 { return String(format: "%.0fs", ms / 1000) }
        if ms >= 1 { return String(format: "%.0f ms", ms) }
        return String(format: "%.2f ms", ms)
    }
}

// MARK: - Shared Chart Styling

extension View {
    func chartCard() -> some View {
        self
            .padding(20)
            .background(Color.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.border, lineWidth: 1)
            }
    }
}

// Shared chart helpers are in ChartHelpers.swift
