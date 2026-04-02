// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnomalyBenchmark",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AnomalyBenchmark",
            path: "Sources/AnomalyBenchmark",
            resources: [
                .process("Metal/AnomalyScoring.metal")
            ]
        )
    ]
)
