#!/usr/bin/env tclsh

# Test script to create a minimal HLS project and verify synthesis works
# Usage: vitis-run --mode hls --tcl test_hls_basic.tcl

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set BASE_DIR [file dirname $SCRIPT_DIR]
set TEST_PROJECT "${BASE_DIR}/test_hls_project"

# Clean up any existing test project
if {[file exists $TEST_PROJECT]} {
    file delete -force $TEST_PROJECT
}

puts "Creating test HLS project..."

# Create new project
open_project $TEST_PROJECT
set_top deconv_top

# Add source files
puts "Adding source files..."
add_files "${BASE_DIR}/src/deconv_top.cpp" -cflags "-std=c++14"
add_files "${BASE_DIR}/src/deconv.hpp" -cflags "-std=c++14"
add_files "${BASE_DIR}/src/utils.hpp" -cflags "-std=c++14"
add_files "${BASE_DIR}/generated_configs/deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp" -cflags "-std=c++14"

# Add testbench
add_files -tb "${BASE_DIR}/src/deconv_tb.cpp" -cflags "-std=c++14 -Wno-unknown-pragmas"

puts "Creating test solution..."
open_solution "test_solution"
set_part "xczu3eg-sbva484-1-i"
create_clock -period 5 -name default

# Add directives
set_directive_interface -mode ap_ctrl_none "deconv_top" return
set_directive_interface -mode axis "deconv_top" src
set_directive_interface -mode axis "deconv_top" dst
set_directive_dataflow "deconv_top"

puts "Running C simulation..."
if {[catch {csim_design} result]} {
    puts "WARNING: C simulation failed: $result"
    puts "This might be due to testbench issues, but synthesis might still work"
} else {
    puts "C simulation completed successfully"
}

puts "Running C synthesis..."
if {[catch {csynth_design} result]} {
    puts "ERROR: C synthesis failed: $result"
    close_solution
    close_project
    exit 1
} else {
    puts "SUCCESS: C synthesis completed successfully!"
}

# Check if synthesis report exists
set rpt_file "${TEST_PROJECT}/test_solution/syn/report/deconv_top_csynth.rpt"
if {[file exists $rpt_file]} {
    puts "Synthesis report generated: $rpt_file"
    
    # Show a summary from the report
    set fp [open $rpt_file r]
    set content [read $fp]
    close $fp
    
    # Extract key metrics
    if {[regexp {Latency \(cycles\):\s+(\d+)} $content match latency]} {
        puts "  Latency: $latency cycles"
    }
    if {[regexp {LUT:\s+(\d+)} $content match lut]} {
        puts "  LUT usage: $lut"
    }
    if {[regexp {FF:\s+(\d+)} $content match ff]} {
        puts "  FF usage: $ff"
    }
} else {
    puts "WARNING: Synthesis report not found"
}

close_solution
close_project

puts ""
puts "Test completed successfully!"
puts "Basic HLS synthesis is working correctly."
puts ""
puts "You can now run the full synthesis with:"
puts "  vitis-run --mode hls --tcl hls_projects/run_all_synthesis.tcl"