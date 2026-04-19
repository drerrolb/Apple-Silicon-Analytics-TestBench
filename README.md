<p align="center">
  <strong>KIRAA AI</strong><br>
  <em>Apple Silicon Analytics TestBench</em>
</p>

# Python vs Swift + Metal GPU

> **10 million ERP transactions. Five aggregation tasks. One takes 8+ minutes. The other finishes in seconds.**

This project benchmarks real-world financial data processing — the kind of row-level aggregation and scoring that happens in production ERP systems — across two fundamentally different execution models.

| | Python (CPU) | Swift + Metal (GPU) |
|---|---|---|
| **Execution** | Row-by-row `for` loop through CPython interpreter | Compiled Swift + Metal GPU compute shaders |
| **Total time** | ~457,000 ms (~7.6 min) | ~5,000 ms (~5s) |
| **Throughput** | ~22,000 rec/s | ~1,800,000 rec/s |
| **Peak memory** | ~2,000 MB | ~230 MB |
| **Anomalies found** | 20,000 | 20,000 (identical) |

*Measured on Apple M4 Max with 10M rows. Python results from `benchmark_python.py` using `df.iterrows()`. Swift results from on-device Metal GPU benchmark.*

---

## What We're Testing

Five common ERP aggregation tasks that run against 10 million synthetic transactions:

| # | Task | What It Does | Python Approach | Swift + Metal Approach |
|---|------|-------------|-----------------|----------------------|
| 1 | **Total by cost centre** | Group-by sum across 12 departments | `for _, row in df.iterrows()` with dict accumulator | Direct array indexing, compiled loop |
| 2 | **Top 10 suppliers** | Group-by sum, sort, take top 10 | `for _, row in df.iterrows()` with dict accumulator | Hash map accumulation, partial sort |
| 3 | **Z-score anomaly detection** | Per-row statistical scoring against department baselines | `for _, row in df.iterrows()` with dict lookup per row | **Metal GPU**: 1,000+ parallel threads, each scoring one transaction |
| 4 | **Plant x cost centre pivot** | 4 plants x 12 centres = 48-cell cross-tab | `for _, row in df.iterrows()` with tuple-key dict | 2D array indexing, single compiled pass |
| 5 | **Running total** | Cumulative sum over all amounts | `for _, row in df.iterrows()` | Single-pass compiled accumulation |

Each task processes all 10 million rows independently and is timed separately.

---

## Why Swift + Metal Wins

### Compiled vs Interpreted
Swift compiles to native ARM64 machine code. Python interprets bytecode through an eval loop with dynamic type checks on every operation.

### Zero Object Allocation
Swift iterates contiguous 24-byte structs in memory. Python's `iterrows()` creates a new pandas Series object per row — 10 million temporary objects for 10 million rows.

### GPU Parallelism
Metal dispatches 1,000+ GPU threads simultaneously for z-score scoring. Python processes one transaction at a time through the GIL.

### Memory Efficiency
Swift uses packed structs with shared-mode Metal buffers (zero-copy on Apple Silicon). Python DataFrames store each column as a separate numpy array with per-element object overhead.

### Static Dispatch
Swift resolves all method calls at compile time. Python looks up every attribute, method, and operator at runtime through `__getattr__` and descriptor protocols.

---

## The Scoring Logic (Task 3)

Both engines compute identical z-scores:

```
z = (amount - cost_centre_mean) / cost_centre_std
is_anomaly = |z| > 3.5
```

**Python** scores each row in a `for` loop:
```python
for _, row in df.iterrows():
    bl = baselines[row["cost_centre"]]
    z = (row["amount"] - bl["mean"]) / bl["std"]
    if abs(z) > 3.5:
        anomaly_count += 1
```

**Metal** dispatches one GPU thread per transaction:
```metal
kernel void scoreTransactions(..., uint gid [[ thread_position_in_grid ]]) {
    Transaction txn = transactions[gid];
    Baseline baseline = baselines[txn.cost_centre_id];
    float z = (txn.amount - baseline.mean) / baseline.std_dev;
    results[gid].is_anomaly = (fabs(z) > z_threshold) ? 1u : 0u;
}
```

---

## Quick Start

### 1. Run the Python benchmark locally

```bash
pip install pandas numpy tqdm
python3 benchmark_python.py
```

Results are saved to `benchmark_results_python.json`.

### 2. Run the full pipeline (generate shared data + benchmark)

```bash
./run_benchmark.sh              # Generate CSV, run Python benchmark, copy to app bundle
```

### 3. Run the iOS app

1. Open `TestBench.xcodeproj` in Xcode
2. Select an iPhone or iPad simulator (Apple Silicon required)
3. Build and run
4. Python results load from bundled JSON
5. Tap **Run Benchmark** to run Swift + Metal on-device
6. Speedup multiplier appears with side-by-side comparison

### Alternative workflows

```bash
./generate_data.sh                           # Just generate CSV
./run_benchmark.sh --skip-generate           # Run Python on existing CSV
./run_benchmark.sh --verbose --rows 100000   # Quick verbose run
```

---

## iOS App

The benchmark ships as a native iOS app with five tabs:

| Tab | Purpose |
|-----|---------|
| **Dashboard** | Controls, speedup banner, engine result cards, throughput chart, local validation instructions |
| **Analysis** | Per-task timing comparison charts, speedup-per-task bars, time distribution |
| **Explorer** | Data exploration and detailed benchmark data views |
| **Deep Dive** | Detailed explanation of each task, side-by-side Python vs Swift approach, why Metal wins |
| **Pipeline** | Architecture diagrams, GPU data flow animation, stream visualizer |

### Features

- **Kiraa-branded app icon** — shared with the Kiraa engine product family
- **Auto-play** — floating action button rotates through all tabs every 5 seconds (tap to start/stop)
- **Ambient music** — `kiraa-10m-music.mp3` loops quietly in the background
- **Particle field** — floating particles that react to benchmark state
- **GPU wave** — triple-layered sine waveform pulsing with processing intensity
- **Data flow pipeline** — animated dot stream showing transactions through GPU scoring
- **Progress ring** — circular gauge with gradient sweep during runs
- **Stream visualizer** — 500-cell dot grid simulating live transaction scanning

---

## Data Pipeline

```bash
./run_benchmark.sh    # Generate CSV -> Python benchmark -> copy to app bundle
```

Generates `benchmark_data.csv` (10M rows, seed=42), runs the Python benchmark, and copies both the CSV and results JSON into the iOS app bundle. Swift loads the same CSV at runtime.

### Data Format

| Column | Type | Description |
|--------|------|-------------|
| `amount` | float | Transaction amount (normally distributed per cost centre) |
| `cost_centre_id` | int (0-11) | Maps to: RAW_MATERIALS, PACKAGING, LOGISTICS, ... |
| `txn_type_id` | int (0-6) | Maps to: PURCHASE_ORDER, INVOICE_MATCH, ... |
| `supplier_id` | int (1000-9998) | 4-digit supplier identifier |
| `plant_code_id` | int (0-3) | Maps to: GOLD_COAST, SYDNEY, MELBOURNE, BRISBANE |

---

## Test Suite

```bash
xcodebuild test -project TestBench.xcodeproj -scheme TestBench \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

| Test Class | Tests | Coverage |
|-----------|-------|----------|
| MetalStructAlignmentTests | 6 | GPU struct layout (24/8/8 bytes, field offsets) |
| ConfigTests | 6 | All constants match expected values |
| TimingTests | 2 | Monotonicity and positivity |
| SeededRNGTests | 5 | Determinism, Gaussian distribution, edge cases |
| DataGeneratorTests | 13 | Row count, ID ranges, anomaly rate, baselines, CSV loading |
| ZScoreTests | 7 | Known z-scores, threshold boundary, zero stdDev |
| BenchmarkRunnerTests | 13 | All 5 tasks, empty/single input, progress, throughput |
| BenchmarkModelsTests | 4 | JSON decode/encode, snake_case keys, nullable fields |
| BenchmarkViewModelTests | 8 | State machine, speedup calc, guard conditions |

---

## Project Structure

```
TestBench/
├── benchmark_python.py          # Python benchmark (standalone CLI, df.iterrows())
├── generate_data.py             # Generate benchmark_data.csv (10M rows)
├── generate_data.sh             # Shell wrapper (generates + copies to app)
├── run_benchmark.sh             # Full pipeline: generate -> benchmark -> bundle
├── benchmark_results_python.json
│
├── TestBench/                   # iOS app (SwiftUI + Metal)
│   ├── TestBenchApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── BenchmarkModels.swift    # Transaction, Baseline, Config, results
│   │   ├── BenchmarkData.swift      # Detailed chart data structures
│   │   ├── BenchmarkEngine.swift    # High-resolution timing
│   │   └── AudioManager.swift       # Ambient music playback
│   ├── Engines/
│   │   ├── MetalEngine.swift        # Metal GPU compute + SwiftBenchmarkRunner
│   │   └── DataGenerator.swift      # Data generation + CSV loading
│   ├── Shaders/
│   │   └── AnomalyScoring.metal     # GPU z-score kernel
│   ├── ViewModels/
│   │   └── BenchmarkViewModel.swift # Orchestrates runs, loads Python JSON
│   ├── Views/
│   │   ├── MainTabView.swift        # 5-tab container
│   │   ├── DashboardView.swift      # Dashboard with controls + validation info
│   │   ├── TaskAnalysisView.swift   # Per-task timing charts
│   │   ├── DataExplorerView.swift   # Data exploration
│   │   ├── DeepDiveView.swift       # Task explanations + why Metal wins
│   │   ├── PipelineView.swift       # Architecture + animations
│   │   ├── EngineCardView.swift     # Per-engine stats card
│   │   ├── SpeedupBannerView.swift  # Hero speedup multiplier
│   │   ├── ThroughputChartView.swift
│   │   ├── BenchmarkControlView.swift
│   │   ├── ChartHelpers.swift       # Shared chart styling
│   │   ├── ParticleFieldView.swift
│   │   ├── GPUWaveView.swift
│   │   ├── DataFlowView.swift
│   │   ├── ProgressRingView.swift
│   │   ├── ArchitectureGridView.swift
│   │   └── StreamVisualizerView.swift
│   ├── Theme/
│   │   └── AppTheme.swift           # Pink/purple neon palette + fonts
│   └── Resources/
│       ├── benchmark_results_python.json
│       └── kiraa-10m-music.mp3
│
├── TestBenchTests/              # Unit tests
├── TestBenchUITests/            # UI tests
├── reference/                   # Original reference implementations
└── TestBench.xcodeproj/
```

## Requirements

| Component | Version |
|-----------|---------|
| Python | 3.10+ |
| pandas | 2.0+ |
| numpy | 1.24+ |
| Xcode | 26+ |
| iOS | 26+ |
| Hardware | Apple Silicon (M1/M2/M3/M4 or A-series) |

---

<p align="center">
  <strong>Kiraa AI Pty Ltd</strong> · Gold Coast, QLD, Australia<br>
  <em>Making financial intelligence fast.</em>
</p>
