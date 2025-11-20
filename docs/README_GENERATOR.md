# Deconvolution Configuration Generator (Detailed)

This standalone Python script `scripts/generate_deconv_configs.py` creates HLS configuration header files for each deconvolution design produced by the benchmark sweep.

## What's New vs Early Revision
- Includes padding parameter `P` in every filename and macro.
- Designed to consume the CSV emitted by `run_benchmark_and_generate.sh` in `deconv_data/configs/deconv_configs.csv`.
- Automatically pulls weight/input/output golden data from `deconv_data/exp_data` for each configuration if present.
- Emphasizes reproducibility: deterministic seed path through the orchestrator.

## Typical End‑to‑End Flow
```bash
# 1. Generate benchmark data + headers
./scripts/run_benchmark_and_generate.sh --param-file parameter_space.json

# 2. (Optional) Re-generate headers only with new output location
python scripts/generate_deconv_configs.py \
  --csv deconv_data/configs/deconv_configs.csv \
  --exp-data deconv_data/exp_data \
  --output generated_configs
```

## CLI Summary
Run `python scripts/generate_deconv_configs.py --help` for full details.

Key flags:
- `--csv <file>`: Configuration table (required if not found by default).
- `--exp-data <dir>`: Directory with per‑config CSV tensors (inputs/weights/output).
- `--output <dir>`: Destination for headers (default: `generated_configs`).

## CSV Format
Columns: `kernel_size,stride,input_size,in_channels,out_channels,padding`
Each row defines one logical configuration. Padding may be provided; if omitted earlier versions computed `P = K - S`.

## Naming Pattern
```
deconv_top_K{K}_S{S}_H{H}_W{W}_CI{CI}_CO{CO}_P{P}.hpp
```
Example: `deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp`.

## Selector Header
A unified `deconv_top.hpp` is generated listing all configurations. You can select by index or by full macro name:
```cpp
#define DECONV_CFG_IDX_0
#include "generated_configs/deconv_top.hpp"
// or
#define DECONV_CFG_K3_S1_H3_W3_CI1_CO3_P2
#include "generated_configs/deconv_top.hpp"
```

## PE / SIMD Enumeration
- PE candidates: divisors of CO.
- SIMD candidates: divisors of CI.
- At least one `(PE=1, SIMD=1)` always emitted.

## Weight Loading Rules
- Accepts decimal or hex tokens (e.g. `0x1F`).
- Non‑numeric tokens ignored.
- Values clamped to 8‑bit range.
- Falls back to sequential synthetic pattern if file missing.

## Error Handling
- Missing CSV → abort with message.
- Missing exp_data weight file → continue with synthetic values.
- Malformed CSV row → skipped (reported).

## Advantages Over Notebook
- Scriptable / CI friendly.
- Deterministic outputs.
- Smaller diffs in version control.

## Next Step After Generation
Use `./manage_hls_projects.sh validate` then `generate` to form HLS projects; or run the full simulation + comparison pipeline via `./manage_hls_projects.sh run` (after headers + data exist).
