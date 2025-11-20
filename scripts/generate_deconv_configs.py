#!/usr/bin/env python3
"""
Deconvolution Configuration Generator

This script generates deconv_top.hpp files with configurable parameters 
for HLS deconvolution implementations.

Usage:
    python generate_deconv_configs.py
    python generate_deconv_configs.py --csv /path/to/config.csv
    python generate_deconv_configs.py --output ./my_configs
"""

import argparse
import csv
import sys
from pathlib import Path
from typing import List, Tuple, Dict


class DeconvConfig:
    """Configuration class for deconvolution parameters"""
    
    def __init__(self, K: int, S: int, H: int, W: int, CI: int, CO: int, P: int = None):
        self.K = K      # Kernel size
        self.S = S      # Stride
        self.H = H      # Input height
        self.W = W      # Input width
        self.CI = CI    # Input channels
        self.CO = CO    # Output channels
        self.P = P if P is not None else K - S  # Padding (derived if not provided)
    
    def validate(self) -> bool:
        """Validate parameter constraints"""
        if self.K <= 0 or self.S <= 0 or self.H <= 0 or self.W <= 0:
            return False
        if self.CI <= 0 or self.CO <= 0:
            return False
        if self.P < 0:
            return False
        return True
    
    def __str__(self):
        return f"K={self.K}, S={self.S}, H={self.H}, W={self.W}, CI={self.CI}, CO={self.CO}, P={self.P}"


def load_weights_from_csv(weights_path: str) -> List[int]:
    """Load flat list of weights from a CSV file. 
    
    Supports comma/whitespace separated, decimal or hex (0x..) values.
    Non-numeric tokens are ignored.
    """
    text = Path(weights_path).read_text().strip()
    tokens = []
    for line in text.splitlines():
        parts = [p for p in line.replace(',', ' ').split() if p]
        tokens.extend(parts)
    
    values = []
    for t in tokens:
        try:
            v = int(t, 16) if t.lower().startswith("0x") else int(float(t))
            values.append(v & 0xFF)  # clamp to 8-bit
        except Exception:
            # ignore non-numeric tokens (headers, etc.)
            continue
    return values


def generate_kernel_weights(config: DeconvConfig, pe: int = 1, simd: int = 1, 
                            weights: List[int] = None) -> str:
    """Generate kernel weight array in C++ format.
    
    If weights is provided, use it; otherwise generate a simple incremental pattern.
    """
    outer_dim = (config.CO // pe) * config.K * config.K * (config.CI // simd)
    total_elems = outer_dim * pe * simd
    
    if weights is None or len(weights) == 0:
        # fallback: incremental pattern
        weights = list(range(total_elems))
    else:
        # adjust length to match required elements
        if len(weights) < total_elems:
            weights = weights + [0] * (total_elems - len(weights))
        elif len(weights) > total_elems:
            weights = weights[:total_elems]
    
    kernel_lines = []
    kernel_lines.append(f"static TW const  KERNEL[{outer_dim}][{pe}][{simd}] = {{")
    
    idx = 0
    for _co_group in range(config.CO // pe):
        for _k_row in range(config.K):
            for _k_col in range(config.K):
                for _ci_group in range(config.CI // simd):
                    pe_values = []
                    for _p in range(pe):
                        simd_values = []
                        for _s in range(simd):
                            hex_val = f"0x{(weights[idx] & 0xFF):02x}"
                            simd_values.append(hex_val)
                            idx += 1
                        if simd == 1:
                            pe_values.append(f"{{{simd_values[0]},}}")
                        else:
                            pe_values.append(f"{{{','.join(simd_values)},}}")
                    
                    if pe == 1:
                        line = f"\t{{{pe_values[0]}}},"
                    else:
                        line = f"\t{{{','.join(pe_values)}}},"
                    kernel_lines.append(line)
    
    kernel_lines.append("};")
    return "\n".join(kernel_lines)


def generate_pe_simd_configs(config: DeconvConfig) -> List[Tuple[int, int]]:
    """Generate valid PE and SIMD configurations"""
    configs = []
    
    # Find divisors of CO for PE
    pe_options = [i for i in range(1, config.CO + 1) if config.CO % i == 0]
    
    # Find divisors of CI for SIMD
    simd_options = [i for i in range(1, config.CI + 1) if config.CI % i == 0]
    
    # Common configurations
    for pe in pe_options[:3]:  # Limit to first 3 options
        for simd in simd_options[:2]:  # Limit to first 2 options
            configs.append((pe, simd))
    
    return configs if configs else [(1, 1)]


def generate_header_file(config: DeconvConfig, pe_simd_configs: List[Tuple[int, int]], 
                         weights_path: str = None) -> str:
    """Generate complete header file content.
    
    If weights_path is provided, load weights from CSV and pass them 
    to generate_kernel_weights.
    """
    header_template = f"""#ifndef DECONV_TOP_HPP
#define DECONV_TOP_HPP

#include <ap_int.h>
#include <hls_stream.h>
#include <hls_vector.h>

constexpr unsigned  K = {config.K};		// kernel Size
constexpr unsigned  S = {config.S}; 		// stride
constexpr unsigned  P = {config.P};		// padding
constexpr unsigned  H = {config.H};		// IFM height
constexpr unsigned  W = {config.W};		// IFM Width
constexpr unsigned  CI = {config.CI};		// input channels
constexpr unsigned  CO = {config.CO};		// output channels

using  TW = ap_uint< 8>;
using  TI = ap_uint< 4>;
using  TO = ap_uint<16>;

"""
    
    provided_weights = load_weights_from_csv(weights_path) if weights_path else None
    
    config_sections = []
    for i, (pe, simd) in enumerate(pe_simd_configs):
        if i == 0:
            config_sections.append("#if 1\n")
        else:
            config_sections.append("#else\n")
        
        config_sections.append(f"constexpr unsigned  PE   = {pe};\n")
        config_sections.append(f"constexpr unsigned  SIMD = {simd};\n")
        config_sections.append("")
        
        kernel_weights = generate_kernel_weights(config, pe, simd, weights=provided_weights)
        config_sections.append(kernel_weights)
        config_sections.append("")
    
    if len(pe_simd_configs) > 1:
        config_sections.append("#endif")
    
    function_decl = """
void deconv_top(
    hls::stream<hls::vector<TI, SIMD>> &src,
    hls::stream<hls::vector<TO, PE>>   &dst
);

#endif"""
    
    full_content = header_template + "\n".join(config_sections) + function_decl
    return full_content


def load_configs_from_csv(csv_path: Path, exp_data_dir: Path = None) -> List[Dict]:
    """Load configurations from CSV file and find associated data files"""
    configurations = []
    config_groups = []
    
    print(f"Loading configurations from {csv_path}...")
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                config = DeconvConfig(
                    K=int(row['kernel_size']),
                    S=int(row['stride']),
                    H=int(row['input_size']),
                    W=int(row['input_size']),
                    CI=int(row['in_channels']),
                    CO=int(row['out_channels']),
                    P=int(row['padding'])
                )
                configurations.append(config)
                print(f"  Loaded: {config}")
            except (KeyError, ValueError) as e:
                print(f"  Skipping invalid row: {row} - Error: {e}")
    
    print(f"Total configurations loaded: {len(configurations)}\n")
    
    # Validate configurations
    valid_configs = []
    for config in configurations:
        if config.validate():
            valid_configs.append(config)
            print(f"✓ Valid: {config}")
        else:
            print(f"✗ Invalid: {config}")
    
    print(f"\nTotal valid configurations: {len(valid_configs)}")
    
    # Find associated data files if exp_data_dir is provided
    if exp_data_dir and exp_data_dir.exists():
        suffixes = {
            'weights': '_weights.csv',
            'input': '_input.csv',
            'output': '_output.csv',
        }
        
        for cfg in valid_configs:
            base = f"deconv_{cfg.H}x{cfg.W}_in{cfg.CI}_out{cfg.CO}_k{cfg.K}_s{cfg.S}_p{cfg.P}"
            files = {}
            all_present = True
            
            for kind, suff in suffixes.items():
                fpath = exp_data_dir / f"{base}{suff}"
                if fpath.exists():
                    files[kind] = str(fpath)
                    print(f"Found {kind} file for config: {cfg} -> {fpath}")
                else:
                    files[kind] = None
                    all_present = False
            
            config_groups.append({
                'config': cfg,
                'files': files,
                'all_present': all_present
            })
        
        print(f"\nConfig groups with all files present: {sum(1 for g in config_groups if g['all_present'])}")
    else:
        # No data directory, just create config groups without files
        for cfg in valid_configs:
            config_groups.append({
                'config': cfg,
                'files': {},
                'all_present': False
            })
    
    return config_groups


def generate_selector_header(generated_files: List[Dict], output_dir: Path):
    """Generate selector header that includes one of the generated config headers"""
    selector_path = output_dir / "deconv_top.hpp"
    
    lines = []
    lines.append("// Auto-generated selector header for deconvolution configurations")
    lines.append("// Usage: define one of the following macros before including this file:")
    for idx, info in enumerate(generated_files):
        param_tag = info['filename'].replace("deconv_top_", "").replace(".hpp", "")
        lines.append(f"//   - DECONV_CFG_IDX_{idx}")
        lines.append(f"//   - DECONV_CFG_{param_tag}")
    lines.append("")
    
    guard = "DECONV_TOP_SELECTOR_HPP"
    lines.append(f"#ifndef {guard}")
    lines.append(f"#define {guard}")
    lines.append("")
    
    if generated_files:
        for idx, info in enumerate(generated_files):
            param_tag = info['filename'].replace("deconv_top_", "").replace(".hpp", "")
            macro_idx = f"DECONV_CFG_IDX_{idx}"
            macro_param = f"DECONV_CFG_{param_tag}"
            cond = f"defined({macro_idx}) || defined({macro_param})"
            prefix = "#if" if idx == 0 else "#elif"
            lines.append(f"{prefix} {cond}")
            lines.append(f'#include "{info["filename"]}"')
        # Default to the first config if none specified
        lines.append("#else")
        lines.append(f'#include "{generated_files[0]["filename"]}"')
        lines.append("#endif")
    else:
        lines.append('#error "No configuration headers were generated. Please generate configurations first."')
    
    lines.append("")
    lines.append(f"#endif // {guard}")
    
    with open(selector_path, "w") as f:
        f.write("\n".join(lines))
    
    print(f"\nSelector header generated: {selector_path}")


def print_summary(generated_files: List[Dict]):
    """Print summary table of generated configurations"""
    print("\n" + "=" * 80)
    print("GENERATED CONFIGURATIONS SUMMARY")
    print("=" * 80)
    print(f"{'Filename':<45} {'Parameters':<35} {'PE/SIMD'}")
    print("-" * 80)
    
    for file_info in generated_files:
        pe_simd_str = ", ".join([f"({pe},{simd})" for pe, simd in file_info['pe_simd_configs']])
        print(f"{file_info['filename']:<45} {file_info['config']:<35} {pe_simd_str}")
    
    print("=" * 80)
    print("\n🔧 Next Steps:")
    print("  1. Run HLS project generation: ./manage_hls_projects.sh generate")
    print("  2. Run C simulation: ./manage_hls_projects.sh csim")
    print("  3. Run synthesis: ./manage_hls_projects.sh synthesize")
    print("  4. Run co-simulation: ./manage_hls_projects.sh cosim")
    print("  5. Gather output files: ./manage_hls_projects.sh gather-outputs")
    print("  6. Copy golden reference files: ./manage_hls_projects.sh gather-golden")
    print("  7. Compare results with golden references: ./manage_hls_projects.sh compare-results")
    print("\n📁 Scripts are organized in the 'scripts/' folder")
    print("📁 Generated configs are in the 'generated_configs/' folder")
    print("📁 All configurations now include padding parameter (P) in filename")


def main():
    parser = argparse.ArgumentParser(
        description='Generate deconvolution configuration header files for HLS',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate from default CSV file
  python generate_deconv_configs.py
  
  # Generate from custom CSV file
  python generate_deconv_configs.py --csv /path/to/configs.csv
  
  # Specify custom output directory
  python generate_deconv_configs.py --output ./my_configs
  
  # Specify experimental data directory for weights
  python generate_deconv_configs.py --exp-data /path/to/exp_data
        """
    )
    
    parser.add_argument(
        '--csv',
        type=Path,
        default=Path('/mnt/Crucial/WorkspaceB/finn_hls/DeConv_benchmark/deconv_data/configs/deconv_configs.csv'),
        help='Path to CSV file containing configurations (default: DeConv_benchmark path)'
    )
    
    parser.add_argument(
        '--exp-data',
        type=Path,
        default=Path('/mnt/Crucial/WorkspaceB/finn_hls/DeConv_benchmark/deconv_data/exp_data'),
        help='Path to experimental data directory containing weights files (default: DeConv_benchmark path)'
    )
    
    parser.add_argument(
        '--output',
        type=Path,
        default=Path('generated_configs'),
        help='Output directory for generated header files (default: ./generated_configs)'
    )
    
    args = parser.parse_args()
    
    # Validate CSV file exists
    if not args.csv.exists():
        print(f"Error: CSV file not found: {args.csv}")
        print("Please provide a valid CSV file with --csv option")
        sys.exit(1)
    
    # Create output directory
    args.output.mkdir(exist_ok=True, parents=True)
    print(f"Output directory: {args.output.absolute()}\n")
    
    # Load configurations from CSV
    config_groups = load_configs_from_csv(args.csv, args.exp_data)
    
    if not config_groups:
        print("No valid configurations found!")
        sys.exit(1)
    
    # Generate header files
    generated_files = []
    
    for i, de_config in enumerate(config_groups):
        config = de_config['config']
        weights_file = de_config['files'].get('weights')
        
        # Generate PE/SIMD configurations
        pe_simd_configs = generate_pe_simd_configs(config)
        
        # Generate header content with padding in filename
        header_content = generate_header_file(config, pe_simd_configs, weights_path=weights_file)
        filename = f"deconv_top_K{config.K}_S{config.S}_H{config.H}_W{config.W}_CI{config.CI}_CO{config.CO}_P{config.P}.hpp"
        filepath = args.output / filename
        
        # Write to file
        with open(filepath, 'w') as f:
            f.write(header_content)
        
        generated_files.append({
            'filename': filename,
            'config': str(config),
            'pe_simd_configs': pe_simd_configs,
            'filepath': str(filepath)
        })
        
        print(f"Generated: {filename}")
    
    # Generate selector header
    generate_selector_header(generated_files, args.output)
    
    # Print summary
    print(f"\n📁 All files saved to: {args.output.absolute()}")
    print(f"📊 Total files generated: {len(generated_files)}")
    
    print_summary(generated_files)


if __name__ == '__main__':
    main()
