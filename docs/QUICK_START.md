# Quick Start (Updated Pipeline)

## Goal
Generate benchmark data, produce HLS headers, create projects, simulate, gather results, and compare against golden outputs — all with minimal commands.

## 0. Prerequisites
- Vitis 2024.1+ (preferred) or Vivado HLS in PATH for project generation / csim.
- Python 3 (with torch & numpy) for benchmark script.
- `parameter_space.json` in project root (or supply via `--param-file`).

## 1. Benchmark + Header Generation
```bash
./run_benchmark_and_generate.sh --param-file parameter_space.json
```
Outputs:
- `deconv_data/exp_data/` (inputs, weights, outputs, shapes CSVs)
- `deconv_data/configs/deconv_configs.csv` (table of configurations)
- `generated_configs/deconv_top_*.hpp` + `generated_configs/deconv_top.hpp`

## 2. Validate
```bash
./manage_hls_projects.sh validate
```
Shows what would be generated, confirms headers present, lists PE/SIMD options.

## 3. Generate Projects
```bash
./manage_hls_projects.sh generate
```
Creates one HLS project per configuration plus solutions for each PE/SIMD tuple.

## 4. Run End‑to‑End Simulation + Comparison
```bash
./manage_hls_projects.sh run
```
Expands to:
```
csim → gather-outputs → gather-golden → compare-results
```
Results placed under `comparison_results/<TIMESTAMP>/` (symlink `comparison_results/latest` points to newest). Raw simulation CSVs collected into `outputs/`.

## 5. Inspect Comparison
```bash
ls comparison_results/latest
```
Look for summary CSV or textual diff report. Historical runs retained.

## 6. Optional Steps
- Synthesis: `./manage_hls_projects.sh synthesize`
- Co‑simulation: `./manage_hls_projects.sh cosim`
- Individual gathering (if not using run):
  - `./manage_hls_projects.sh gather-outputs`
  - `./manage_hls_projects.sh gather-golden`
  - `./manage_hls_projects.sh compare-results`

## Cleaning Policy
```bash
./manage_hls_projects.sh clean
```
Removes: `hls_projects/`, `hls_projects_demo/`, `test_hls_project/`, `outputs/`, `golden_results/`
Preserves (history): `comparison_results/`

## Status & Listing
```bash
./manage_hls_projects.sh status
./manage_hls_projects.sh list
```

## Filename Convention (Headers)
```
deconv_top_K{K}_S{S}_H{H}_W{W}_CI{CI}_CO{CO}_P{P}.hpp
```
Padding `P` is explicitly encoded. Selector header: `generated_configs/deconv_top.hpp`.

## Troubleshooting Quick Hints
- Missing golden data? Ensure you ran the orchestrator; expect `deconv_data/exp_data/output_*.csv`.
- `compare-results` says missing outputs: run `csim` (or `run`) first.
- Empty comparison folder: verify PE/SIMD naming matches outputs.
- Clean removed projects unexpectedly: re‑run steps 1–3.

## Next
Check `docs/README_GENERATOR.md` for generator details or `docs/VITIS_2024_MIGRATION.md` for toolchain notes.
