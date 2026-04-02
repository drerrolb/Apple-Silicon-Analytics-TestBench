import SwiftUI
import Combine

/// Animated data flow pipeline showing transactions streaming through the GPU.
///
/// Dots flow from left to right, pass through a "GPU" processing zone (cyan),
/// and emerge scored on the right. During benchmark runs, flow speed and
/// density increase dramatically to visualize throughput.
struct DataFlowView: View {
    let isRunning: Bool
    let progress: Double

    @State private var flowDots: [FlowDot] = []
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    struct FlowDot: Identifiable {
        let id = UUID()
        var x: Double          // 0..1 normalized position
        var y: Double           // vertical offset for lane
        var speed: Double
        var isAnomaly: Bool
        var opacity: Double
        var size: Double
    }

    var body: some View {
        VStack(spacing: 8) {
            // Pipeline labels
            HStack {
                Text("INPUT")
                    .font(.monoCaption)
                    .tracking(2)
                    .foregroundStyle(Color.dimText)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.swiftCyan)
                    Text("GPU SCORING")
                        .font(.monoCaption)
                        .tracking(2)
                        .foregroundStyle(isRunning ? Color.swiftCyan : Color.dimText)
                }
                Spacer()
                Text("SCORED")
                    .font(.monoCaption)
                    .tracking(2)
                    .foregroundStyle(Color.dimText)
            }

            // Flow canvas
            Canvas { context, size in
                let gpuZoneStart = size.width * 0.35
                let gpuZoneEnd = size.width * 0.65

                // GPU processing zone background
                let zoneRect = CGRect(x: gpuZoneStart, y: 0,
                                      width: gpuZoneEnd - gpuZoneStart,
                                      height: size.height)
                let zoneOpacity = isRunning ? 0.08 : 0.03
                context.fill(
                    Rectangle().path(in: zoneRect),
                    with: .color(Color(hex: "BF5AF2").opacity(zoneOpacity))
                )

                // Zone borders
                let leftBorder = Path { p in
                    p.move(to: CGPoint(x: gpuZoneStart, y: 0))
                    p.addLine(to: CGPoint(x: gpuZoneStart, y: size.height))
                }
                let rightBorder = Path { p in
                    p.move(to: CGPoint(x: gpuZoneEnd, y: 0))
                    p.addLine(to: CGPoint(x: gpuZoneEnd, y: size.height))
                }
                let borderOpacity = isRunning ? 0.3 : 0.1
                context.stroke(leftBorder, with: .color(Color(hex: "BF5AF2").opacity(borderOpacity)), lineWidth: 1)
                context.stroke(rightBorder, with: .color(Color(hex: "BF5AF2").opacity(borderOpacity)), lineWidth: 1)

                // Flow dots
                for dot in flowDots {
                    let px = dot.x * size.width
                    let py = dot.y * size.height

                    let inGPUZone = px > gpuZoneStart && px < gpuZoneEnd
                    let pastGPU = px > gpuZoneEnd

                    let color: Color
                    if dot.isAnomaly && pastGPU {
                        color = .danger
                    } else if inGPUZone {
                        color = Color(hex: "BF5AF2")
                    } else {
                        color = Color(hex: "5A6080")
                    }

                    // Glow in GPU zone
                    if inGPUZone && isRunning {
                        let glowRect = CGRect(x: px - 6, y: py - 6, width: 12, height: 12)
                        context.fill(
                            Circle().path(in: glowRect),
                            with: .color(Color(hex: "BF5AF2").opacity(0.2))
                        )
                    }

                    // Anomaly glow after GPU zone
                    if dot.isAnomaly && pastGPU {
                        let glowRect = CGRect(x: px - 5, y: py - 5, width: 10, height: 10)
                        context.fill(
                            Circle().path(in: glowRect),
                            with: .color(Color.danger.opacity(0.3))
                        )
                    }

                    let dotRect = CGRect(x: px - dot.size / 2, y: py - dot.size / 2,
                                         width: dot.size, height: dot.size)
                    context.fill(
                        Circle().path(in: dotRect),
                        with: .color(color.opacity(dot.opacity))
                    )
                }
            }
            .frame(height: 50)

            // Throughput indicator
            if isRunning {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.swiftCyan)
                            .frame(width: 4, height: 4)
                        Text("PROCESSING")
                            .font(.monoCaption)
                            .tracking(2)
                            .foregroundStyle(Color.swiftCyan.opacity(0.6))
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.border, lineWidth: 1)
        }
        .onReceive(timer) { _ in
            updateDots()
        }
        .animation(.easeInOut(duration: 0.3), value: isRunning)
    }

    private func updateDots() {
        // Move existing dots
        for i in flowDots.indices {
            flowDots[i].x += flowDots[i].speed

            // Fade out near right edge
            if flowDots[i].x > 0.9 {
                flowDots[i].opacity *= 0.92
            }
        }

        // Remove off-screen dots
        flowDots.removeAll { $0.x > 1.1 || $0.opacity < 0.01 }

        // Spawn new dots
        let spawnRate = isRunning ? 3 : 1
        let maxDots = isRunning ? 80 : 20

        if flowDots.count < maxDots {
            for _ in 0 ..< spawnRate {
                let speed = isRunning
                    ? Double.random(in: 0.008...0.02)
                    : Double.random(in: 0.002...0.005)

                flowDots.append(FlowDot(
                    x: Double.random(in: -0.05...0.0),
                    y: Double.random(in: 0.15...0.85),
                    speed: speed,
                    isAnomaly: Double.random(in: 0...1) < 0.02,
                    opacity: isRunning ? Double.random(in: 0.4...0.8) : Double.random(in: 0.1...0.3),
                    size: Double.random(in: 2...4)
                ))
            }
        }
    }
}
