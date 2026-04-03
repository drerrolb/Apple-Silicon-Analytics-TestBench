import SwiftUI

/// Root TabView container with 4 neon-styled tabs.
///
/// The particle field background is shared across all tabs by sitting
/// behind the TabView in a ZStack.
struct MainTabView: View {
    @Bindable var viewModel: BenchmarkViewModel
    @State private var selectedTab = 0

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

                PipelineView(viewModel: viewModel)
                    .tag(3)
                    .tabItem {
                        Label("Pipeline", systemImage: "cpu")
                    }
            }
            .tint(.kiraaAccent)
        }
        .background(Color.appBackground)
    }
}
