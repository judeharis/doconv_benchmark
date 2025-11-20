# Documentation Index

This folder collects all auxiliary documentation for the DeConv HLS benchmark. The root `README.md` gives the high‑level overview; these docs dive deeper into specific topics.

## Contents

- `QUICK_START.md` – Minimal, updated quick start with the new end‑to‑end flow.
- `README_GENERATOR.md` – Standalone Python generator + selector header details.
- `SCRIPTS_REORGANIZATION.md` – History of script layout & rationale.
- `VITIS_2024_MIGRATION.md` – Notes on migrating to / using Vitis 2024.1+ with fallback.
- `todo.md` – Small backlog / open tasks.

## Key New Concepts (Since Initial Version)

- Padded configuration filenames include padding `P` (e.g. `deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp`).
- Orchestrator script `scripts/run_benchmark_and_generate.sh` produces benchmark data (`deconv_data/`) then headers (`generated_configs/`).
- Local golden data copied from `deconv_data/exp_data` via `./manage_hls_projects.sh gather-golden`.
- Timestamped comparison runs in `comparison_results/<YYYYMMDD_HHMMSS>/` with a `latest` symlink.
- End‑to‑end `run` command: `csim → gather-outputs → gather-golden → compare-results`.

## Reading Order (Suggested)
1. Quick start.
2. Generator details.
3. Migration notes (if tool versions matter).
4. Script reorganization (if maintaining project).

## See Also
- Root `README.md` for overall architecture and usage patterns.
