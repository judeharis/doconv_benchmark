#!/usr/bin/env tclsh

# =============================================================================
# HLS Project Generator for Deconvolution Configurations
# =============================================================================
# This script automatically generates Vitis HLS projects for each deconvolution
# configuration found in the generated_configs directory.
#
# Usage (Vitis 2024.1+): vitis-run --mode hls --tcl generate_hls_projects.tcl
# Usage (Legacy):        vivado_hls -f generate_hls_projects.tcl
# =============================================================================

# Configuration
set SCRIPT_DIR [file dirname [file normalize [info script]]]
set BASE_DIR [file dirname $SCRIPT_DIR]
set CONFIG_DIR "${BASE_DIR}/generated_configs"
set SRC_DIR "${BASE_DIR}/src"
set PROJECTS_DIR "${BASE_DIR}/hls_projects"

# HLS Settings
# Zynq UltraScale+ device
set TARGET_DEVICE "xczu3eg-sbva484-1-i"
set CLOCK_PERIOD "5"             
set RESET_TYPE "sync"         
set RESET_POLARITY "active_high"

# Global variable to store all project configurations for script generation
set all_project_configs {}

# =============================================================================
# Utility Functions
# =============================================================================

proc log_message {level message} {
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    puts "\[$timestamp\] \[$level\] $message"
}

proc log_info {message} {
    log_message "INFO" $message
}

proc log_error {message} {
    log_message "ERROR" $message
}

proc log_warning {message} {
    log_message "WARN" $message
}

# Extract configuration parameters from filename
proc parse_config_filename {filename} {
    # Expected format: deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp
    if {[regexp {deconv_top_K(\d+)_S(\d+)_H(\d+)_W(\d+)_CI(\d+)_CO(\d+)_P(\d+)\.hpp} $filename match K S H W CI CO P]} {
        return [list $K $S $H $W $CI $CO $P]
    } else {
        return {}
    }
}

# Create directory if it doesn't exist
proc ensure_directory {dir_path} {
    if {![file exists $dir_path]} {
        file mkdir $dir_path
        log_info "Created directory: $dir_path"
    }
}

# Copy file with error handling
proc safe_copy_file {src dst} {
    if {[file exists $src]} {
        file copy -force $src $dst
        log_info "Copied: [file tail $src] -> [file tail $dst]"
        return 1
    } else {
        log_error "Source file not found: $src"
        return 0
    }
}

# Extract PE and SIMD values from header file
proc extract_pe_simd_configs {header_file} {
    set configs {}
    set file_handle [open $header_file r]
    set content [read $file_handle]
    close $file_handle
    
    # Look for PE and SIMD definitions
    set lines [split $content "\n"]
    set current_pe ""
    set current_simd ""
    
    foreach line $lines {
        if {[regexp {constexpr\s+unsigned\s+PE\s*=\s*(\d+);} $line match pe]} {
            set current_pe $pe
        }
        if {[regexp {constexpr\s+unsigned\s+SIMD\s*=\s*(\d+);} $line match simd]} {
            set current_simd $simd
            if {$current_pe != ""} {
                lappend configs [list $current_pe $current_simd]
            }
        }
    }
    
    if {[llength $configs] == 0} {
        # Default configuration if none found
        lappend configs [list 1 1]
    }
    
    return $configs
}

# =============================================================================
# HLS Project Creation Functions
# =============================================================================

proc create_hls_project {project_name config_params pe_simd_configs config_file} {
    global PROJECTS_DIR SRC_DIR TARGET_DEVICE CLOCK_PERIOD RESET_TYPE RESET_POLARITY
    
    lassign $config_params K S H W CI CO
    set project_dir "${PROJECTS_DIR}/${project_name}"
    
    log_info "Creating HLS project: $project_name"
    log_info "  Configuration: K=$K, S=$S, H=$H, W=$W, CI=$CI, CO=$CO"
    
    # Create project directory
    ensure_directory $project_dir
    
    # Create new HLS project
    open_project $project_dir
    
    # Set top function
    set_top deconv_top
    
    # Add source files
    set success 1
    
    # Copy and add the specific configuration header
    set config_dst "${project_dir}/deconv_top.hpp"
    if {[safe_copy_file $config_file $config_dst]} {
        add_files $config_dst -cflags "-std=c++14"
    } else {
        set success 0
    }
    
    # Add other source files
    set source_files {
        "deconv_top.cpp"
        "deconv.hpp"
        "utils.hpp"
    }
    
    foreach src_file $source_files {
        set src_path "${SRC_DIR}/${src_file}"
        set dst_path "${project_dir}/${src_file}"
        if {[safe_copy_file $src_path $dst_path]} {
            add_files $dst_path -cflags "-std=c++14"
        } else {
            set success 0
        }
    }
    
    # Add testbench
    set tb_src "${SRC_DIR}/deconv_tb.cpp"
    set tb_dst "${project_dir}/deconv_tb.cpp"
    if {[safe_copy_file $tb_src $tb_dst]} {
        add_files -tb $tb_dst -cflags "-std=c++14 -Wno-unknown-pragmas"
    } else {
        set success 0
    }
    
    # Create solutions for each PE/SIMD configuration
    set solution_count 1
    foreach pe_simd $pe_simd_configs {
        lassign $pe_simd pe simd
        set solution_name "solution${solution_count}_PE${pe}_SIMD${simd}"
        
        log_info "  Creating solution: $solution_name (PE=$pe, SIMD=$simd)"
        
        # Create solution
        open_solution $solution_name
        
        # Set device and clock
        set_part $TARGET_DEVICE
        create_clock -period $CLOCK_PERIOD -name default
        
        # Configure reset
        # config_reset -type $RESET_TYPE -sync $RESET_POLARITY
        
        # Add configuration-specific directives
        set_directive_interface -mode ap_ctrl_none "deconv_top" return
        set_directive_interface -mode axis "deconv_top" src
        set_directive_interface -mode axis "deconv_top" dst
        set_directive_dataflow "deconv_top"
        
        # Close solution
        close_solution
        
        incr solution_count
    }
    
    # Close project
    close_project
    
    if {$success} {
        log_info "Successfully created project: $project_name"
    } else {
        log_error "Project creation completed with errors: $project_name"
    }
    
    return $success
}

# =============================================================================
# Main Execution
# =============================================================================

proc main {} {
    global CONFIG_DIR PROJECTS_DIR all_project_configs
    
    log_info "Starting HLS project generation"
    log_info "Configuration directory: $CONFIG_DIR"
    log_info "Projects directory: $PROJECTS_DIR"
    
    # Ensure projects directory exists
    ensure_directory $PROJECTS_DIR
    
    # Find all configuration files
    set config_files {}
    if {[file exists $CONFIG_DIR]} {
        set all_files [glob -nocomplain -directory $CONFIG_DIR "deconv_top_K*_S*_H*_W*_CI*_CO*_P*.hpp"]
        set config_files $all_files
    }
    
    if {[llength $config_files] == 0} {
        log_error "No configuration files found in $CONFIG_DIR"
        log_error "Please run the deconv_generator.ipynb notebook first to generate configurations"
        return 1
    }
    
    log_info "Found [llength $config_files] configuration files"
    
    # Process each configuration file
    set successful_projects 0
    set total_projects 0
    
    foreach config_file $config_files {
        set filename [file tail $config_file]
        log_info "Processing configuration file: $filename"
        
        # Parse configuration parameters
        set config_params [parse_config_filename $filename]
        if {[llength $config_params] != 7} {
            log_error "Could not parse configuration from filename: $filename"
            continue
        }
        
        # Extract PE/SIMD configurations from the header file
        set pe_simd_configs [extract_pe_simd_configs $config_file]
        log_info "  Found [llength $pe_simd_configs] PE/SIMD configurations"
        
        # Create project name
        lassign $config_params K S H W CI CO P
        set project_name "deconv_K${K}_S${S}_H${H}_W${W}_CI${CI}_CO${CO}_P${P}"
        
        # Store configuration for script generation
        set solution_count 1
        foreach pe_simd $pe_simd_configs {
            lassign $pe_simd pe simd
            set solution_name "solution${solution_count}_PE${pe}_SIMD${simd}"
            set full_config [dict create \
                K $K S $S H $H W $W CI $CI CO $CO \
                PE $pe SIMD $simd \
                project_name $project_name \
                solution_name $solution_name]
            lappend all_project_configs $full_config
            incr solution_count
        }
        
        # Create HLS project
        incr total_projects
        if {[create_hls_project $project_name $config_params $pe_simd_configs $config_file]} {
            incr successful_projects
        }
        
        log_info "Completed processing: $filename"
        puts ""
    }
    
    # Summary
    log_info "Project generation completed"
    log_info "Total projects: $total_projects"
    log_info "Successful: $successful_projects"
    log_info "Failed: [expr $total_projects - $successful_projects]"
    
    if {$successful_projects == $total_projects} {
        log_info "All projects created successfully!"
        return 0
    } else {
        log_warning "Some projects failed to create. Check the log messages above."
        return 1
    }
}

# =============================================================================
# Additional Utility Scripts
# =============================================================================

# Generate a batch synthesis script for all projects
proc generate_synthesis_script {} {
    global PROJECTS_DIR
    
    set script_file "${PROJECTS_DIR}/run_all_synthesis.tcl"
    set file_handle [open $script_file w]
    
    puts $file_handle "# Auto-generated synthesis script for all deconv projects"
    puts $file_handle "# Usage (Vitis 2024.1+): vitis-run --mode hls --tcl run_all_synthesis.tcl"
    puts $file_handle "# Usage (Legacy):       vivado_hls -f run_all_synthesis.tcl"
    puts $file_handle ""
    
    # Find all project directories
    set project_dirs [glob -nocomplain -directory $PROJECTS_DIR -type d "deconv_*"]
    
    foreach project_dir $project_dirs {
        set project_name [file tail $project_dir]
        puts $file_handle "# Synthesize project: $project_name"
        puts $file_handle "puts \"Synthesizing project: $project_name\""
        puts $file_handle "open_project $project_dir"
        puts $file_handle "set_top deconv_top"
        puts $file_handle ""
        puts $file_handle "# Re-add source files to ensure they are properly loaded"
        puts $file_handle "add_files \{${project_dir}/deconv_top.hpp\} -cflags \"-std=c++14\""
        puts $file_handle "add_files \{${project_dir}/deconv_top.cpp\} -cflags \"-std=c++14\""
        puts $file_handle "add_files \{${project_dir}/deconv.hpp\} -cflags \"-std=c++14\""
        puts $file_handle "add_files \{${project_dir}/utils.hpp\} -cflags \"-std=c++14\""
        puts $file_handle "add_files -tb \{${project_dir}/deconv_tb.cpp\} -cflags \"-std=c++14 -Wno-unknown-pragmas\""
        puts $file_handle ""
        
        # Find all solutions in the project
        set solution_dirs [glob -nocomplain -directory $project_dir -type d "solution*"]
        foreach solution_dir $solution_dirs {
            set solution_name [file tail $solution_dir]
            puts $file_handle "puts \"  Synthesizing solution: $solution_name\""
            puts $file_handle "open_solution $solution_name"
            puts $file_handle "if \{\[catch \{csynth_design\} result\]\} \{"
            puts $file_handle "    puts \"ERROR: Synthesis failed for $solution_name: \$result\""
            puts $file_handle "\} else \{"
            puts $file_handle "    puts \"SUCCESS: Synthesis completed for $solution_name\""
            puts $file_handle "\}"
            puts $file_handle "close_solution"
        }
        
        puts $file_handle "close_project"
        puts $file_handle "puts \"Completed project: $project_name\""
        puts $file_handle ""
    }
    
    close $file_handle
    log_info "Generated synthesis script: $script_file"
}

# Generate a report extraction script
proc generate_report_script {} {
    global PROJECTS_DIR
    
    set script_file "${PROJECTS_DIR}/extract_reports.tcl"
    set file_handle [open $script_file w]
    
    puts $file_handle "# Auto-generated report extraction script"
    puts $file_handle "# This script extracts synthesis reports from all projects"
    puts $file_handle ""
    puts $file_handle "set report_file \"${PROJECTS_DIR}/synthesis_summary.csv\""
    puts $file_handle "set csv_file \[open \$report_file w\]"
    puts $file_handle "puts \$csv_file \"Project,Solution,LUT,FF,DSP,BRAM,Latency_Min,Latency_Max,Clock_Period\""
    puts $file_handle ""
    
    # Find all project directories
    set project_dirs [glob -nocomplain -directory $PROJECTS_DIR -type d "deconv_*"]
    
    foreach project_dir $project_dirs {
        set project_name [file tail $project_dir]
        puts $file_handle "# Extract reports from project: $project_name"
        
        # Find all solutions
        set solution_dirs [glob -nocomplain -directory $project_dir -type d "solution*"]
        foreach solution_dir $solution_dirs {
            set solution_name [file tail $solution_dir]
            set report_dir "${solution_dir}/syn/report"
            
            puts $file_handle "if {\[file exists ${report_dir}/deconv_top_csynth.rpt\]} {"
            puts $file_handle "    # Parse synthesis report for $project_name/$solution_name"
            puts $file_handle "    # Add parsing logic here"
            puts $file_handle "    puts \$csv_file \"$project_name,$solution_name,N/A,N/A,N/A,N/A,N/A,N/A,N/A\""
            puts $file_handle "}"
        }
        puts $file_handle ""
    }
    
    puts $file_handle "close \$csv_file"
    puts $file_handle "puts \"Report extraction completed. Results saved to: \$report_file\""
    
    close $file_handle
    log_info "Generated report extraction script: $script_file"
}

# =============================================================================
# Generate C Simulation Script
# =============================================================================
proc generate_csim_script {} {
    global all_project_configs PROJECTS_DIR
    
    set script_file "${PROJECTS_DIR}/run_all_csim.tcl"
    log_info "Generating C simulation script: $script_file"
    
    set file_handle [open $script_file w]
    
    # Header
    puts $file_handle "#!/usr/bin/env tclsh"
    puts $file_handle "# Generated C simulation script for all deconvolution configurations"
    puts $file_handle "# Generated on: [clock format [clock seconds]]"
    puts $file_handle ""
    puts $file_handle "# Log file for C simulation results"
    puts $file_handle "set log_file \"csim_results.log\""
    puts $file_handle "set log_handle \[open \$log_file w\]"
    puts $file_handle ""
    puts $file_handle "proc log_csim {message} {"
    puts $file_handle "    global log_handle"
    puts $file_handle "    puts \$log_handle \"\[clock format \[clock seconds\] -format \"%Y-%m-%d %H:%M:%S\"\] \$message\""
    puts $file_handle "    puts \$message"
    puts $file_handle "    flush \$log_handle"
    puts $file_handle "}"
    puts $file_handle ""
    puts $file_handle "log_csim \"Starting C simulation for all projects...\""
    puts $file_handle ""
    
    # Generate csim commands for each configuration
    foreach config $all_project_configs {
        dict with config {
            set project_dir $project_name
            
            puts $file_handle "# C Simulation for $project_name/$solution_name"
            puts $file_handle "if {\[file exists $project_dir\]} {"
            puts $file_handle "    log_csim \"Running C simulation for $project_name/$solution_name...\""
            puts $file_handle "    "
            puts $file_handle "    # Open project"
            puts $file_handle "    open_project $project_dir"
            puts $file_handle "    open_solution $solution_name"
            puts $file_handle "    "
            puts $file_handle "    # Run C simulation"
            puts $file_handle "    csim_design"
            puts $file_handle "    "
            puts $file_handle "    # Check results"
            puts $file_handle "    if {\[file exists $project_dir/$solution_name/csim/build/csim.exe\]} {"
            puts $file_handle "        log_csim \"C simulation completed successfully for $project_name/$solution_name\""
            puts $file_handle "    } else {"
            puts $file_handle "        log_csim \"WARNING: C simulation may have failed for $project_name/$solution_name\""
            puts $file_handle "    }"
            puts $file_handle "    "
            puts $file_handle "    close_project"
            puts $file_handle "} else {"
            puts $file_handle "    log_csim \"WARNING: Project directory not found: $project_dir\""
            puts $file_handle "}"
            puts $file_handle ""
        }
    }
    
    puts $file_handle "log_csim \"C simulation completed for all projects.\""
    puts $file_handle "close \$log_handle"
    puts $file_handle "puts \"C simulation results logged to: \$log_file\""
    
    close $file_handle
    log_info "Generated C simulation script: $script_file"
}

# =============================================================================
# Generate Co-Simulation Script
# =============================================================================
proc generate_cosim_script {} {
    global all_project_configs PROJECTS_DIR
    
    set script_file "${PROJECTS_DIR}/run_all_cosim.tcl"
    log_info "Generating co-simulation script: $script_file"
    
    set file_handle [open $script_file w]
    
    # Header
    puts $file_handle "#!/usr/bin/env tclsh"
    puts $file_handle "# Generated co-simulation script for all deconvolution configurations"
    puts $file_handle "# Generated on: [clock format [clock seconds]]"
    puts $file_handle ""
    puts $file_handle "# Log file for co-simulation results"
    puts $file_handle "set log_file \"cosim_results.log\""
    puts $file_handle "set log_handle \[open \$log_file w\]"
    puts $file_handle ""
    puts $file_handle "proc log_cosim {message} {"
    puts $file_handle "    global log_handle"
    puts $file_handle "    puts \$log_handle \"\[clock format \[clock seconds\] -format \"%Y-%m-%d %H:%M:%S\"\] \$message\""
    puts $file_handle "    puts \$message"
    puts $file_handle "    flush \$log_handle"
    puts $file_handle "}"
    puts $file_handle ""
    puts $file_handle "log_cosim \"Starting co-simulation for all projects...\""
    puts $file_handle ""
    
    # Generate cosim commands for each configuration
    foreach config $all_project_configs {
        dict with config {
            set project_dir $project_name
            
            puts $file_handle "# Co-simulation for $project_name/$solution_name"
            puts $file_handle "if {\[file exists $project_dir\]} {"
            puts $file_handle "    log_cosim \"Running co-simulation for $project_name/$solution_name...\""
            puts $file_handle "    "
            puts $file_handle "    # Open project"
            puts $file_handle "    open_project $project_dir"
            puts $file_handle "    open_solution $solution_name"
            puts $file_handle "    "
            puts $file_handle "    # Check if synthesis is completed first"
            puts $file_handle "    set syn_dir \"$project_dir/$solution_name/syn\""
            puts $file_handle "    if {\[file exists \$syn_dir\] && \[file exists \$syn_dir/report\]} {"
            puts $file_handle "        # Run co-simulation with default settings"
            puts $file_handle "        cosim_design"
            puts $file_handle "        "
            puts $file_handle "        # Check results"
            puts $file_handle "        set cosim_dir \"$project_dir/$solution_name/sim\""
            puts $file_handle "        if {\[file exists \$cosim_dir\]} {"
            puts $file_handle "            log_cosim \"Co-simulation completed for $project_name/$solution_name\""
            puts $file_handle "        } else {"
            puts $file_handle "            log_cosim \"WARNING: Co-simulation may have failed for $project_name/$solution_name\""
            puts $file_handle "        }"
            puts $file_handle "    } else {"
            puts $file_handle "        log_cosim \"WARNING: Synthesis not completed for $project_name/$solution_name - skipping co-simulation\""
            puts $file_handle "    }"
            puts $file_handle "    "
            puts $file_handle "    close_project"
            puts $file_handle "} else {"
            puts $file_handle "    log_cosim \"WARNING: Project directory not found: $project_dir\""
            puts $file_handle "}"
            puts $file_handle ""
        }
    }
    
    puts $file_handle "log_cosim \"Co-simulation completed for all projects.\""
    puts $file_handle "close \$log_handle"
    puts $file_handle "puts \"Co-simulation results logged to: \$log_file\""
    
    close $file_handle
    log_info "Generated co-simulation script: $script_file"
}

# =============================================================================
# Entry Point
# =============================================================================

# Check if running in Vitis HLS
if {[info exists ::env(VITIS_HLS_HOME)] || [info exists ::env(VIVADO_HLS_HOME)] || [info commands open_project] != ""} {
    # Running in Vitis HLS environment
    set exit_code [main]
    
    # Generate additional utility scripts
    generate_synthesis_script
    generate_report_script
    generate_csim_script
    generate_cosim_script
    
    log_info "Additional utility scripts generated in $PROJECTS_DIR"
    log_info "- run_all_synthesis.tcl: Batch synthesis for all projects"
    log_info "- extract_reports.tcl: Extract synthesis reports (template)"
    log_info "- run_all_csim.tcl: Batch C simulation for all projects"
    log_info "- run_all_cosim.tcl: Batch co-simulation for all projects"
    
    if {$exit_code == 0} {
        log_info "Script completed successfully"
    } else {
        log_error "Script completed with errors"
    }
} else {
    # Running in regular Tclsh
    puts "This script must be run with Vitis HLS (2024.1 or later):"
    puts "  vitis-run --mode hls --tcl generate_hls_projects.tcl"
    puts ""
    puts "Or for legacy Vivado HLS:"
    puts "  vivado_hls -f generate_hls_projects.tcl"
    puts ""
    puts "Or source it within Vitis HLS:"
    puts "  vitis-run --mode hls"
    puts "  Vitis HLS% source generate_hls_projects.tcl"
    exit 1
}