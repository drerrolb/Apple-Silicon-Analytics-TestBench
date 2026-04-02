import SwiftUI

/// Full-screen particle field that reacts to benchmark state.
///
/// - **Idle:** Slow-drifting dim particles (ambient atmosphere)
/// - **Running:** Fast neon purple/pink particles stream upward with glow trails
/// - **Complete:** Particle burst celebration, then fade to idle
///
/// Uses `TimelineView` for frame-driven animation — no manual `Timer` needed.
struct ParticleFieldView: View {
    let isRunning: Bool
    let progress: Double
    let isComplete: Bool

    @State private var particles: [Particle] = []
    @State private var lastUpdate: Date = .now
    @State private var burstTriggered = false
    @State private var initialized = false

    private let particleCount = 50

    struct Particle {
        var x: Double
        var y: Double
        var size: Double
        var opacity: Double
        var speed: Double
        var isPrimary: Bool   // true = purple, false = pink
        var drift: Double
        var glowRadius: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let point = CGPoint(x: particle.x * size.width, y: particle.y * size.height)
                    let color = particle.isPrimary
                        ? Color(red: 0.75, green: 0.35, blue: 0.95)
                        : Color(red: 1.0, green: 0.42, blue: 0.62)

                    // Glow layer
                    if particle.glowRadius > 0 {
                        let glowRect = CGRect(
                            x: point.x - particle.glowRadius,
                            y: point.y - particle.glowRadius,
                            width: particle.glowRadius * 2,
                            height: particle.glowRadius * 2
                        )
                        context.fill(
                            Circle().path(in: glowRect),
                            with: .color(color.opacity(particle.opacity * 0.2))
                        )
                    }

                    // Core dot
                    let rect = CGRect(
                        x: point.x - particle.size / 2,
                        y: point.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.fill(Circle().path(in: rect), with: .color(color.opacity(particle.opacity)))
                }
            }
            .onChange(of: timeline.date) { _, now in
                tick(now: now)
            }
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            particles = (0 ..< particleCount).map { _ in makeIdleParticle() }
            lastUpdate = .now
        }
        .onChange(of: isRunning) { _, running in
            if running {
                burstTriggered = false
                // Replace some idle particles with running ones
                for i in 0 ..< min(35, particles.count) {
                    particles[i] = makeRunningParticle()
                }
            }
        }
        .onChange(of: isComplete) { _, complete in
            if complete && !burstTriggered {
                burstTriggered = true
                triggerBurst()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Frame Update

    private func tick(now: Date) {
        let dt = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        guard dt < 0.5 else { return }  // skip large jumps

        for i in particles.indices {
            // Move upward
            particles[i].y -= particles[i].speed * dt * 30
            particles[i].x += particles[i].drift * dt * 30

            // Fade out near top
            if particles[i].y < 0.1 {
                particles[i].opacity *= (1.0 - dt * 3)
            }

            // Respawn when off-screen or faded
            if particles[i].y < -0.05 || particles[i].opacity < 0.005 {
                particles[i] = isRunning ? makeRunningParticle() : makeIdleParticle()
            }

            // Bounce horizontal drift at edges
            if particles[i].x < 0 || particles[i].x > 1 {
                particles[i].drift *= -1
            }
        }

        // Trim burst particles back to normal count
        if particles.count > particleCount + 20 {
            particles = Array(particles.prefix(particleCount))
        }
    }

    // MARK: - Particle Factories

    private func makeIdleParticle() -> Particle {
        Particle(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...1.2),
            size: Double.random(in: 1.5...3.0),
            opacity: Double.random(in: 0.03...0.12),
            speed: Double.random(in: 0.0003...0.001),
            isPrimary: Bool.random(),
            drift: Double.random(in: -0.0003...0.0003),
            glowRadius: 0
        )
    }

    private func makeRunningParticle() -> Particle {
        Particle(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0.8...1.3),
            size: Double.random(in: 2.0...5.0),
            opacity: Double.random(in: 0.15...0.5),
            speed: Double.random(in: 0.003...0.012),
            isPrimary: Double.random(in: 0...1) < 0.7,
            drift: Double.random(in: -0.002...0.002),
            glowRadius: Double.random(in: 4...12)
        )
    }

    private func triggerBurst() {
        for _ in 0 ..< 25 {
            particles.append(Particle(
                x: 0.5 + Double.random(in: -0.1...0.1),
                y: 0.4 + Double.random(in: -0.1...0.1),
                size: Double.random(in: 3...7),
                opacity: Double.random(in: 0.5...1.0),
                speed: Double.random(in: 0.005...0.02),
                isPrimary: Bool.random(),
                drift: Double.random(in: -0.01...0.01),
                glowRadius: Double.random(in: 8...18)
            ))
        }
    }
}
