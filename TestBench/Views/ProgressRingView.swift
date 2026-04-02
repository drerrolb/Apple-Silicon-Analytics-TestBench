import SwiftUI

/// Animated circular progress ring with glowing sweep and pulse effects.
///
/// Displays benchmark progress as a circular gauge with:
/// - Gradient stroke that sweeps around the ring
/// - Glowing tip at the progress point
/// - Pulsing center with task number and name
/// - Ambient particle sparks at the leading edge
struct ProgressRingView: View {
    let progress: Double
    let currentTask: String
    let isRunning: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: Double = 1.0

    private let ringSize: Double = 120
    private let lineWidth: Double = 4

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.border, lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            // Ambient glow ring (rotating when running)
            if isRunning {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            colors: [.clear, Color(hex: "BF5AF2").opacity(0.1), .clear],
                            center: .center
                        ),
                        lineWidth: lineWidth + 8
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(rotation))
            }

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: "BF5AF2").opacity(0.3),
                            Color(hex: "BF5AF2"),
                            Color(hex: "BF5AF2")
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Glowing tip at progress point
            if isRunning && progress > 0.01 {
                Circle()
                    .fill(Color(hex: "BF5AF2"))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hex: "BF5AF2").opacity(0.8), radius: 8)
                    .shadow(color: Color(hex: "BF5AF2").opacity(0.4), radius: 16)
                    .offset(y: -ringSize / 2)
                    .rotationEffect(.degrees(360 * progress - 90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }

            // Center content
            VStack(spacing: 4) {
                if isRunning {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.swiftCyan)
                        .contentTransition(.numericText())

                    if !currentTask.isEmpty {
                        Text(taskShortName)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.dimText)
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(Color.swiftCyan.opacity(0.3))
                }
            }
            .scaleEffect(pulseScale)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }

    /// Extract just the task name from "Task 2/5: Top 10 suppliers"
    private var taskShortName: String {
        if let colonIndex = currentTask.firstIndex(of: ":") {
            return String(currentTask[currentTask.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return currentTask
    }
}
