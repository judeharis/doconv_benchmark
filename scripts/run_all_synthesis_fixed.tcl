# Fixed synthesis script for deconv projects
# This script properly sets up files and top function before synthesis

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set PROJECTS_DIR $SCRIPT_DIR

# Function to synthesize a single project
proc synthesize_project {project_path} {
    set project_name [file tail $project_path]
    puts "Synthesizing project: $project_name"
    
    # Open project
    open_project $project_path
    
    # Set top function
    set_top deconv_top
    
    # Add source files if they're not already added
    set source_files [glob -nocomplain "${project_path}/*.cpp"]
    foreach src_file $source_files {
        if {[file tail $src_file] ne "deconv_tb.cpp"} {
            add_files $src_file
        }
    }
    
    # Add header files  
    set header_files [glob -nocomplain "${project_path}/*.hpp"]
    foreach hdr_file $header_files {
        add_files $hdr_file
    }
    
    # Add testbench
    set tb_file "${project_path}/deconv_tb.cpp"
    if {[file exists $tb_file]} {
        add_files -tb $tb_file
    }
    
    # Find and synthesize all solutions
    set solution_dirs [glob -nocomplain -directory $project_path -type d "solution*"]
    foreach solution_dir $solution_dirs {
        set solution_name [file tail $solution_dir]
        puts "  Synthesizing solution: $solution_name"
        
        open_solution $solution_name
        
        # Run synthesis
        if {[catch {csynth_design} result]} {
            puts "ERROR: Synthesis failed for $solution_name: $result"
        } else {
            puts "  Synthesis completed for $solution_name"
        }
        
        close_solution
    }
    
    close_project
    puts "Completed project: $project_name"
    puts ""
}

# Main execution
puts "Starting synthesis of all deconv projects..."
puts ""

# Find all project directories
set project_dirs [glob -nocomplain -directory $PROJECTS_DIR -type d "deconv_*"]

if {[llength $project_dirs] == 0} {
    puts "ERROR: No deconv projects found in $PROJECTS_DIR"
    puts "Please run the project generator first."
    exit 1
}

puts "Found [llength $project_dirs] project(s) to synthesize:"
foreach project_dir $project_dirs {
    puts "  [file tail $project_dir]"
}
puts ""

# Synthesize each project
foreach project_dir $project_dirs {
    if {[catch {synthesize_project $project_dir} result]} {
        puts "ERROR: Failed to synthesize [file tail $project_dir]: $result"
        continue
    }
}

puts "Synthesis script completed."