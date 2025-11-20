#!/usr/bin/env python3
"""
PyTorch Deconvolution (ConvTranspose2d) Benchmark Data Generator
===============================================================

This script replicates and extends the functionality of the Jupyter notebook
`deconv_pytorch.ipynb` by generating synthetic input, weight, and output data
for a sweep of ConvTranspose2d (deconvolution) layer configurations defined
in a JSON parameter space file.

Outputs:
  - configs/deconv_configs.csv : CSV listing all tested parameter combinations.
  - exp_data/*_input.csv       : Flattened input tensor values.
  - exp_data/*_weights.csv     : Flattened weight tensor values.
  - exp_data/*_output.csv      : Flattened output tensor values (channel-last order).
  - exp_data/*_shapes.csv      : Shapes of tensors (input, weights, output).

JSON Parameter Space Format (example `parameter_space.json`):
{
  "input_size":   [3, 5],
  "in_channels":  [1],
  "out_channels": [3],
  "kernel_size":  [3],
  "stride":       [1],
  "padding":      [1, 2]
}
Keys become Cartesian product dimensions.

CLI Usage:
  python deconv_benchmark.py \
      --param-file parameter_space.json \
      --out-dir deconv_data \
      --seed 42 \
      --input-range 0 1 \
      --weight-range 0 255 \
      --device cpu \
      --no-clean

Options:
  --param-file    Path to JSON parameter space (required).
  --out-dir       Root output directory (default: deconv_data).
  --seed          Random seed for reproducibility (default: 1234).
  --input-range   Two ints: inclusive low high for input tensor values (default: 1 1 reproducing notebook behavior).
  --weight-range  Two ints: inclusive low high for weight tensor values (default: 0 255).
  --device        Torch device (cpu / cuda) (default: cpu).
  --bias          Include bias in layer (default: False like notebook; if True, saves *_bias.csv and bias shape).
  --clean / --no-clean  Remove existing output directory before generation (default: --clean).
  --limit         Optional int to limit number of configurations processed (debugging).
  --dry-run       List configurations without generating tensors.
  --verbose       Extra logging.

Notes:
  - Input tensors and weights are sampled with torch.randint in the specified ranges.
  - Output tensor is saved in channel-last flattened order: (H_out, W_out, out_channels).
  - Bias disabled by default (original notebook used bias=False for layer construction).
  - Shapes CSV encodes dimensions using 'x' separators.

Future improvements (not implemented):
  - Parallel generation via multiprocessing.
  - Additional export formats (NPY, PT).
  - Quantization or scaling to fixed-point domains.
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import shutil
import sys
from dataclasses import dataclass
from typing import Dict, List, Tuple

import torch
import torch.nn as nn
import numpy as np
import csv

# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------
@dataclass
class DeconvConfig:
    input_size: int
    in_channels: int
    out_channels: int
    kernel_size: int
    stride: int
    padding: int

    def to_dict(self) -> Dict[str, int]:
        return {
            "input_size": self.input_size,
            "in_channels": self.in_channels,
            "out_channels": self.out_channels,
            "kernel_size": self.kernel_size,
            "stride": self.stride,
            "padding": self.padding,
        }

    def base_filename(self, root: str) -> str:
        return os.path.join(
            root,
            "exp_data",
            f"deconv_{self.input_size}x{self.input_size}_in{self.in_channels}_out{self.out_channels}_k{self.kernel_size}_s{self.stride}_p{self.padding}",
        )

# ---------------------------------------------------------------------------
# Core functionality
# ---------------------------------------------------------------------------

def load_parameter_space(path: str) -> Dict[str, List[int]]:
    with open(path, "r") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("Parameter space JSON must be an object mapping names to lists")
    for k, v in data.items():
        if not isinstance(v, list):
            raise ValueError(f"Parameter '{k}' must map to a list of values")
    return data


def enumerate_configs(parameter_space: Dict[str, List[int]]) -> List[DeconvConfig]:
    required_keys = ["input_size", "in_channels", "out_channels", "kernel_size", "stride", "padding"]
    for k in required_keys:
        if k not in parameter_space:
            raise KeyError(f"Missing required parameter key: {k}")
    names = required_keys
    values = [parameter_space[k] for k in names]
    configs = [DeconvConfig(*combo) for combo in itertools.product(*values)]
    return configs


def write_configs_csv(path: str, configs: List[DeconvConfig]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "input_size", "in_channels", "out_channels", "kernel_size", "stride", "padding"
        ])
        writer.writeheader()
        for cfg in configs:
            writer.writerow(cfg.to_dict())


def init_layer(cfg: DeconvConfig, bias: bool, device: torch.device) -> nn.ConvTranspose2d:
    layer = nn.ConvTranspose2d(
        in_channels=cfg.in_channels,
        out_channels=cfg.out_channels,
        kernel_size=cfg.kernel_size,
        stride=cfg.stride,
        padding=cfg.padding,
        output_padding=0,
        dilation=1,
        groups=1,
        bias=bias,
    ).to(device)
    return layer


def gen_tensor_int(shape: Tuple[int, ...], low: int, high: int, device: torch.device) -> torch.Tensor:
    # torch.randint is exclusive on high, so add 1 for inclusive semantics
    if low > high:
        raise ValueError("low cannot be greater than high")
    return torch.randint(low, high + 1, shape, dtype=torch.int32, device=device).to(torch.float32)


def save_flat_csv(path: str, tensor: torch.Tensor) -> None:
    arr = tensor.detach().cpu().numpy().reshape(-1).astype(np.int32)
    np.savetxt(path, arr, delimiter=",", fmt="%d")


def save_shapes_csv(path: str, shapes: Dict[str, Tuple[int, ...]]) -> None:
    with open(path, "w") as f:
        for name, shape in shapes.items():
            f.write(f"{name},{'x'.join(str(d) for d in shape)}\n")

# ---------------------------------------------------------------------------
# Generation loop
# ---------------------------------------------------------------------------

def generate_data(
    configs: List[DeconvConfig],
    out_dir: str,
    input_range: Tuple[int, int],
    weight_range: Tuple[int, int],
    seed: int,
    device_str: str,
    bias: bool,
    limit: int | None = None,
    dry_run: bool = False,
    verbose: bool = False,
) -> None:
    if limit is not None:
        configs = configs[:limit]
    device = torch.device(device_str)
    torch.manual_seed(seed)
    np.random.seed(seed)

    # Prepare directories
    configs_csv = os.path.join(out_dir, "configs", "deconv_configs.csv")
    write_configs_csv(configs_csv, configs)
    os.makedirs(os.path.join(out_dir, "exp_data"), exist_ok=True)
    print(f"Saved configuration table: {configs_csv}")

    if dry_run:
        print("Dry-run: listing configurations only (no tensors generated).")
        for i, cfg in enumerate(configs, 1):
            print(f"[{i}/{len(configs)}] {cfg}")
        return

    total = len(configs)
    for idx, cfg in enumerate(configs, 1):
        if verbose:
            print(f"Preparing data for configuration {idx}/{total}: {cfg}")
        base = cfg.base_filename(out_dir)

        # Initialize layer
        layer = init_layer(cfg, bias=bias, device=device)

        # Overwrite weights and (optional) bias with random ints
        with torch.no_grad():
            weight_tensor = gen_tensor_int(tuple(layer.weight.shape), *weight_range, device=device)
            layer.weight.copy_(weight_tensor)
            if bias and layer.bias is not None:
                bias_tensor = gen_tensor_int(tuple(layer.bias.shape), *weight_range, device=device)
                layer.bias.copy_(bias_tensor)

        # Generate input tensor
        input_tensor = gen_tensor_int((1, cfg.in_channels, cfg.input_size, cfg.input_size), *input_range, device=device)

        # Forward pass
        with torch.no_grad():
            output_tensor = layer(input_tensor)

        # Save tensors
        save_flat_csv(f"{base}_input.csv", input_tensor)
        save_flat_csv(f"{base}_weights.csv", layer.weight)
        if bias and layer.bias is not None:
            save_flat_csv(f"{base}_bias.csv", layer.bias)

        # Output rearranged to (H_out, W_out, C_out) then flattened
        out_rearranged = output_tensor.detach().squeeze(0).permute(1, 2, 0).contiguous()
        save_flat_csv(f"{base}_output.csv", out_rearranged)

        # Shapes CSV
        shapes = {
            "input_shape": tuple(input_tensor.shape),
            "weights_shape": tuple(layer.weight.shape),
            "output_shape": tuple(output_tensor.shape),
        }
        if bias and layer.bias is not None:
            shapes["bias_shape"] = tuple(layer.bias.shape)
        save_shapes_csv(f"{base}_shapes.csv", shapes)

        if verbose:
            print(f"Saved data set: {base}")
        else:
            # lightweight progress indicator
            print(f"[{idx}/{total}] {base.split(os.sep)[-1]}")

    print(f"Generation complete. Data root: {out_dir}")

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def parse_args(argv: List[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate benchmark data for ConvTranspose2d parameter sweeps.")
    p.add_argument("--param-file", required=True, help="JSON file defining parameter space")
    p.add_argument("--out-dir", default="deconv_data", help="Root output directory")
    p.add_argument("--seed", type=int, default=1234, help="Random seed")
    p.add_argument("--input-range", nargs=2, type=int, default=[1, 1], metavar=("LOW", "HIGH"), help="Inclusive range for input values")
    p.add_argument("--weight-range", nargs=2, type=int, default=[0, 255], metavar=("LOW", "HIGH"), help="Inclusive range for weight (and bias) values")
    p.add_argument("--device", default="cpu", choices=["cpu", "cuda"], help="Torch device")
    p.add_argument("--bias", action="store_true", help="Include bias in layer and save bias data")
    p.add_argument("--clean", dest="clean", action="store_true", help="Remove existing output directory before generation (default)")
    p.add_argument("--no-clean", dest="clean", action="store_false", help="Do not remove existing output directory before generation")
    p.set_defaults(clean=True)
    p.add_argument("--limit", type=int, help="Limit number of configurations processed (debug)")
    p.add_argument("--dry-run", action="store_true", help="Only list configurations, do not generate tensors")
    p.add_argument("--verbose", action="store_true", help="Verbose logging")
    return p.parse_args(argv)

# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def main(argv: List[str]) -> None:
    args = parse_args(argv)

    param_space = load_parameter_space(args.param_file)
    configs = enumerate_configs(param_space)
    print(f"Total configurations: {len(configs)}")

    if args.clean and not args.dry_run and os.path.isdir(args.out_dir):
        print(f"Removing existing output directory: {args.out_dir}")
        shutil.rmtree(args.out_dir)

    os.makedirs(args.out_dir, exist_ok=True)

    generate_data(
        configs=configs,
        out_dir=args.out_dir,
        input_range=(args.input_range[0], args.input_range[1]),
        weight_range=(args.weight_range[0], args.weight_range[1]),
        seed=args.seed,
        device_str=args.device,
        bias=args.bias,
        limit=args.limit,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )


if __name__ == "__main__":
    main(sys.argv[1:])
