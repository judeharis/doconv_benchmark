# Scripts Reorganization & Evolution

## Original Reorganization
- Introduced `scripts/` directory; moved all HLS TCL automation inside.
- Kept root clean: `manage_hls_projects.sh`, notebook (legacy), orchestrator script, headers, data.
- Added path normalization variables (`BASE_DIR`, `CONFIG_DIR`, etc.) inside TCL.

## Subsequent Additions
| Feature | Purpose |
|---------|---------|
| `run_benchmark_and_generate.sh` | One command to produce benchmark tensors + config headers including padding.
| Padding `P` in filenames | Unambiguous config naming and macro generation.
| Golden gathering (`gather-golden`) | Copies reference output CSVs from local `deconv_data/exp_data` into `golden_results/`.
| Output gathering (`gather-outputs`) | Collects csim outputs with PE/SIMD suffix into `outputs/`.
| Comparison (`compare-results`) | Compares outputs vs golden; writes timestamped run directory.
| `run` meta command | Automates `csim → gather-outputs → gather-golden → compare-results`.
| Timestamped comparison history | Auditable evolution; `latest` symlink convenience.
| Clean policy preserving comparisons | Avoid accidental deletion of historical validation results.
| Removal of `test_hls_project` in clean | Ensures a fully reset environment.

## Current Script Landscape
```
scripts/
  generate_hls_projects.tcl
  validate_hls_setup.tcl
  demo_hls_projects.tcl
  test_hls_basic.tcl
  deconv_benchmark.py
  generate_deconv_configs.py
  run_benchmark_and_generate.sh
```
Generated (after project creation):
```
hls_projects/run_all_synthesis.tcl
hls_projects/run_all_csim.tcl
hls_projects/run_all_cosim.tcl
```

## Design Principles
1. Deterministic artifacts (seed, explicit ranges, padding encoded).
2. Clear separation: data generation vs project creation vs verification.
3. Auditable results (timestamp folders, preserved history).
4. Minimal manual steps (`run` consolidates simulation + comparison).
5. Backward compatibility (Vitis preferred, Vivado fallback).

## Maintenance Tips
- Add new config dimensions → update benchmark + generator; ensure filenames include new tokens if needed.
- Extend comparison metrics → augment `compare-results` logic; keep CSV summary consistent.
- Large sweeps: consider limiting with `--limit` in orchestrator for quick iteration.
- Keep docs up to date when introducing new commands or data paths.

## Future Ideas
- Integrate resource & latency report collation into comparison timestamp directories.
- Add PyTorch correctness check harness (see `todo.md`).
- Introduce JSON summary of each comparison run for downstream dashboards.
