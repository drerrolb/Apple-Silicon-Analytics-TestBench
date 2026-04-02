import SwiftUI
import Combine

/// Animated 500-cell dot grid simulating a live transaction scanning stream.
///
/// A cursor sweeps through the grid at 60ms intervals (≈17 fps), processing
/// 10 dots per tick. Each dot is randomly flagged as an anomaly with 1.8%
/// probability (close to the benchmark's ~2% anomaly rate for visual effect).
struct StreamVisualizerView: View {
    @State private var dots: [DotState] = Array(repeating: .normal, count: 500)
    @State private var cursor = 0

    private let columns = Array(repeating: GridItem(.fixed(7), spacing: 2), count: 50)
    private let timer = Timer.publish(every: 0.06, on: .main, in: .common).autoconnect()

    /// Visual state of a single cell in the grid.
    enum DotState {
        case normal   // Processed, no anomaly (dark background)
        case anomaly  // Flagged as anomalous (red, glowing)
        case active   // Currently being scanned (cyan, glowing)

        var color: Color {
            switch self {
            case .normal:  Color(hex: "150D25")
            case .anomaly: .danger
            case .active:  .swiftCyan
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 4) {
                    Text("Each cell = 1 transaction  ·  ")
                        .font(.caption2)
                        .foregroundStyle(Color.dimText)
                    Circle()
                        .fill(Color.danger)
                        .frame(width: 6, height: 6)
                    Text(" anomaly flagged")
                        .font(.caption2)
                        .foregroundStyle(Color.dimText)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.swiftCyan)
                        .frame(width: 6, height: 6)
                        .opacity(pulseOpacity)
                    Text("LIVE")
                        .font(.monoCaption)
                        .tracking(2)
                        .foregroundStyle(Color.swiftCyan)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0 ..< dots.count, id: \.self) { i in
                    Rectangle()
                        .fill(dots[i].color)
                        .frame(width: 7, height: 7)
                        .shadow(color: dots[i] == .anomaly ? .danger.opacity(0.5) : .clear, radius: 2)
                        .shadow(color: dots[i] == .active ? .swiftCyan.opacity(0.5) : .clear, radius: 3)
                }
            }
        }
        .padding(20)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
        .onReceive(timer) { _ in
            advanceCursor()
        }
    }

    @State private var pulsePhase = false

    /// Pulsing opacity for the "LIVE" indicator.
    /// sin(t * 4.5) produces a ~4.5 Hz oscillation, mapped to the 0.2–1.0 range.
    private var pulseOpacity: Double {
        let t = Date.timeIntervalSinceReferenceDate
        return 0.6 + 0.4 * sin(t * 4.5)
    }

    /// Advance the scanning cursor by one batch (10 dots per tick).
    ///
    /// Each tick: clears the previous active marker, scans 10 new cells
    /// (randomly flagging ~1.8% as anomalies), marks the cursor position
    /// as active, and wraps around at the end of the grid.
    private func advanceCursor() {
        // Reset any previously active dots back to normal before scanning new ones.
        for i in 0 ..< dots.count {
            if dots[i] == .active { dots[i] = .normal }
        }

        let batchSize = 10
        for i in 0 ..< batchSize {
            let idx = (cursor + i) % dots.count
            // 1.8% anomaly rate per dot — slightly below the 2% injection rate
            // to create a visually realistic scanning effect.
            dots[idx] = Double.random(in: 0...1) < 0.018 ? .anomaly : .normal
        }
        dots[cursor % dots.count] = .active
        cursor = (cursor + batchSize) % dots.count
    }
}
