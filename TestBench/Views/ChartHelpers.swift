import SwiftUI

/// Shared styling helpers for chart tab views.

func tabHeader(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(Color.whiteText)
        .frame(maxWidth: .infinity, alignment: .leading)
}

func chartTitle(_ title: String) -> some View {
    Text(title)
        .font(.system(.subheadline, design: .monospaced))
        .fontWeight(.semibold)
        .foregroundStyle(Color.whiteText)
}

func chartSubtitle(_ text: String) -> some View {
    Text(text)
        .font(.caption2)
        .foregroundStyle(Color.dimText)
}

func emptyState(_ message: String) -> some View {
    VStack(spacing: 16) {
        Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 48))
            .foregroundStyle(Color.mutedText)
        Text(message)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Color.dimText)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 80)
}
