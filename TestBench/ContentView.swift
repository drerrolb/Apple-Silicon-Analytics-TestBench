import SwiftUI

/// Root view container. Creates the `BenchmarkViewModel` and presents the tab interface.
struct ContentView: View {
    @State private var viewModel = BenchmarkViewModel()

    var body: some View {
        MainTabView(viewModel: viewModel)
    }
}
