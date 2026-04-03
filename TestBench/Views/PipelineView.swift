import SwiftUI

/// Tab 4: GPU processing pipeline visualisation.
///
/// Relocates the DataFlowView, ArchitectureGridView, and StreamVisualizerView
/// from the main dashboard into their own dedicated tab.
struct PipelineView: View {
    @Bindable var viewModel: BenchmarkViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tabHeader("GPU Pipeline")

                // ── Data Flow Pipeline ──────────────────────────────
                sectionLabel("Transaction Flow")

                DataFlowView(
                    isRunning: viewModel.isRunning,
                    progress: viewModel.progress
                )

                // ── GPU Wave ────────────────────────────────────────
                sectionLabel("Processing Intensity")

                GPUWaveView(
                    isRunning: viewModel.isRunning,
                    progress: viewModel.progress
                )

                // ── Architecture ────────────────────────────────────
                sectionLabel("Why Apple Silicon Wins This Workload")

                ArchitectureGridView()

                // ── Stream Visualizer ───────────────────────────────
                sectionLabel("Simulated Live Transaction Stream")

                StreamVisualizerView()
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.opacity(0.01))
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
}
