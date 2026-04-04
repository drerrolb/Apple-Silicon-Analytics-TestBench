import SwiftUI

/// Root TabView container with 5 neon-styled tabs.
///
/// The particle field background is shared across all tabs by sitting
/// behind the TabView in a ZStack. A floating action button (FAB) in
/// the bottom-right corner cycles through tabs automatically.
struct MainTabView: View {
    @Bindable var viewModel: BenchmarkViewModel
    @State private var selectedTab = 0
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>?

    private let tabCount = 5

    var body: some View {
        ZStack {
            // Shared particle background across all tabs
            ParticleFieldView(
                isRunning: viewModel.isRunning,
                progress: viewModel.progress,
                isComplete: viewModel.bothComplete
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView(viewModel: viewModel)
                    .tag(0)
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                    }

                TaskAnalysisView(viewModel: viewModel)
                    .tag(1)
                    .tabItem {
                        Label("Analysis", systemImage: "chart.xyaxis.line")
                    }

                DataExplorerView(viewModel: viewModel)
                    .tag(2)
                    .tabItem {
                        Label("Explorer", systemImage: "magnifyingglass.circle")
                    }

                DeepDiveView(viewModel: viewModel)
                    .tag(3)
                    .tabItem {
                        Label("Deep Dive", systemImage: "doc.text.magnifyingglass")
                    }

                PipelineView(viewModel: viewModel)
                    .tag(4)
                    .tabItem {
                        Label("Pipeline", systemImage: "cpu")
                    }
            }
            .tint(.kiraaAccent)

            // Floating action button — auto-rotates through tabs every 5 seconds
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if isAutoPlaying {
                            stopAutoPlay()
                        } else {
                            startAutoPlay()
                        }
                    } label: {
                        Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appBackground)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(isAutoPlaying ? Color.swiftCyan : Color.kiraaAccent)
                                    .shadow(color: (isAutoPlaying ? Color.swiftCyan : Color.kiraaAccent).opacity(0.5), radius: 12)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 90) // above tab bar
                }
            }
        }
        .background(Color.appBackground)
        .onChange(of: selectedTab) {
            // If user manually taps a tab while auto-playing, stop auto-play
            // (the onChange fires for both manual and programmatic changes,
            // but the task handles its own cycling so this is a no-op for that case)
        }
    }

    private func startAutoPlay() {
        isAutoPlaying = true
        autoPlayTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedTab = (selectedTab + 1) % tabCount
                }
            }
        }
    }

    private func stopAutoPlay() {
        isAutoPlaying = false
        autoPlayTask?.cancel()
        autoPlayTask = nil
    }
}
