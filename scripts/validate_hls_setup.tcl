#!/usr/bin/env tclsh

# =============================================================================
# Simple HLS Project Generator - Test Version
# =============================================================================
# This is a simplified version that can be run outside of Vivado HLS 
# for testing and validation purposes.
# =============================================================================

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set BASE_DIR [file dirname $SCRIPT_DIR]
set CONFIG_DIR "${BASE_DIR}/generated_configs"
set SRC_DIR "${BASE_DIR}/src"
set PROJECTS_DIR "${BASE_DIR}/hls_projects"

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
        lappend configs [list 1 1]
    }
    
    return $configs
}

proc validate_and_show_projects {} {
    global CONFIG_DIR SRC_DIR PROJECTS_DIR
    
    log_info "Validating project generation setup..."
    log_info "Configuration directory: $CONFIG_DIR"
    log_info "Source directory: $SRC_DIR"
    log_info "Projects directory: $PROJECTS_DIR"
    
    # Check if directories exist
    foreach dir [list $CONFIG_DIR $SRC_DIR] {
        if {![file exists $dir]} {
            log_error "Directory not found: $dir"
            return 0
        }
    }
    
    # Find configuration files
    set config_files [glob -nocomplain -directory $CONFIG_DIR "deconv_top_K*_S*_H*_W*_CI*_CO*_P*.hpp"]
    
    if {[llength $config_files] == 0} {
        log_error "No configuration files found in $CONFIG_DIR"
        return 0
    }
    
    log_info "Found [llength $config_files] configuration files:"
    
    foreach config_file $config_files {
        set filename [file tail $config_file]
        set config_params [parse_config_filename $filename]
        
        if {[llength $config_params] == 7} {
            lassign $config_params K S H W CI CO P
            set pe_simd_configs [extract_pe_simd_configs $config_file]
            
            log_info "  $filename"
            log_info "    Parameters: K=$K, S=$S, H=$H, W=$W, CI=$CI, CO=$CO, P=$P"
            log_info "    PE/SIMD configs: $pe_simd_configs"
            
            # Show what project would be created
            set project_name "deconv_K${K}_S${S}_H${H}_W${W}_CI${CI}_CO${CO}_P${P}"
            log_info "    -> Would create project: $project_name"
            
            set solution_count 1
            foreach pe_simd $pe_simd_configs {
                lassign $pe_simd pe simd
                set solution_name "solution${solution_count}_PE${pe}_SIMD${simd}"
                log_info "       -> Solution: $solution_name"
                incr solution_count
            }
        } else {
            log_error "  Could not parse: $filename"
        }
        puts ""
    }
    
    # Check source files
    log_info "Checking source files in $SRC_DIR:"
    set required_files {deconv_top.cpp deconv.hpp utils.hpp deconv_tb.cpp}
    
    foreach file $required_files {
        set file_path "${SRC_DIR}/${file}"
        if {[file exists $file_path]} {
            log_info "  ✓ $file"
        } else {
            log_error "  ✗ $file (missing)"
        }
    }
    
    return 1
}

proc main {} {
    if {[validate_and_show_projects]} {
        log_info "Validation completed successfully!"
        log_info ""
        log_info "To actually generate HLS projects, run:"
        log_info "  vitis-run --mode hls --tcl scripts/generate_hls_projects.tcl"
        log_info "Or with legacy Vivado HLS:"
        log_info "  vivado_hls -f scripts/generate_hls_projects.tcl"
        return 0
    } else {
        log_error "Validation failed!"
        return 1
    }
}

# Run validation
exit [main]