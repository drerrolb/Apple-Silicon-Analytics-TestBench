import SwiftUI

/// Run button, progress bar, and status display for the benchmark.
struct BenchmarkControlView: View {
    @Bindable var viewModel: BenchmarkViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Row count info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Config.numRows / 1_000_000)M transactions · \(Config.streamingBatch) batch size")
                        .font(.monoCaption)
                        .foregroundStyle(Color.dimText)

                    let memMB = Config.numRows * MemoryLayout<Transaction>.stride / 1_048_576
                    Text("Est. memory: ~\(memMB) MB")
                        .font(.monoCaption)
                        .foregroundStyle(Color.mutedText)
                }

                Spacer()

                Button {
                    viewModel.runBenchmark()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isRunning {
                            ProgressView()
                                .tint(.appBackground)
                                .scaleEffect(0.7)
                        }
                        Text(viewModel.isRunning ? "RUNNING..." : "RUN BENCHMARK")
                            .font(.monoCaption)
                            .tracking(2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(viewModel.isRunning ? Color.dimText : Color.appBackground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(viewModel.isRunning ? Color.border : Color.swiftCyan)
                }
                .disabled(viewModel.isRunning || !viewModel.gpuAvailable)
            }

            // Progress
            if viewModel.isRunning {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.progress)
                        .tint(.swiftCyan)

                    Text(viewModel.currentTask)
                        .font(.monoCaption)
                        .foregroundStyle(Color.dimText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !viewModel.gpuAvailable {
                Text("Metal GPU not available on this device")
                    .font(.monoCaption)
                    .foregroundStyle(Color.danger)
            }
        }
        .padding(20)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRunning)
    }
}
