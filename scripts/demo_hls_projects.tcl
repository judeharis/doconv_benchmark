#!/usr/biset SCRIPT_DIR [file dirname [file normalize [info script]]]
set BASE_DIR [file dirname $SCRIPT_DIR]
set CONFIG_DIR "${BASE_DIR}/generated_configs"
set SRC_DIR "${BASE_DIR}/src"
set PROJECTS_DIR "${BASE_DIR}/hls_projects_demo"v tclsh

# =============================================================================
# HLS Project Generator - Demo Mode
# =============================================================================
# This script demonstrates what the HLS project generator would do
# without requiring Vivado HLS to be installed.
# =============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set CONFIG_DIR "${SCRIPT_DIR}/generated_configs"
set SRC_DIR "${SCRIPT_DIR}/src"
set PROJECTS_DIR "${SCRIPT_DIR}/hls_projects_demo"

proc log_info {message} {
    puts "\[INFO\] $message"
}

proc log_error {message} {
    puts "\[ERROR\] $message"
}

proc parse_config_filename {filename} {
    if {[regexp {deconv_top_K(\d+)_S(\d+)_H(\d+)_W(\d+)_CI(\d+)_CO(\d+)_P(\d+)\.hpp} $filename match K S H W CI CO P]} {
        return [list $K $S $H $W $CI $CO $P]
    } else {
        return {}
    }
}

proc extract_pe_simd_configs {header_file} {
    set configs {}
    if {![file exists $header_file]} {
        return [list [list 1 1]]
    }
    
    set file_handle [open $header_file r]
    set content [read $file_handle]
    close $file_handle
    
    set lines [split $content "\n"]
    set in_config_section 0
    set current_pe ""
    set current_simd ""
    
    foreach line $lines {
        if {[regexp {#if\s+1} $line] || [regexp {#else} $line]} {
            set in_config_section 1
        } elseif {[regexp {#endif} $line]} {
            set in_config_section 0
        }
        
        if {$in_config_section} {
            if {[regexp {constexpr\s+unsigned\s+PE\s*=\s*(\d+);} $line match pe]} {
                set current_pe $pe
            }
            if {[regexp {constexpr\s+unsigned\s+SIMD\s*=\s*(\d+);} $line match simd]} {
                set current_simd $simd
                if {$current_pe != ""} {
                    lappend configs [list $current_pe $current_simd]
                    set current_pe ""
                    set current_simd ""
                }
            }
        }
    }
    
    if {[llength $configs] == 0} {
        lappend configs [list 1 1]
    }
    
    return $configs
}

proc create_demo_project {project_name config_params pe_simd_configs config_file} {
    global PROJECTS_DIR SRC_DIR
    
    lassign $config_params K S H W CI CO
    set project_dir "${PROJECTS_DIR}/${project_name}"
    
    log_info "Creating demo project: $project_name"
    log_info "  Configuration: K=$K, S=$S, H=$H, W=$W, CI=$CI, CO=$CO"
    
    # Create project directory
    file mkdir $project_dir
    
    # Copy configuration header
    file copy -force $config_file "${project_dir}/deconv_top.hpp"
    log_info "  Copied configuration header"
    
    # Copy source files
    set source_files {deconv_top.cpp deconv.hpp utils.hpp deconv_tb.cpp}
    foreach src_file $source_files {
        set src_path "${SRC_DIR}/${src_file}"
        if {[file exists $src_path]} {
            file copy -force $src_path "${project_dir}/${src_file}"
            log_info "  Copied: $src_file"
        }
    }
    
    # Create solution directories and info files
    set solution_count 1
    foreach pe_simd $pe_simd_configs {
        lassign $pe_simd pe simd
        set solution_name "solution${solution_count}_PE${pe}_SIMD${simd}"
        set solution_dir "${project_dir}/${solution_name}"
        
        file mkdir $solution_dir
        log_info "  Created solution: $solution_name (PE=$pe, SIMD=$simd)"
        
        # Create a demo info file
        set info_file [open "${solution_dir}/solution_info.txt" w]
        puts $info_file "Solution: $solution_name"
        puts $info_file "PE: $pe"
        puts $info_file "SIMD: $simd"
        puts $info_file "Target Device: xczu3eg-sbva484-1-i"
        puts $info_file "Clock Period: 5ns (200MHz)"
        puts $info_file ""
        puts $info_file "HLS Directives:"
        puts $info_file "- Interface: ap_ctrl_none for return"
        puts $info_file "- Interface: axis for src and dst"
        puts $info_file "- Dataflow optimization enabled"
        close $info_file
        
        incr solution_count
    }
    
    # Create a project makefile
    set makefile [open "${project_dir}/Makefile" w]
    puts $makefile "# Demo Makefile for $project_name"
    puts $makefile "# This would normally run HLS synthesis"
    puts $makefile ""
    puts $makefile "PROJECT = $project_name"
    puts $makefile "TOP_FUNC = deconv_top"
    puts $makefile ""
    puts $makefile "all:"
    puts $makefile "\t@echo \"Would synthesize project: \$(PROJECT)\""
    puts $makefile "\t@echo \"Top function: \$(TOP_FUNC)\""
    puts $makefile "\t@echo \"Configuration: K=$K, S=$S, H=$H, W=$W, CI=$CI, CO=$CO\""
    puts $makefile ""
    puts $makefile "clean:"
    puts $makefile "\t@echo \"Would clean synthesis results\""
    puts $makefile ""
    puts $makefile ".PHONY: all clean"
    close $makefile
    
    return 1
}

proc main {} {
    global CONFIG_DIR PROJECTS_DIR
    
    log_info "Starting HLS project demo generation"
    log_info "Configuration directory: $CONFIG_DIR"
    log_info "Demo projects directory: $PROJECTS_DIR"
    
    # Create projects directory
    file mkdir $PROJECTS_DIR
    
    # Find configuration files
    set config_files [glob -nocomplain -directory $CONFIG_DIR "deconv_top_K*_S*_H*_W*_CI*_CO*_P*.hpp"]
    
    if {[llength $config_files] == 0} {
        log_error "No configuration files found in $CONFIG_DIR"
        return 1
    }
    
    log_info "Found [llength $config_files] configuration files"
    
    # Process each configuration
    set successful_projects 0
    
    foreach config_file $config_files {
        set filename [file tail $config_file]
        log_info "Processing: $filename"
        
        set config_params [parse_config_filename $filename]
        if {[llength $config_params] != 7} {
            log_error "Could not parse: $filename"
            continue
        }
        
        set pe_simd_configs [extract_pe_simd_configs $config_file]
        
        lassign $config_params K S H W CI CO P
        set project_name "deconv_K${K}_S${S}_H${H}_W${W}_CI${CI}_CO${CO}_P${P}"
        
        if {[create_demo_project $project_name $config_params $pe_simd_configs $config_file]} {
            incr successful_projects
        }
        
        puts ""
    }
    
    # Create summary
    log_info "Demo project generation completed"
    log_info "Successfully created: $successful_projects projects"
    
    # Create a summary script
    set summary_script [open "${PROJECTS_DIR}/run_demo.sh" w]
    puts $summary_script "#!/bin/bash"
    puts $summary_script "# Demo script to show what would be synthesized"
    puts $summary_script ""
    puts $summary_script "echo \"=== HLS Project Demo ===\""
    puts $summary_script "echo \"This demonstrates the projects that would be created\""
    puts $summary_script "echo \"\""
    
    set project_dirs [glob -nocomplain -directory $PROJECTS_DIR -type d "deconv_*"]
    foreach project_dir $project_dirs {
        set project_name [file tail $project_dir]
        puts $summary_script "echo \"Project: $project_name\""
        puts $summary_script "cd $project_dir && make"
        puts $summary_script "echo \"\""
    }
    
    close $summary_script
    file attributes "${PROJECTS_DIR}/run_demo.sh" -permissions +x
    
    log_info "Created demo runner: ${PROJECTS_DIR}/run_demo.sh"
    log_info "Run it with: bash ${PROJECTS_DIR}/run_demo.sh"
    
    return 0
}

# Run the demo
exit [main]