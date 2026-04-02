import SwiftUI

/// Large speedup multiplier display with explanation text.
struct SpeedupBannerView: View {
    let speedup: Double

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SWIFT / METAL ADVANTAGE")
                    .font(.monoCaption)
                    .tracking(2)
                    .foregroundStyle(Color.dimText)

                Text(String(format: "%.1f\u{00D7}", speedup))
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(Color.swiftCyan)
                    .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Same workload. Same data.\nRadically different outcome.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.bodyText)

                Text("Python's interpreter loop pays overhead per record: dict lookups, conditionals, math calls. Metal dispatches 1,000 GPU threads simultaneously — each scoring transactions in parallel with zero-copy unified memory.")
                    .font(.caption)
                    .foregroundStyle(Color.dimText)
                    .lineSpacing(4)
            }
        }
        .padding(24)
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
}
