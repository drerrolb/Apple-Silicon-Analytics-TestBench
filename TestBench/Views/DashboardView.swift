import SwiftUI

/// Dashboard tab — controls, speedup banner, engine comparison cards.
///
/// Particle field is provided by MainTabView (shared across tabs).
/// Pipeline, architecture, and stream views have moved to the Pipeline tab.
struct DashboardView: View {
    @Bindable var viewModel: BenchmarkViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass == .compact }

    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(spacing: 0) {

                // ── Header (compact) ────────────────────────────────
                header
                    .padding(.bottom, 20)

                // ── Controls ─────────────────────────────────────────
                Group {
                    if isCompact {
                        VStack(alignment: .center, spacing: 16) {
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
                    } else {
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

                Group {
                    if isCompact {
                        VStack(spacing: 12) {
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
                    } else {
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
                    }
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

                // ── Validation Info ──────────────────────────────────
                validationInfo
                    .padding(.bottom, 20)

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
            if isCompact {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("PYTHON")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color.whiteText)
                            Text("VS SWIFT")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Color.swiftCyan)
                        }

                        Spacer()

                        KiraaLogoMark(size: 40)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        chipLabel("Python · Row-by-Row · CPU", color: .pythonAmber)
                        chipLabel("Swift · Metal · Apple Silicon GPU", color: .swiftCyan)
                    }
                }
            } else {
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

                    KiraaLogoMark(size: 48)
                        .padding(.leading, 12)
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

    private var validationInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Validate Locally")

            VStack(alignment: .leading, spacing: 8) {
                Text("Run the Python benchmark on your Mac to verify results independently:")
                    .font(.monoCaption)
                    .foregroundStyle(Color.bodyText)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Clone the repository")
                        .font(.monoCaption)
                        .foregroundStyle(Color.dimText)
                    Text("git clone https://github.com/drerrolb/Apple-Silicon-Analytics-TestBench.git")
                        .font(.monoCaption)
                        .foregroundStyle(Color.pythonAmber)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("2. Install dependencies")
                        .font(.monoCaption)
                        .foregroundStyle(Color.dimText)
                    Text("pip install pandas numpy tqdm")
                        .font(.monoCaption)
                        .foregroundStyle(Color.pythonAmber)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("3. Run the benchmark")
                        .font(.monoCaption)
                        .foregroundStyle(Color.dimText)
                    Text("python3 benchmark_python.py")
                        .font(.monoCaption)
                        .foregroundStyle(Color.pythonAmber)
                        .textSelection(.enabled)
                }

                Text("Results are saved to benchmark_results_python.json and can be compared with the values shown above.")
                    .font(.monoCaption)
                    .foregroundStyle(Color.mutedText)
                    .padding(.top, 4)

                Link(destination: URL(string: "https://github.com/drerrolb/Apple-Silicon-Analytics-TestBench/blob/main/benchmark_python.py")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                        Text("View benchmark_python.py on GitHub")
                    }
                    .font(.monoCaption)
                    .foregroundStyle(Color.swiftCyan)
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
    }

    private var footer: some View {
        HStack {
            Text("Kiraa AI Pty Ltd · Gold Coast QLD · Benchmark v1.03")
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
