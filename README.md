<p align="center">
  <strong>KIRAA AI</strong><br>
  <em>Financial Anomaly Detection Benchmark</em>
</p>

# Python vs Swift + Metal GPU

> **10 million ERP transactions. Five aggregation tasks. One takes 8 minutes. The other finishes in milliseconds.**

This project benchmarks real-world financial data processing — the kind of row-level aggregation and scoring that happens in production ERP systems — across two fundamentally different execution models.

| | Python (CPU) | Swift + Metal (GPU) |
|---|---|---|
| **Execution** | Row-by-row `for` loop through CPython interpreter | Compiled Swift + Metal GPU compute shaders |
| **Total time** | ~470,000 ms (~8 min) | Milliseconds |
| **Throughput** | ~21,000 rec/s | Millions of rec/s |
| **Peak memory** | ~2,000 MB | ~230 MB |
| **Anomalies found** | 20,000 | 20,000 (identical) |

*Measured on Apple M4 Max with 10M rows. Both engines process the same shared CSV dataset and produce identical results.*

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

## Why We're Testing This

### The real-world problem

Enterprise financial systems process millions of transaction records daily. Common operations — aggregation, anomaly detection, pivot reporting — seem simple at the algorithmic level but become bottlenecks at scale. The question is: **how much does the execution model matter when the logic stays the same?**

### Python's structural limitation

Python is the dominant language for data processing, but its interpreter imposes a hard floor on per-record cost. When business logic requires:

- **Dictionary lookups** per record (`baselines[cost_centre]`)
- **Conditional branching** (`if abs(z) > threshold`)
- **Object creation** overhead (each `iterrows()` yields a new Series)
- **GIL contention** (no thread-level parallelism possible)

...you pay the full interpreter overhead on every single row. Vectorized pandas/numpy can bypass this for simple array operations, but the moment you need per-row conditionals or lookups, you're back in the interpreter loop.

### What Metal GPU offers

Apple Silicon's unified memory architecture eliminates the traditional CPU-to-GPU data transfer bottleneck:

- **Zero-copy buffers** — CPU and GPU share the same physical memory address
- **Massive parallelism** — thousands of GPU threads score transactions simultaneously
- **No interpreter** — Metal shader code compiles to native GPU instructions
- **Sub-microsecond dispatch** — command buffer overhead is negligible

---

## What It Shows

The benchmark demonstrates that **identical scoring logic** can run orders of magnitude faster when moved from an interpreted row-by-row loop to compiled parallel execution on GPU hardware.

This isn't a contrived microbenchmark. The five tasks represent real financial operations:
- Departmental spend aggregation (tasks 1, 4)
- Supplier analysis (task 2)
- Statistical anomaly detection (task 3)
- Running totals for reconciliation (task 5)

The Python implementation uses `df.iterrows()` — the standard approach when business rules can't be vectorized. The Swift + Metal implementation runs the same logic with compiled code and GPU acceleration where it matters most (z-score scoring across millions of rows).

---

## iOS App

The benchmark ships as a native iOS app with a pink/purple neon Kiraa-branded dark theme, animated particle effects, and ambient background music.

### Visual Effects

- **Particle field** — full-screen floating particles that react to benchmark state: slow drift when idle, fast neon streams during runs, burst celebration on completion
- **GPU wave** — triple-layered sine waveform that pulses with processing intensity
- **Data flow pipeline** — animated dot stream showing transactions flowing through the GPU scoring zone, with anomalies glowing red after detection
- **Progress ring** — circular gauge with gradient sweep, glowing tip, and rotating ambient ring during runs
- **Stream visualizer** — 500-cell dot grid simulating live transaction scanning with anomaly flags

### Speedup Banner

The hero element of the dashboard — a large **~96x** speedup multiplier that pops in dramatically when both benchmark results are available. Positioned immediately after the controls so it's the first thing visible after a run.

### Ambient Audio

`kiraa-10m-music.mp3` plays quietly on loop (15% volume, ambient audio session) while the app is running.

---

## The Scoring Logic (Task 3)

Both engines compute identical z-scores for anomaly detection:

```
z = (amount - cost_centre_mean) / cost_centre_std
is_anomaly = |z| > 3.5
```

Each of 12 cost centres has its own baseline mean and standard deviation, computed empirically from the dataset with Bessel's correction (ddof=1).

**Python** scores each row in a `for` loop, hitting a dictionary lookup per record:
```python
for _, row in df.iterrows():
    bl = baselines[row["cost_centre"]]
    z = (row["amount"] - bl["mean"]) / bl["std"]
    if abs(z) > 3.5:
        anomaly_count += 1
```

**Metal** dispatches one GPU thread per transaction — all scored in parallel:
```metal
kernel void scoreTransactions(..., uint gid [[ thread_position_in_grid ]]) {
    Transaction txn = transactions[gid];
    Baseline baseline = baselines[txn.cost_centre_id];
    float z = (txn.amount - baseline.mean) / baseline.std_dev;
    results[gid].is_anomaly = (fabs(z) > z_threshold) ? 1u : 0u;
}
```

---

## Data Pipeline

A single shared CSV ensures both engines process identical data:

```bash
./run_benchmark.sh    # Generate CSV → Python benchmark → copy to app bundle
```

This generates `benchmark_data.csv` (10M rows, seed=42), runs the Python benchmark against it, and copies both the CSV and results JSON into the iOS app bundle. Swift loads the same CSV at runtime.

### Data Format

| Column | Type | Description |
|--------|------|-------------|
| `amount` | float | Transaction amount (normally distributed per cost centre) |
| `cost_centre_id` | int (0-11) | Maps to: RAW_MATERIALS, PACKAGING, LOGISTICS, ... |
| `txn_type_id` | int (0-6) | Maps to: PURCHASE_ORDER, INVOICE_MATCH, ... |
| `supplier_id` | int (1000-9998) | 4-digit supplier identifier |
| `plant_code_id` | int (0-3) | Maps to: GOLD_COAST, SYDNEY, MELBOURNE, BRISBANE |

---

## Quick Start

### 1. Run the full pipeline (recommended)

```bash
./run_benchmark.sh              # Generate CSV → Python benchmark → copy to app bundle
```

### 2. Run the Swift + Metal benchmark

1. Open `TestBench.xcodeproj` in Xcode
2. Select an iPhone/iPad simulator (Apple Silicon required)
3. Build and run
4. Python results load from bundled JSON, Swift loads the shared CSV
5. Tap **Run Benchmark** — Metal GPU scoring runs on-device
6. Speedup multiplier appears with side-by-side comparison

### Alternative: generate data separately

```bash
./generate_data.sh                           # Just generate CSV (copies to app bundle)
./run_benchmark.sh --skip-generate           # Run Python on existing CSV
./run_benchmark.sh --verbose --rows 100000   # Quick verbose run with smaller dataset
```

---

## Test Suite

70 unit tests covering all core logic:

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

```bash
xcodebuild test -project TestBench.xcodeproj -scheme TestBench \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Project Structure

```
TestBench/
├── generate_data.py             # Generate benchmark_data.csv (10M rows)
├── generate_data.sh             # Shell wrapper (generates + copies to app)
├── benchmark_python.py          # Python benchmark (standalone CLI)
├── run_benchmark.sh             # Full pipeline: generate → benchmark → bundle
├── benchmark_results_python.json
│
├── TestBench/                   # iOS app (SwiftUI + Metal)
│   ├── TestBenchApp.swift       # Entry point, dark mode, ambient music
│   ├── ContentView.swift        # Root view
│   ├── Models/
│   │   ├── BenchmarkModels.swift    # Transaction, Baseline, Config, results
│   │   ├── BenchmarkEngine.swift    # High-resolution timing
│   │   └── AudioManager.swift       # Ambient music playback
│   ├── Engines/
│   │   ├── MetalEngine.swift        # Metal GPU compute + benchmark runner
│   │   └── DataGenerator.swift      # Data generation + CSV loading
│   ├── Shaders/
│   │   └── AnomalyScoring.metal     # GPU z-score kernel
│   ├── ViewModels/
│   │   └── BenchmarkViewModel.swift # Orchestrates runs, loads Python JSON
│   ├── Views/
│   │   ├── DashboardView.swift      # Main dashboard layout
│   │   ├── EngineCardView.swift     # Per-engine stats card
│   │   ├── SpeedupBannerView.swift  # Hero speedup multiplier
│   │   ├── ThroughputChartView.swift
│   │   ├── ParticleFieldView.swift  # Ambient particle effects
│   │   ├── GPUWaveView.swift        # Processing waveform
│   │   ├── DataFlowView.swift       # Transaction flow pipeline
│   │   ├── ProgressRingView.swift   # Circular progress gauge
│   │   ├── ArchitectureGridView.swift
│   │   ├── StreamVisualizerView.swift
│   │   └── BenchmarkControlView.swift
│   ├── Theme/
│   │   └── AppTheme.swift           # Pink/purple neon Kiraa palette
│   └── Resources/
│       ├── benchmark_results_python.json
│       └── kiraa-10m-music.mp3      # Ambient background music
│
├── TestBenchTests/              # 70 unit tests
│   ├── TestBenchTests.swift
│   ├── SeededRNGTests.swift
│   ├── DataGeneratorTests.swift
│   ├── ZScoreTests.swift
│   ├── BenchmarkRunnerTests.swift
│   ├── BenchmarkModelsTests.swift
│   └── BenchmarkViewModelTests.swift
│
├── TestBench.xcodeproj/
└── reference/                   # Original reference implementations
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
