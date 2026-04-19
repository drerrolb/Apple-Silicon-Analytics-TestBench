import SwiftUI

/// 2x2 grid explaining why Apple Silicon wins this workload.
/// Compares Python (interpreter loop, DataFrame copies) vs Swift+Metal
/// (compiled iteration, parallel GPU z-score with zero-copy unified memory).
struct ArchitectureGridView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var columns: [GridItem] {
        hSizeClass == .compact
            ? [GridItem(.flexible(), spacing: 2)]
            : [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            archCell(
                label: "Python · CPU",
                title: "Interpreter loop",
                body: "Each `for row in df.iterrows()` call pays full CPython overhead: dict lookups, object creation, GIL contention. **~100× slower than vectorized numpy.**"
            )
            archCell(
                label: "Python · Memory",
                title: "DataFrame copies",
                body: "10M rows × multiple columns → **3+ GB** with working copies. Garbage collection spikes latency unpredictably."
            )
            archCell(
                label: "Swift · CPU",
                title: "Compiled iteration",
                body: "Swift compiles to native ARM64. Array iteration is **pointer arithmetic** — no interpreter, no GIL, no object boxing per element."
            )
            archCell(
                label: "Metal · GPU",
                title: "Parallel z-score",
                body: "1,000 GPU threads score transactions simultaneously. **Zero-copy unified memory** — CPU and GPU share the same physical address."
            )
        }
    }

    @ViewBuilder
    private func archCell(label: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.monoCaption).tracking(2).textCase(.uppercase)
                .foregroundStyle(Color.dimText)
            Text(title)
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.whiteText)
            Text((try? AttributedString(markdown: body)) ?? AttributedString(body))
                .font(.caption2)
                .foregroundStyle(Color.dimText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.surface)
    }
}
