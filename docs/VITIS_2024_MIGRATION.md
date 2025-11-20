# Vitis 2024.1 Migration & Current Tooling

## Status
Primary flow targets **Vitis 2024.1+**; legacy Vivado HLS still supported automatically. Management script detects `vitis-run` first, then falls back.

## Key Command Mapping
| Legacy | Preferred |
|--------|----------|
| `vivado_hls -f script.tcl` | `vitis-run --mode hls --tcl script.tcl` |
| `vivado_hls` interactive | `vitis-run --mode hls` then `source script.tcl` |

## End‑to‑End Pipeline With Vitis
```bash
# Data + headers
./scripts/run_benchmark_and_generate.sh --param-file parameter_space.json
# Project generation
./manage_hls_projects.sh generate
# Functional simulation + golden comparison
./manage_hls_projects.sh run
# (Optional) synthesis / cosim
./manage_hls_projects.sh synthesize
./manage_hls_projects.sh cosim
```

## Environment Setup
```bash
# Vitis 2024.1+
source /path/to/Vitis/settings64.sh
# (Optional legacy fallback)
source /path/to/Vivado/settings64.sh
```

## Device & Constraints
- Target: `xczu3eg-sbva484-1-i`
- Clock: 5ns (200 MHz)
- Interfaces: AXI Stream IO, `ap_ctrl_none`
- Optimization baseline: `#pragma HLS dataflow`

## Migration Enhancements Since Initial Port
- Added `run` meta command binding simulation + comparison.
- Incorporated padding `P` in config filenames (future‑proof parameterization).
- Local data model (`deconv_data/`) ensuring golden sources reproducible pre‑synthesis.
- Timestamped comparison history for regression tracking.

## Troubleshooting
| Symptom | Action |
|---------|--------|
| Tool not found | Verify `vitis-run` in PATH; source settings script. |
| Unsupported device | Edit `TARGET_DEVICE` in `scripts/generate_hls_projects.tcl`. |
| Clock constraint unmet | Adjust `CLOCK_PERIOD` or investigate loop pragmas. |
| Missing headers | Re-run the orchestrator or generator script. |
| Comparison empty | Ensure `csim` ran; check `outputs/` population. |

## Next Migration Steps (Optional)
- Introduce QoR summary extraction integrated into comparison runs.
- Add automatic export of utilization / latency JSON for CI dashboards.
- Evaluate upgrade to newer Vitis release once stable.
