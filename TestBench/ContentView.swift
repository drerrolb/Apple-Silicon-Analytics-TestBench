import SwiftUI

/// Root view container. Creates the `BenchmarkViewModel` and presents the dashboard.
struct ContentView: View {
    @State private var viewModel = BenchmarkViewModel()

    var body: some View {
        DashboardView(viewModel: viewModel)
    }
}
