import SwiftUI

/// Dashboard tab — controls, speedup banner, engine comparison cards.
///
/// Particle field is provided by MainTabView (shared across tabs).
/// Pipeline, architecture, and stream views have moved to the Pipeline tab.
struct DashboardView: View {
    @Bindable var viewModel: BenchmarkViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Header (compact) ────────────────────────────────
                header
                    .padding(.bottom, 20)

                // ── Controls ─────────────────────────────────────────
                HStack(alignment: .center, spacing: 16) {
                    BenchmarkControlView(viewModel: viewModel)

                    if viewModel.isRunning {
                        ProgressRingView(
                            progress: viewModel.progress,
                            currentTask: viewModel.currentTask,
                            isRunning: viewModel.isRunning
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.5), value: viewModel.isRunning)
                .padding(.bottom, 16)

                // ── GPU Wave (slim, always visible) ─────────────────
                GPUWaveView(
                    isRunning: viewModel.isRunning,
                    progress: viewModel.progress
                )
                .padding(.bottom, 16)

                // ── SPEEDUP BANNER (hero position) ──────────────────
                if let speedup = viewModel.speedup {
                    SpeedupBannerView(speedup: speedup)
                        .padding(.bottom, 20)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }

                // ── Engine Results ───────────────────────────────────
                sectionLabel("Engine Results")

                HStack(alignment: .top, spacing: 2) {
                    EngineCardView(
                        type: .python,
                        result: viewModel.pythonResult,
                        otherResult: viewModel.gpuResult
                    )
                    EngineCardView(
                        type: .swift,
                        result: viewModel.gpuResult,
                        otherResult: viewModel.pythonResult,
                        isRunning: viewModel.isRunning
                    )
                }
                .padding(.bottom, 20)

                // ── Throughput Chart ─────────────────────────────────
                if viewModel.bothComplete {
                    sectionLabel("Throughput — Records per Second")

                    ThroughputChartView(
                        pythonResult: viewModel.pythonResult,
                        gpuResult: viewModel.gpuResult
                    )
                    .padding(.bottom, 20)
                    .transition(.opacity)
                }

                // ── Footer ───────────────────────────────────────────
                footer
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.opacity(0.01))
        .animation(.easeInOut(duration: 0.5), value: viewModel.bothComplete)
        .animation(.spring(duration: 0.6), value: viewModel.speedup != nil)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PYTHON")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.whiteText)
                    Text("VS SWIFT")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Color.swiftCyan)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    chipLabel("Python · Row-by-Row · CPU", color: .pythonAmber)
                    chipLabel("Swift · Metal · Apple Silicon GPU", color: .swiftCyan)
                }
            }

            // Gradient rule
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.kiraaAccent, .swiftCyan, .neonViolet, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .opacity(0.5)

            Text("10,000,000 ERP transactions · 5 aggregation tasks · group-by, ranking, z-score anomaly, pivot, running total")
                .font(.caption2)
                .foregroundStyle(Color.dimText)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func chipLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay {
                Rectangle()
                    .stroke(color, lineWidth: 1)
            }
            .background(color.opacity(0.07))
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.monoCaption)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Color.dimText)

            Rectangle()
                .fill(Color.border)
                .frame(height: 1)
        }
        .padding(.bottom, 10)
    }

    private var footer: some View {
        HStack {
            Text("Kiraa AI Pty Ltd · Gold Coast QLD · Benchmark v1.0")
                .font(.monoCaption)
                .foregroundStyle(Color.mutedText)

            Spacer()

            Text(viewModel.statusMessage)
                .font(.monoCaption)
                .foregroundStyle(Color.dimText)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.border)
                .frame(height: 1)
        }
    }
}
