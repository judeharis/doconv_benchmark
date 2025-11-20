#!/usr/bin/env bash

# Sequential Deconvolution Data + Config Generation Orchestrator
# -----------------------------------------------------------------------------
# This script runs `deconv_benchmark.py` to generate synthetic benchmark data
# (inputs, weights, outputs, shapes, and configuration CSV), then invokes
# `generate_deconv_configs.py` to create HLS-ready header files for each
# configuration including padding (P) in the filenames.
#
# Requirements:
#   - Python 3 environment with torch, numpy
#   - Files: scripts/deconv_benchmark.py, scripts/generate_deconv_configs.py
#
# Usage examples:
#   ./run_benchmark_and_generate.sh --param-file parameter_space.json
#   ./run_benchmark_and_generate.sh --param-file parameter_space.json --out-dir my_data
#   ./run_benchmark_and_generate.sh --param-file parameter_space.json --config-dir my_headers --seed 42
#   PYTHON=python3.11 ./run_benchmark_and_generate.sh --param-file parameter_space.json --device cuda --bias
#   ./run_benchmark_and_generate.sh --param-file parameter_space.json --limit 1 --dry-run
#
# Common options passed through to benchmark:
#   --seed, --device, --bias, --limit, --dry-run, --no-clean
#
# After successful benchmark generation this script locates:
#   <out-dir>/configs/deconv_configs.csv
# and uses it (plus <out-dir>/exp_data) for config header generation.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

PYTHON_BIN="${PYTHON:-python3}"  # override via env PYTHON=<executable>

param_file=""
out_dir="deconv_data"
config_dir="generated_configs"
seed="1"
device="cpu"
bias="false"
clean="true"  # default behavior removes existing out_dir
limit=""
dry_run="false"
input_low="1"
input_high="1"
weight_low="0"
weight_high="255"

print_usage() {
  cat <<USAGE
Sequential Deconvolution Benchmark + HLS Config Generation

Usage: $0 [--param-file parameter_space.json] [options]

Parameter Space:
  --param-file <file>     JSON parameter space describing sweep (default: PROJECT_ROOT/parameter_space.json if present)

Benchmark Options:
  --out-dir <dir>         Output root for benchmark data (default: deconv_data)
  --seed <int>            Random seed (default: 1)
  --device <cpu|cuda>     Torch device (default: cpu)
  --bias                  Enable bias parameter in ConvTranspose2d (default: off)
  --limit <int>           Limit number of configurations (debug)
  --dry-run               List configurations only; skip tensor generation & header generation
  --no-clean              Do not remove existing out-dir before generation
  --input-range <L H>     Inclusive range for input tensor values (default: 1 1)
  --weight-range <L H>    Inclusive range for weight (and bias) values (default: 0 255)

Config Generation Options:
  --config-dir <dir>      Directory to write generated header files (default: generated_configs)

Environment:
  PYTHON=<exe>            Override Python executable (default: python3)

Examples:
  $0 --param-file parameter_space.json
  $0 --param-file parameter_space.json --out-dir benchmark_run --config-dir hls_headers
  PYTHON=python3.11 $0 --param-file parameter_space.json --device cuda --bias
  $0 --param-file parameter_space.json --limit 2 --dry-run

Outputs:
  Benchmark data: <out-dir>/exp_data/* (input, weights, output CSVs + shapes)
  Config table:   <out-dir>/configs/deconv_configs.csv
  Generated HLS headers: <config-dir>/deconv_top_*.hpp and selector deconv_top.hpp

USAGE
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --param-file)
      param_file="$2"; shift 2 ;;
    --out-dir)
      out_dir="$2"; shift 2 ;;
    --config-dir)
      config_dir="$2"; shift 2 ;;
    --seed)
      seed="$2"; shift 2 ;;
    --device)
      device="$2"; shift 2 ;;
    --bias)
      bias="true"; shift 1 ;;
    --limit)
      limit="$2"; shift 2 ;;
    --dry-run)
      dry_run="true"; shift 1 ;;
    --no-clean)
      clean="false"; shift 1 ;;
    --input-range)
      if [[ $# -lt 3 ]]; then echo "Error: --input-range requires two integers" >&2; exit 1; fi
      input_low="$2"; input_high="$3"; shift 3 ;;
    --weight-range)
      if [[ $# -lt 3 ]]; then echo "Error: --weight-range requires two integers" >&2; exit 1; fi
      weight_low="$2"; weight_high="$3"; shift 3 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 1 ;;
  esac
done

# Resolve default parameter space if not provided
if [[ -z "$param_file" ]]; then
  if [[ -f "${PROJECT_ROOT}/parameter_space.json" ]]; then
    param_file="${PROJECT_ROOT}/parameter_space.json"
    echo "[INFO] Using default parameter space file: $param_file"
  else
    echo "Error: parameter_space.json not found and --param-file not supplied" >&2
    print_usage
    exit 1
  fi
fi
if [[ ! -f "$param_file" ]]; then
  echo "Error: Parameter space file not found: $param_file" >&2
  exit 1
fi

# Resolve absolute paths
param_file="$(realpath "$param_file")"
out_dir="$(realpath "$out_dir")"
config_dir="$(realpath "$config_dir")"

echo "[INFO] Python executable : $PYTHON_BIN"
echo "[INFO] Parameter file    : $param_file"
echo "[INFO] Benchmark out-dir : $out_dir"
echo "[INFO] Headers config-dir: $config_dir"
echo "[INFO] Seed              : $seed"
echo "[INFO] Device            : $device"
echo "[INFO] Bias enabled      : $bias"
echo "[INFO] Clean out-dir     : $clean"
echo "[INFO] Dry-run           : $dry_run"
echo "[INFO] Input range       : $input_low $input_high"
echo "[INFO] Weight range      : $weight_low $weight_high"
if [[ -n "$limit" ]]; then
  echo "[INFO] Limit configs     : $limit"
fi
echo "------------------------------------------------------------"

mkdir -p "$config_dir"

# Construct benchmark command (array form for safe quoting)
benchmark_cmd=(
  "$PYTHON_BIN" "$SCRIPT_DIR/scripts/deconv_benchmark.py"
  --param-file "$param_file"
  --out-dir "$out_dir"
  --seed "$seed"
  --device "$device"
  --input-range "$input_low" "$input_high"
  --weight-range "$weight_low" "$weight_high"
)

[[ "$bias" == "true" ]] && benchmark_cmd+=(--bias)
[[ "$clean" == "false" ]] && benchmark_cmd+=(--no-clean) || benchmark_cmd+=(--clean)
[[ -n "$limit" ]] && benchmark_cmd+=(--limit "$limit")
[[ "$dry_run" == "true" ]] && benchmark_cmd+=(--dry-run)

echo "[RUN] Benchmark generation..."
printf '       '; printf '%q ' "${benchmark_cmd[@]}"; echo
"${benchmark_cmd[@]}"
echo "------------------------------------------------------------"

csv_path="$out_dir/configs/deconv_configs.csv"
exp_data_dir="$out_dir/exp_data"

if [[ ! -f "$csv_path" ]]; then
  if [[ "$dry_run" == "true" ]]; then
    echo "[INFO] Dry-run mode: CSV not generated; skipping header generation."; exit 0
  fi
  echo "[ERROR] Expected configuration CSV not found: $csv_path" >&2
  exit 1
fi

if [[ ! -d "$exp_data_dir" ]]; then
  echo "[ERROR] Expected exp_data directory not found: $exp_data_dir" >&2
  exit 1
fi

echo "[INFO] Found configuration CSV: $csv_path"
echo "[INFO] Found experimental data directory: $exp_data_dir"
echo "------------------------------------------------------------"

echo "[RUN] Generating HLS configuration headers..."
gen_cmd=(
  "$PYTHON_BIN" "$SCRIPT_DIR/scripts/generate_deconv_configs.py"
  --csv "$csv_path"
  --exp-data "$exp_data_dir"
  --output "$config_dir"
)
printf '       '; printf '%q ' "${gen_cmd[@]}"; echo
"${gen_cmd[@]}"
echo "------------------------------------------------------------"

echo "[DONE] Benchmark + header generation complete." 
echo "[RESULT] Benchmark data root : $out_dir"
echo "[RESULT] Generated headers   : $config_dir"
echo "[HINT]  To list configs: ls -1 $config_dir/deconv_top_K*_S*_H*_W*_CI*_CO*_P*.hpp"
echo "[HINT]  Selector header: $config_dir/deconv_top.hpp"
echo "[HINT]  Re-run with different sweep by adjusting parameter_space JSON."

exit 0
