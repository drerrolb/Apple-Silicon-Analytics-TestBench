import SwiftUI

/// Shared styling helpers for chart tab views.

func tabHeader(_ title: String) -> some View {
    HStack(alignment: .center, spacing: 12) {
        Text(title)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(Color.whiteText)
            .frame(maxWidth: .infinity, alignment: .leading)

        KiraaLogoMark(size: 36)
    }
}

/// Kiraa brand mark — rounded-square logo with a subtle glow.
struct KiraaLogoMark: View {
    var size: CGFloat = 36

    var body: some View {
        Image("KiraaLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(Color.border, lineWidth: 0.5)
            }
            .shadow(color: Color.kiraaAccent.opacity(0.35), radius: 6)
            .accessibilityLabel("Kiraa")
    }
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
