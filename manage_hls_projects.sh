#!/bin/bash

# =============================================================================
# HLS Project Management Script
# =============================================================================
# This script provides convenient commands for managing HLS projects
# =============================================================================

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/generated_configs"
PROJECTS_DIR="${SCRIPT_DIR}/hls_projects"
# Local benchmark data root (produced by run_benchmark_and_generate.sh)
DATA_ROOT="${SCRIPT_DIR}/deconv_data"
EXP_DATA_DIR="${DATA_ROOT}/exp_data"
CONFIG_CSV="${DATA_ROOT}/configs/deconv_configs.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

show_usage() {
    cat << EOF
HLS Project Management Script

Usage: $0 <command> [options]

Commands:
    validate        - Validate setup and show what projects would be created
    generate        - Generate HLS projects (requires Vitis 2024.1+ or Vivado HLS)
    demo           - Create demo project structure
    test           - Test basic HLS synthesis functionality
    csim           - Run C simulation on all projects (requires Vitis 2024.1+ or Vivado HLS)
    synthesize     - Run synthesis on all projects (requires Vitis 2024.1+ or Vivado HLS)
    cosim          - Run co-simulation on all projects (requires Vitis 2024.1+ or Vivado HLS)
    gather-outputs - Gather C simulation output CSV files with PE/SIMD naming into outputs folder
    gather-golden  - Copy golden reference output files from experimental data
    compare-results - Compare simulation outputs with golden reference results
    run            - End-to-end flow: csim → gather-outputs → gather-golden → compare-results (timestamped history retained)
    clean          - Clean generated projects
    list           - List all available configurations
    status         - Show status of projects
    help           - Show this help message

Examples:
    $0 validate                    # Check if setup is correct
    $0 generate                    # Create real HLS projects  
    $0 demo                        # Create demo projects
    $0 test                        # Test basic HLS synthesis
    $0 csim                        # Run C simulation on all projects
    $0 synthesize                  # Run synthesis on all projects
    $0 cosim                       # Run co-simulation on all projects
    $0 gather-outputs              # Gather C simulation CSV files with PE/SIMD naming
    $0 gather-golden               # Copy golden reference output files
    $0 compare-results             # Compare simulation outputs with golden results
    $0 run                         # Perform full simulation + collection + comparison (results in comparison_results/<timestamp>/)
    $0 clean                       # Remove all generated projects
    $0 list                        # Show available configurations

Requirements:
    - For 'generate', 'csim', 'synthesize', 'cosim': Vitis 2024.1+ (preferred) or Vivado HLS (legacy)
    - For other commands: Only tclsh is required

Data Locations (defaults):
    Benchmark configs CSV : 
        ${CONFIG_CSV}
    Experimental golden data root (outputs, weights, inputs):
        ${EXP_DATA_DIR}
    Generated HLS headers (after running generator script):
        ${CONFIG_DIR}
    Comparison results (timestamped runs retained):
        ${SCRIPT_DIR}/comparison_results/<YYYYMMDD_HHMMSS>/ (symlink 'latest' points to most recent)
EOF
}

check_vitis_hls() {
    if command -v vitis-run &> /dev/null; then
        return 0
    elif command -v vivado_hls &> /dev/null; then
        log_warn "Using legacy Vivado HLS. Consider upgrading to Vitis 2024.1+"
        return 0
    else
        log_error "Neither Vitis HLS nor Vivado HLS found in PATH"
        log_error "Please install Vitis 2024.1+ and source the settings script:"
        log_error "  source /path/to/Vitis/settings64.sh"
        log_error "Or for legacy Vivado HLS:"
        log_error "  source /path/to/Vivado/settings64.sh"
        return 1
    fi
}

validate_setup() {
    log_header "Validating Setup"
    
    if [ ! -f "${SCRIPT_DIR}/scripts/validate_hls_setup.tcl" ]; then
        log_error "Validation script not found: scripts/validate_hls_setup.tcl"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    tclsh scripts/validate_hls_setup.tcl
}

generate_projects() {
    log_header "Generating HLS Projects"
    
    if ! check_vitis_hls; then
        return 1
    fi
    
    if [ ! -f "${SCRIPT_DIR}/scripts/generate_hls_projects.tcl" ]; then
        log_error "Generator script not found: scripts/generate_hls_projects.tcl"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    log_info "Running HLS project generator..."
    if command -v vitis-run &> /dev/null; then
        vitis-run --mode hls --tcl scripts/generate_hls_projects.tcl
    else
        vivado_hls -f scripts/generate_hls_projects.tcl
    fi
    
    if [ $? -eq 0 ]; then
        log_info "HLS projects generated successfully!"
        log_info "Projects created in: $PROJECTS_DIR"
    else
        log_error "HLS project generation failed!"
        return 1
    fi
}

create_demo() {
    log_header "Creating Demo Projects"
    
    if [ ! -f "${SCRIPT_DIR}/scripts/demo_hls_projects.tcl" ]; then
        log_error "Demo script not found: scripts/demo_hls_projects.tcl"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    tclsh scripts/demo_hls_projects.tcl
    
    if [ $? -eq 0 ]; then
        log_info "Demo projects created successfully!"
        log_info "Demo projects in: ${SCRIPT_DIR}/hls_projects_demo"
    else
        log_error "Demo project creation failed!"
        return 1
    fi
}

test_hls() {
    log_header "Testing Basic HLS Synthesis"
    
    if ! check_vitis_hls; then
        return 1
    fi
    
    if [ ! -f "${SCRIPT_DIR}/scripts/test_hls_basic.tcl" ]; then
        log_error "Test script not found: scripts/test_hls_basic.tcl"
        return 1
    fi
    
    cd "$SCRIPT_DIR"
    log_info "Running basic HLS synthesis test..."
    if command -v vitis-run &> /dev/null; then
        vitis-run --mode hls --tcl scripts/test_hls_basic.tcl
    else
        vivado_hls -f scripts/test_hls_basic.tcl
    fi
    
    if [ $? -eq 0 ]; then
        log_info "HLS synthesis test completed successfully!"
    else
        log_error "HLS synthesis test failed!"
        return 1
    fi
}

csim_all() {
    log_header "Running C Simulation on All Projects"
    
    if ! check_vitis_hls; then
        return 1
    fi
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        log_error "Projects directory not found: $PROJECTS_DIR"
        log_error "Run '$0 generate' first to create projects"
        return 1
    fi
    
    local csim_script="${PROJECTS_DIR}/run_all_csim.tcl"
    if [ ! -f "$csim_script" ]; then
        log_error "C simulation script not found: $csim_script"
        log_error "Make sure to generate projects first"
        return 1
    fi
    
    cd "$PROJECTS_DIR"
    log_info "Running C simulation script..."
    if command -v vitis-run &> /dev/null; then
        vitis-run --mode hls --tcl run_all_csim.tcl
    else
        vivado_hls -f run_all_csim.tcl
    fi
    
    if [ $? -eq 0 ]; then
        log_info "C simulation completed successfully!"
    else
        log_error "C simulation failed!"
        return 1
    fi
}

synthesize_all() {
    log_header "Running Synthesis on All Projects"
    
    if ! check_vitis_hls; then
        return 1
    fi
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        log_error "Projects directory not found: $PROJECTS_DIR"
        log_error "Run '$0 generate' first to create projects"
        return 1
    fi
    
    local synthesis_script="${PROJECTS_DIR}/run_all_synthesis.tcl"
    if [ ! -f "$synthesis_script" ]; then
        log_error "Synthesis script not found: $synthesis_script"
        log_error "Make sure to generate projects first"
        return 1
    fi
    
    cd "$PROJECTS_DIR"
    log_info "Running synthesis script..."
    if command -v vitis-run &> /dev/null; then
        vitis-run --mode hls --tcl run_all_synthesis.tcl
    else
        vivado_hls -f run_all_synthesis.tcl
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Synthesis completed successfully!"
    else
        log_error "Synthesis failed!"
        return 1
    fi
}

cosim_all() {
    log_header "Running Co-simulation on All Projects"
    
    if ! check_vitis_hls; then
        return 1
    fi
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        log_error "Projects directory not found: $PROJECTS_DIR"
        log_error "Run '$0 generate' first to create projects"
        return 1
    fi
    
    local cosim_script="${PROJECTS_DIR}/run_all_cosim.tcl"
    if [ ! -f "$cosim_script" ]; then
        log_error "Co-simulation script not found: $cosim_script"
        log_error "Make sure to generate projects first"
        return 1
    fi
    
    cd "$PROJECTS_DIR"
    log_info "Running co-simulation script..."
    if command -v vitis-run &> /dev/null; then
        vitis-run --mode hls --tcl run_all_cosim.tcl
    else
        vivado_hls -f run_all_cosim.tcl
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Co-simulation completed successfully!"
    else
        log_error "Co-simulation failed!"
        return 1
    fi
}

clean_projects() {
    log_header "Cleaning Generated Projects & Outputs"
    
    local cleaned=0
    
    # Remove HLS project directories
    if [ -d "$PROJECTS_DIR" ]; then
        log_info "Removing HLS projects directory: $PROJECTS_DIR"
        rm -rf "$PROJECTS_DIR"
        cleaned=1
    fi
    
    if [ -d "${SCRIPT_DIR}/hls_projects_demo" ]; then
        log_info "Removing demo projects directory: ${SCRIPT_DIR}/hls_projects_demo"
        rm -rf "${SCRIPT_DIR}/hls_projects_demo"
        cleaned=1
    fi

    # Remove standalone test HLS project created by test_hls_basic.tcl
    local test_proj_dir="${SCRIPT_DIR}/test_hls_project"
    if [ -d "$test_proj_dir" ]; then
        log_info "Removing test HLS project directory: $test_proj_dir"
        rm -rf "$test_proj_dir"
        cleaned=1
    fi
    
    # Remove transient outputs & golden references (preserve comparison_results history)
    for extra_dir in "${SCRIPT_DIR}/outputs" "${SCRIPT_DIR}/golden_results"; do
        if [ -d "$extra_dir" ]; then
            log_info "Removing results directory: $extra_dir"
            rm -rf "$extra_dir"
            cleaned=1
        fi
    done
    if [ -d "${SCRIPT_DIR}/comparison_results" ]; then
        log_info "Preserving comparison results directory: ${SCRIPT_DIR}/comparison_results"
    fi
    
    if [ $cleaned -eq 1 ]; then
        log_info "Cleanup completed"
    else
        log_info "Nothing to clean (projects or output folders absent)"
    fi
}

list_configurations() {
    log_header "Available Configurations"
    
    if [ ! -d "$CONFIG_DIR" ]; then
        log_error "Configuration directory not found: $CONFIG_DIR"
        log_error "Run the Jupyter notebook first to generate configurations"
        return 1
    fi
    
    local config_files=($(find "$CONFIG_DIR" -name "deconv_top_K*_S*_H*_W*_CI*_CO*_P*.hpp" 2>/dev/null))
    
    if [ ${#config_files[@]} -eq 0 ]; then
        log_warn "No configuration files found in $CONFIG_DIR"
        log_warn "Run the deconv_generator.ipynb notebook to generate configurations"
        return 1
    fi
    
    log_info "Found ${#config_files[@]} configuration(s):"
    echo
    
    for config_file in "${config_files[@]}"; do
        local filename=$(basename "$config_file")
        
        # Extract parameters using regex
        if [[ $filename =~ deconv_top_K([0-9]+)_S([0-9]+)_H([0-9]+)_W([0-9]+)_CI([0-9]+)_CO([0-9]+)_P([0-9]+)\.hpp ]]; then
            local K=${BASH_REMATCH[1]}
            local S=${BASH_REMATCH[2]}
            local H=${BASH_REMATCH[3]}
            local W=${BASH_REMATCH[4]}
            local CI=${BASH_REMATCH[5]}
            local CO=${BASH_REMATCH[6]}
            local P=${BASH_REMATCH[7]}
            
            echo "  $filename"
            echo "    Parameters: K=$K, S=$S, H=$H, W=$W, CI=$CI, CO=$CO, P=$P"
            echo "    Project name: deconv_K${K}_S${S}_H${H}_W${W}_CI${CI}_CO${CO}_P${P}"
            echo
        else
            echo "  $filename (could not parse parameters)"
            echo
        fi
    done
}

gather_outputs() {
    log_header "Gathering Output Files"
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        log_error "HLS projects directory not found: $PROJECTS_DIR"
        return 1
    fi
    
    local outputs_dir="${SCRIPT_DIR}/outputs"
    mkdir -p "$outputs_dir"
    
    # Clean outputs directory first
    rm -f "$outputs_dir"/*.csv
    
    local found_files=0
    
    # Find all projects
    for project_dir in "$PROJECTS_DIR"/deconv_*; do
        if [ ! -d "$project_dir" ]; then
            continue
        fi
        
        local project_name=$(basename "$project_dir")
        log_info "Processing project: $project_name"
        
        # Find all solutions in this project
        for solution_dir in "$project_dir"/solution*; do
            if [ ! -d "$solution_dir" ]; then
                continue
            fi
            
            local solution_name=$(basename "$solution_dir")
            log_info "  Processing solution: $solution_name"
            
            # Extract PE and SIMD values from solution name (e.g., solution1_PE1_SIMD1)
            local pe_simd=""
            if [[ "$solution_name" =~ solution[0-9]+_(PE[0-9]+_SIMD[0-9]+) ]]; then
                pe_simd="${BASH_REMATCH[1]}"
            else
                pe_simd="$solution_name"
            fi
            
            # Gather only C simulation outputs (csim/build/)
            if [ -d "$solution_dir/csim/build" ]; then
                find "$solution_dir/csim/build" -name "*.csv" 2>/dev/null | while read -r file; do
                    if [ -f "$file" ]; then
                        local original_filename=$(basename "$file")
                        local base_name="${original_filename%.*}"
                        local extension="${original_filename##*.}"
                        local new_filename="${base_name}_${pe_simd}.${extension}"
                        
                        cp "$file" "${outputs_dir}/${new_filename}"
                        log_info "    Copied: $original_filename -> $new_filename"
                        found_files=$((found_files + 1))
                    fi
                done
            fi
        done
    done
    
    # Count actual files copied (since subshell variables don't propagate)
    found_files=$(find "$outputs_dir" -name "*.csv" -type f 2>/dev/null | wc -l)
    
    if [ "$found_files" -eq 0 ]; then
        log_warn "No C simulation output CSV files found. Run csim first."
    else
        log_info "Successfully gathered $found_files C simulation output files to: $outputs_dir"
        echo
        log_info "Output files:"
        ls -la "$outputs_dir"/*.csv 2>/dev/null || echo "No CSV files found"
    fi
}

gather_golden_results() {
    log_header "Gathering Golden Reference Results"
    
    local golden_dir="${SCRIPT_DIR}/golden_results"

    if [ ! -d "$EXP_DATA_DIR" ]; then
        log_error "Experimental data directory not found: $EXP_DATA_DIR"
        log_error "Run './scripts/run_benchmark_and_generate.sh' first to create local deconv_data."
        return 1
    fi
    
    mkdir -p "$golden_dir"
    
    # Clean golden results directory first
    rm -f "$golden_dir"/*.csv
    
    local found_files=0
    
    # Find all output CSV files in local experimental data
    find "$EXP_DATA_DIR" -name "*_output.csv" | while read -r file; do
        if [ -f "$file" ]; then
            local basename=$(basename "$file")
            cp "$file" "$golden_dir/"
            log_info "Copied: $basename"
            found_files=$((found_files + 1))
        fi
    done
    
    # Count actual files copied (since subshell variables don't propagate)
    found_files=$(find "$golden_dir" -name "*.csv" -type f 2>/dev/null | wc -l)
    
    if [ "$found_files" -eq 0 ]; then
        log_warn "No golden reference output files found in: $EXP_DATA_DIR"
    else
        log_info "Successfully copied $found_files golden reference files to: $golden_dir"
        echo
        log_info "Golden reference files:"
        ls -la "$golden_dir"/*.csv 2>/dev/null || echo "No CSV files found"
    fi
}

compare_results() {
    log_header "Comparing Results with Golden References"
    
    local outputs_dir="${SCRIPT_DIR}/outputs"
    local golden_dir="${SCRIPT_DIR}/golden_results"
    local comparison_dir="${SCRIPT_DIR}/comparison_results"
    
    if [ ! -d "$outputs_dir" ]; then
        log_error "Outputs directory not found: $outputs_dir"
        log_error "Run './manage_hls_projects.sh gather-outputs' first"
        return 1
    fi
    
    if [ ! -d "$golden_dir" ]; then
        log_error "Golden results directory not found: $golden_dir"
        log_error "Run './manage_hls_projects.sh gather-golden' first"
        return 1
    fi
    
    mkdir -p "$comparison_dir"
    # Create timestamped run directory and update 'latest' symlink
    local timestamp="$(date +"%Y%m%d_%H%M%S")"
    local run_dir="${comparison_dir}/${timestamp}"
    mkdir -p "$run_dir"
    ln -sfn "$run_dir" "${comparison_dir}/latest"
    
    # Create comparison report inside run directory
    local report_file="${run_dir}/comparison_report.txt"
    local csv_report="${run_dir}/comparison_summary.csv"
    
    echo "HLS Deconvolution Results Comparison Report" > "$report_file"
    echo "Generated on: $(date)" >> "$report_file"
    echo "==========================================" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "Configuration,PE_SIMD,Status,Match,Output_File,Golden_File" > "$csv_report"
    
    local total_comparisons=0
    local successful_matches=0
    local failed_matches=0
    
    # Compare each output file with corresponding golden reference
    for output_file in "$outputs_dir"/*.csv; do
        if [ ! -f "$output_file" ]; then
            continue
        fi
        
        local output_basename=$(basename "$output_file")
        
        # Extract configuration from filename (remove PE_SIMD suffix)
        # Example: deconv_3x3_in1_out3_k3_s1_p2_output_hls_PE1_SIMD1.csv
        # Should match: deconv_3x3_in1_out3_k3_s1_p2_output.csv
        local config_pattern=""
        if [[ "$output_basename" =~ deconv_([0-9]+x[0-9]+_in[0-9]+_out[0-9]+_k[0-9]+_s[0-9]+_p[0-9]+)_output_hls_(PE[0-9]+_SIMD[0-9]+)\.csv ]]; then
            local config_base="${BASH_REMATCH[1]}"
            local pe_simd="${BASH_REMATCH[2]}"
            config_pattern="deconv_${config_base}_output.csv"
        else
            log_warn "Could not parse configuration from: $output_basename"
            continue
        fi
        
        # Look for matching golden reference file
        local golden_file="${golden_dir}/${config_pattern}"
        
        if [ ! -f "$golden_file" ]; then
            log_warn "No golden reference found for: $output_basename"
            echo "$config_base,$pe_simd,NO_GOLDEN,N/A,$output_basename,NOT_FOUND" >> "$csv_report"
            echo "COMPARISON: $output_basename" >> "$report_file"
            echo "  Status: NO GOLDEN REFERENCE FOUND" >> "$report_file"
            echo "  Expected: $config_pattern" >> "$report_file"
            echo "" >> "$report_file"
            continue
        fi
        
        total_comparisons=$((total_comparisons + 1))
        
        # Compare the files
        local output_content=$(cat "$output_file" | tr -d ' \n\r')
        local golden_content=$(cat "$golden_file" | tr -d ' \n\r')
        
        if [ "$output_content" = "$golden_content" ]; then
            log_info "✓ MATCH: $output_basename vs $(basename "$golden_file")"
            successful_matches=$((successful_matches + 1))
            echo "$config_base,$pe_simd,MATCH,YES,$output_basename,$(basename "$golden_file")" >> "$csv_report"
            echo "COMPARISON: $output_basename" >> "$report_file"
            echo "  Status: MATCH ✓" >> "$report_file"
            echo "  Golden: $(basename "$golden_file")" >> "$report_file"
            echo "  Content: $output_content" >> "$report_file"
        else
            log_error "✗ MISMATCH: $output_basename vs $(basename "$golden_file")"
            failed_matches=$((failed_matches + 1))
            echo "$config_base,$pe_simd,MISMATCH,NO,$output_basename,$(basename "$golden_file")" >> "$csv_report"
            echo "COMPARISON: $output_basename" >> "$report_file"
            echo "  Status: MISMATCH ✗" >> "$report_file"
            echo "  Golden: $(basename "$golden_file")" >> "$report_file"
            echo "  Output Content: $output_content" >> "$report_file"
            echo "  Golden Content: $golden_content" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    # Summary
    echo "SUMMARY" >> "$report_file"
    echo "=======" >> "$report_file"
    echo "Total Comparisons: $total_comparisons" >> "$report_file"
    echo "Successful Matches: $successful_matches" >> "$report_file"
    echo "Failed Matches: $failed_matches" >> "$report_file"
    echo "" >> "$report_file"
    
    if [ $total_comparisons -eq 0 ]; then
        log_warn "No comparisons could be performed"
    else
        local success_rate=$((successful_matches * 100 / total_comparisons))
        log_info "Comparison Summary:"
        log_info "  Total comparisons: $total_comparisons"
        log_info "  Successful matches: $successful_matches"
        log_info "  Failed matches: $failed_matches"
        log_info "  Success rate: ${success_rate}%"
        
        if [ $failed_matches -eq 0 ]; then
            log_info "🎉 All comparisons passed!"
        else
            log_warn "⚠️  Some comparisons failed. Check the detailed report."
        fi
    fi
    
    log_info "Detailed report saved to: $report_file"
    log_info "CSV summary saved to: $csv_report"
    log_info "Run directory: $run_dir"
    log_info "Latest symlink: ${comparison_dir}/latest"
    log_info "All historical runs retained under: $comparison_dir"
}

show_status() {
    log_header "Project Status"
    
    # Check configurations
    local config_count=0
    if [ -d "$CONFIG_DIR" ]; then
        config_count=$(find "$CONFIG_DIR" -name "deconv_top_K*_P*.hpp" | wc -l)
    fi
    
    # Check HLS projects
    local hls_project_count=0
    if [ -d "$PROJECTS_DIR" ]; then
        hls_project_count=$(find "$PROJECTS_DIR" -maxdepth 1 -type d -name "deconv_*" | wc -l)
    fi
    
    # Check demo projects
    local demo_project_count=0
    if [ -d "${SCRIPT_DIR}/hls_projects_demo" ]; then
        demo_project_count=$(find "${SCRIPT_DIR}/hls_projects_demo" -maxdepth 1 -type d -name "deconv_*" | wc -l)
    fi
    
    echo "Configuration files: $config_count"
    echo "HLS projects: $hls_project_count"
    echo "Demo projects: $demo_project_count"
    echo
    
    if [ $config_count -eq 0 ]; then
        log_warn "No configurations found. Run the Jupyter notebook first."
    fi
    
    if [ $hls_project_count -eq 0 ] && [ $config_count -gt 0 ]; then
        log_info "Ready to generate HLS projects. Run: $0 generate"
    fi
    
    # Check for Vitis/Vivado HLS
    if command -v vitis-run &> /dev/null; then
        log_info "Vitis HLS is available (recommended)"
    elif command -v vivado_hls &> /dev/null; then
        log_info "Vivado HLS is available (legacy)"
    else
        log_warn "Neither Vitis HLS nor Vivado HLS found in PATH"
    fi
}

main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        validate)
            validate_setup
            ;;
        generate)
            generate_projects
            ;;
        demo)
            create_demo
            ;;
        test)
            test_hls
            ;;
        csim)
            csim_all
            ;;
        synthesize)
            synthesize_all
            ;;
        cosim)
            synthesize_all
            cosim_all
            ;;
        gather-outputs)
            gather_outputs
            ;;
        gather-golden)
            gather_golden_results
            ;;
        compare-results)
            compare_results
            ;;
        run)
            # synthesize_all
            # cosim_all
            csim_all
            gather_outputs
            gather_golden_results
            compare_results

            ;;
        clean)
            clean_projects
            ;;
        list)
            list_configurations
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            echo
            show_usage
            exit 1
            ;;
    esac
}

main "$@"