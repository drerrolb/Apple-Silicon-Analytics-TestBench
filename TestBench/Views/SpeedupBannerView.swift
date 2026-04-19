import SwiftUI

/// Large speedup multiplier display with explanation text.
struct SpeedupBannerView: View {
    let speedup: Double
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass == .compact }

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    headline
                    description
                }
            } else {
                HStack(spacing: 24) {
                    headline
                    description
                }
            }
        }
        .padding(isCompact ? 18 : 24)
        .background(Color.surface2)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.swiftCyan)
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SWIFT / METAL ADVANTAGE")
                .font(.monoCaption)
                .tracking(2)
                .foregroundStyle(Color.dimText)

            Text(String(format: "%.1f\u{00D7}", speedup))
                .font(.system(size: isCompact ? 52 : 72, weight: .black, design: .rounded))
                .foregroundStyle(Color.swiftCyan)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Same workload. Same data.\nRadically different outcome.")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.bodyText)

            Text("Python's interpreter loop pays overhead per record: dict lookups, conditionals, math calls. Metal dispatches 1,000 GPU threads simultaneously — each scoring transactions in parallel with zero-copy unified memory.")
                .font(.caption)
                .foregroundStyle(Color.dimText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
