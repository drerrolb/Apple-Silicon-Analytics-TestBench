import SwiftUI
import Combine

/// Animated waveform visualization showing GPU processing intensity.
///
/// Renders multiple overlapping sine waves that pulse faster and brighter
/// during benchmark execution. The waves represent parallel GPU thread
/// activity — amplitude scales with progress.
struct GPUWaveView: View {
    let isRunning: Bool
    let progress: Double

    @State private var phase: Double = 0
    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width

            // Draw 3 overlapping waves with different frequencies
            for waveIndex in 0 ..< 3 {
                let config = waveConfig(index: waveIndex)
                var path = Path()

                for x in stride(from: 0, through: width, by: 2) {
                    let normalizedX = x / width
                    let y = midY + sin(normalizedX * config.frequency + phase * config.speed + config.offset)
                        * config.amplitude * size.height * 0.3

                    if x == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(config.color),
                    lineWidth: config.lineWidth
                )
            }
        }
        .frame(height: 60)
        .onReceive(timer) { _ in
            phase += isRunning ? 0.08 : 0.015
        }
    }

    private struct WaveConfig {
        let frequency: Double
        let speed: Double
        let offset: Double
        let amplitude: Double
        let color: Color
        let lineWidth: Double
    }

    private func waveConfig(index: Int) -> WaveConfig {
        let intensity = isRunning ? (0.5 + progress * 0.5) : 0.15

        switch index {
        case 0:
            return WaveConfig(
                frequency: 8, speed: 1.0, offset: 0,
                amplitude: intensity,
                color: Color(hex: "BF5AF2").opacity(isRunning ? 0.5 : 0.1),
                lineWidth: isRunning ? 2.5 : 1.0
            )
        case 1:
            return WaveConfig(
                frequency: 12, speed: 1.3, offset: .pi / 3,
                amplitude: intensity * 0.6,
                color: Color(hex: "BF5AF2").opacity(isRunning ? 0.25 : 0.05),
                lineWidth: isRunning ? 1.5 : 0.5
            )
        default:
            return WaveConfig(
                frequency: 6, speed: 0.7, offset: .pi,
                amplitude: intensity * 0.4,
                color: Color(hex: "FF6B9D").opacity(isRunning ? 0.15 : 0.03),
                lineWidth: isRunning ? 1.0 : 0.5
            )
        }
    }
}
