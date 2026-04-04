# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

- **Build:** `xcodebuild -project TestBench.xcodeproj -scheme TestBench -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Run tests:** `xcodebuild -project TestBench.xcodeproj -scheme TestBench -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- **Run a single test:** `xcodebuild test -project TestBench.xcodeproj -scheme TestBench -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TestBenchTests/TestBenchTests/testExample`
- **Run Python benchmark:** `python3 benchmark_python.py` (requires pandas, numpy, tqdm)

## Architecture

iOS benchmark app comparing Python/pandas CPU performance vs Swift/Metal GPU for financial anomaly detection (z-score scoring of ERP transactions).

### App Structure (TestBench/)

- **TestBenchApp.swift** — App entry point, forces dark mode, starts ambient music via `AudioManager`
- **ContentView.swift** — Thin shell creating `BenchmarkViewModel` and presenting `MainTabView`

### Models/
- **BenchmarkModels.swift** — Shared types: `Transaction` (24-byte GPU-aligned struct), `Baseline`, `ScoredResult`, `BenchmarkResult` (Codable), `Config` constants, `BenchmarkProgress`
- **BenchmarkData.swift** — Detailed intermediate chart data: cost centre totals, supplier rankings, pivot cells, plant totals, anomaly count
- **BenchmarkEngine.swift** — Timing helpers (`highResolutionTime()` using `CLOCK_UPTIME_RAW`)
- **AudioManager.swift** — Singleton ambient music player. Loops `kiraa-10m-music.mp3` at 15% volume via `AVAudioPlayer`

### Engines/
- **MetalEngine.swift** — Metal GPU compute pipeline. Uses `device.makeDefaultLibrary()` (not Bundle.module). Shared-mode buffers for zero-copy on Apple Silicon. Conforms to `BenchmarkEngine`.
- **DataGenerator.swift** — Generates 10M synthetic ERP transactions with deterministic RNG (seed 42). Injects 0.2% anomalies.

### Shaders/
- **AnomalyScoring.metal** — Metal compute kernel. One thread per transaction, z-score against cost-centre baseline. Struct layout must match Swift `Transaction`/`Baseline`/`ScoredResult` exactly.

### ViewModels/
- **BenchmarkViewModel.swift** — `@Observable` class. Orchestrates data generation, Metal benchmark run (via `Task.detached`), Python JSON loading. Reports progress to UI.

### Views/
- **MainTabView.swift** — 5-tab container (Dashboard, Analysis, Explorer, Deep Dive, Pipeline) with floating action button that auto-rotates tabs every 5 seconds
- **DashboardView.swift** — Main scrollable dashboard composing all sub-views, includes "Validate Locally" section with GitHub link
- **TaskAnalysisView.swift** — Per-task timing comparison charts, speedup bars, time distribution
- **DataExplorerView.swift** — Data exploration and detailed benchmark data views
- **DeepDiveView.swift** — Detailed explanation of each benchmark task, side-by-side Python vs Swift approach, why Metal wins, head-to-head comparison table
- **PipelineView.swift** — Architecture diagrams, GPU data flow animation, stream visualizer
- **EngineCardView.swift** — Stats card for CPU or GPU engine with animated bar fills
- **ThroughputChartView.swift** — Head-to-head horizontal bar chart
- **SpeedupBannerView.swift** — Large speedup multiplier display
- **BenchmarkControlView.swift** — Run button, progress bar, status
- **ChartHelpers.swift** — Shared chart styling helpers (tabHeader, chartTitle, emptyState)

### Theme/
- **AppTheme.swift** — Color palette (dark theme: cyan for Metal, amber for Python) and font definitions. All static properties must be `nonisolated` due to `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

### Root level scripts
- **benchmark_python.py** — Standalone Python benchmark (pandas `df.iterrows()`) outputting `benchmark_results_python.json`
- **generate_data.py** — Generates shared `benchmark_data.csv` (10M rows, seed=42)
- **generate_data.sh** — Shell wrapper for generate_data.py (sets up venv)
- **run_benchmark.sh** — Full pipeline: generate CSV → run Python benchmark → copy results to app bundle
- **reference/** — Original reference implementations (not part of app build)

## Key Details

- **Swift concurrency**: Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Engine classes and static Color/Font extensions must be `nonisolated`. Background work uses `Task.detached`.
- **Metal shader compilation**: `.metal` files in the synchronized folder auto-compile to `default.metallib`. Load via `device.makeDefaultLibrary()`.
- **Struct alignment**: `Transaction` is 24 bytes with a `_pad` field. Metal shader structs must match exactly.
- Bundle identifier: `kiraa.TestBench`, iOS 26.4, Swift 5
