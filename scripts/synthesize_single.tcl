#!/usr/bin/env tclsh

# Single Project Synthesis Script
# Usage: vitis-run --mode hls --tcl synthesize_single.tcl [project_path]

if {$argc < 1} {
    puts "ERROR: Project path required"
    puts "Usage: vitis-run --mode hls --tcl synthesize_single.tcl <project_path>"
    exit 1
}

set project_path [lindex $argv 0]

if {![file exists $project_path]} {
    puts "ERROR: Project path does not exist: $project_path"
    exit 1
}

set project_name [file tail $project_path]
puts "Synthesizing project: $project_name"
puts "Project path: $project_path"

# Open project
open_project $project_path

# Set top function
set_top deconv_top

# List existing files in project
puts "Current project files:"
foreach file [get_files] {
    puts "  $file"
}

# Find and synthesize all solutions
set solution_dirs [glob -nocomplain -directory $project_path -type d "solution*"]

if {[llength $solution_dirs] == 0} {
    puts "ERROR: No solutions found in project"
    close_project
    exit 1
}

puts "Found [llength $solution_dirs] solution(s):"
foreach solution_dir $solution_dirs {
    puts "  [file tail $solution_dir]"
}

foreach solution_dir $solution_dirs {
    set solution_name [file tail $solution_dir]
    puts ""
    puts "Synthesizing solution: $solution_name"
    
    open_solution $solution_name
    
    # Show solution configuration
    puts "Solution configuration:"
    puts "  Part: [get_part]"
    puts "  Clock: [get_clock]"
    
    # Run synthesis
    puts "Running C synthesis..."
    if {[catch {csynth_design} result]} {
        puts "ERROR: Synthesis failed for $solution_name"
        puts "Error details: $result"
    } else {
        puts "SUCCESS: Synthesis completed for $solution_name"
        
        # Show results if available
        set rpt_file "${solution_dir}/syn/report/deconv_top_csynth.rpt"
        if {[file exists $rpt_file]} {
            puts "Synthesis report available: $rpt_file"
        }
    }
    
    close_solution
}

close_project
puts ""
puts "Project synthesis completed: $project_name"