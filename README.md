# DeConv HLS Benchmark & Automation

This repository provides an automated pipeline to: (1) generate synthetic benchmark data and HLS configuration headers, (2) build per‑configuration HLS projects (Vitis 2024.1+ or legacy Vivado HLS), (3) run simulation/synthesis, and (4) compare C simulation outputs against golden reference tensors with timestamped history retention.

## Overview

Core components:
1. **Orchestrator Script** (`run_benchmark_and_generate.sh`) – Generates benchmark tensors + headers (with padding `P` embedded) in one step.
2. **Standalone Generator** (`scripts/generate_deconv_configs.py`) – Rebuild headers from a CSV + experimental data (`exp_data`).
3. **Management Script** (`./manage_hls_projects.sh`) – Lifecycle commands: validate, generate, csim, synthesize, cosim, gather, compare, run.
4. **TCL Scripts** (`scripts/*.tcl`) – Project creation, validation, demo, test.
5. **Source Files** (`src/`) – Implementation + testbench.
6. **Comparison System** – `gather-outputs`, `gather-golden`, `compare-results` produce timestamped folders under `comparison_results/` (symlink `latest`).

## 📁 Project Structure (Key Directories)

```
DeConv_hls_benchmark/
├── manage_hls_projects.sh          # Main management script
├── scripts/                        # Benchmark + generator scripts + TCL automation
│   ├── generate_hls_projects.tcl   # Main HLS project generator
│   ├── validate_hls_setup.tcl      # Validation and preview script
│   ├── demo_hls_projects.tcl       # Demo project generator
│   └── test_hls_basic.tcl          # Basic HLS functionality test
│   ├── deconv_benchmark.py         # Benchmark tensor & config CSV generator
│   ├── generate_deconv_configs.py  # Standalone header generator
│   └── run_benchmark_and_generate.sh # Orchestrated benchmark + header pipeline
├── src/                            # Source code and headers
│   ├── deconv_top.cpp              # Main deconvolution implementation
│   ├── deconv.hpp                  # Core deconvolution functions
│   ├── utils.hpp                   # Utility functions
│   └── deconv_tb.cpp               # Testbench
├── generated_configs/              # Generated configuration headers
│   └── deconv_top_*.hpp            # Individual config files
├── outputs/                        # Collected csim output CSVs (PE/SIMD suffix)
├── golden_results/                 # Copied golden reference output CSVs
├── comparison_results/             # Timestamped comparison runs (history retained)
│   ├── <YYYYMMDD_HHMMSS>/          # Individual comparison run directory
│   └── latest -> <YYYYMMDD_HHMMSS>/ # Symlink to most recent run
├── deconv_data/                    # Benchmark data root (exp_data + configs CSV)
└── hls_projects/                   # Generated HLS projects (after generation)
    ├── deconv_*/                   # Individual project directories
    ├── run_all_synthesis.tcl       # Batch synthesis script
    ├── run_all_csim.tcl            # Batch C simulation script
    └── run_all_cosim.tcl           # Batch co-simulation script
```

## 🚀 End-to-End Workflow

### 1. Benchmark Data + Header Generation
```bash
./run_benchmark_and_generate.sh --param-file parameter_space.json
```
Produces:
- `deconv_data/exp_data/` (inputs, weights, outputs, shapes CSVs)
- `deconv_data/configs/deconv_configs.csv` (configuration table)
- `generated_configs/deconv_top_*.hpp` & selector `deconv_top.hpp`

Alternative (headers only):
```bash
python scripts/generate_deconv_configs.py --csv deconv_data/configs/deconv_configs.csv \
   --exp-data deconv_data/exp_data --output generated_configs
```

### 2. Validate
```bash
./manage_hls_projects.sh validate
```

### 3. Generate HLS Projects
```bash
./manage_hls_projects.sh generate
```

### 4. Run Full Simulation + Comparison
```bash
./manage_hls_projects.sh run
```
Sequence: `csim → gather-outputs → gather-golden → compare-results`

### 5. Inspect Results
```bash
ls comparison_results/latest
```

### Optional
```bash
./manage_hls_projects.sh synthesize   # Synthesis
./manage_hls_projects.sh cosim        # Co-simulation
```

## Configuration Parameters

Each deconvolution configuration is defined by:

- **K**: Kernel size
- **S**: Stride
- **H**: Input feature map height  
- **W**: Input feature map width
- **CI**: Input channels
- **CO**: Output channels
- **P**: Padding (derived as K-S)

Additional HLS-specific parameters:
- **PE**: Processing elements (parallelization factor for output channels)
- **SIMD**: SIMD factor (parallelization factor for input channels)

## Generated HLS Projects

Each generated project contains:

### Project Structure
```
deconv_K3_S1_H3_W3_CI1_CO3/
├── deconv_top.hpp              # Configuration-specific header
├── deconv_top.cpp              # Top-level function
├── deconv.hpp                  # Core implementation
├── utils.hpp                   # Utilities
├── deconv_tb.cpp               # Testbench
├── solution1_PE1_SIMD1/        # HLS solution 1
├── solution2_PE3_SIMD1/        # HLS solution 2 (if applicable)
└── ...
```

## Result Comparison & Golden Data

Commands:
```bash
./manage_hls_projects.sh gather-outputs   # Collect csim CSVs into outputs/
./manage_hls_projects.sh gather-golden    # Copy golden reference CSVs from deconv_data/exp_data → golden_results/
./manage_hls_projects.sh compare-results  # Diff outputs/ vs golden_results/ → comparison_results/<timestamp>/
```
Use `run` to chain all of the above after `csim`. Each comparison run is stored in a uniquely timestamped directory; the symlink `comparison_results/latest` always points to the most recent run. Cleaning preserves this history.

## Customization


### Adding New Configurations
1. Add new configurations to the CSV file or modify the notebook
2. Run the notebook to generate new header files
3. Run the HLS project generator to create new projects

### Custom PE/SIMD Settings
The script automatically generates PE/SIMD configurations based on:
- PE values: Divisors of output channels (CO)
- SIMD values: Divisors of input channels (CI)

You can modify the `generate_pe_simd_configs` function in the notebook to change this behavior.

## Cleaning Policy

```bash
./manage_hls_projects.sh clean
```
Removes: `hls_projects/`, `hls_projects_demo/`, `test_hls_project/`, `outputs/`, `golden_results/`
Preserves: `comparison_results/` (historical validation runs)


## Output & Comparison Artifacts

After running the complete flow, you'll have:

1. **Generated Projects**: Individual HLS projects in `hls_projects/`
2. **Synthesis Scripts**: Batch synthesis script for all projects (`run_all_synthesis.tcl`)
3. **Simulation Scripts**: 
   - C simulation script for all projects (`run_all_csim.tcl`)
   - Co-simulation script for all projects (`run_all_cosim.tcl`)
4. **Report Scripts**: Template for extracting synthesis reports (`extract_reports.tcl`)
5. **Log Files**: 
   - Project generation logs
   - C simulation results (`csim_results.log`)
   - Co-simulation results (`cosim_results.log`)

## Performance & Verification

The generated projects support complete HLS verification workflow:

### Functional Verification
- **C Simulation**: Verify algorithmic correctness before synthesis
- **Co-simulation**: Validate RTL behavior matches C model
- **Automated Testing**: Batch simulation across all configurations

### Analysis Workflow
1. Run `./manage_hls_projects.sh csim` for functional verification
2. Run `./manage_hls_projects.sh synthesize` for resource analysis
3. Run `./manage_hls_projects.sh cosim` for RTL verification
4. Use `extract_reports.tcl` script for automated report collection

## Documentation Index
Extended docs have moved under `docs/`:
- `docs/QUICK_START.md` – Condensed modern quick start.
- `docs/README_GENERATOR.md` – Standalone generator deep dive.
- `docs/SCRIPTS_REORGANIZATION.md` – Evolution & layout.
- `docs/VITIS_2024_MIGRATION.md` – Tooling migration notes.
- `docs/todo.md` – Backlog items.
