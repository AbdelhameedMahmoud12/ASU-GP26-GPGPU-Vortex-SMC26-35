
########################### Define Top Module ############################
                                                   
set top_module VX_issue

######################### Formality Setup File ###########################

set synopsys_auto_setup true

set_svf "/home/IC/Issue/syn/default.svf"


puts "###########################################"
puts "#      #setting Design Libraries          #"
puts "###########################################"

#Add the path of the libraries to the search_path variable
lappend search_path /home/IC/Issue/std_cells
lappend search_path /home/IC/Issue/VHDL
lappend search_path /home/IC/Issue/RTL
lappend search_path /home/IC/Issue/RTL/interfaces


set SSLIB "NangateOpenCellLibrary_ff1p25vn40c.db"
set TTLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set FFLIB "NangateOpenCellLibrary_tt1p1v25c.db"
## Standard Cell libraries 
## Standard Cell & Hard Macros libraries 
set target_library [list $TTLIB $FFLIB $SSLIB]
set link_library   [list $TTLIB $FFLIB $SSLIB]


######################### Reference Container ############################

## Read Reference technology libraries

read_db -container Ref [list $SSLIB $TTLIB $FFLIB]


## Read Reference Design Files
#read_verilog -container Ref [glob /home/IC/LSU/lsu_unit/VHDL/*.vh]
read_sverilog -define {NDEBUG } -container Ref ../VX_gpu_pkg.sv
read_sverilog -define {NDEBUG } -container Ref [glob ../RTL/interfaces/*.sv]
read_sverilog -define {NDEBUG } -container Ref [glob ../RTL/*.sv]
read_sverilog -define {NDEBUG } -container Ref ../VX_issue_slice.sv
read_sverilog -define {NDEBUG } -container Ref ../VX_issue.sv


## set the top Reference Design 

set_reference_design VX_issue
set_top VX_issue

######################## Implementation Container #########################

## Read Implementation technology libraries
read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

## Read Implementation Design Files
read_verilog -netlist -container Imp "/home/IC/Issue/syn/VX_issue_netlist.v"
 
## set the top Implementation Design
set_implementation_design VX_issue
set_top VX_issue


## Report undriven nets for debugging

## Fix dispatch_if interface array port mapping
## DC uses C-style indexing for [3:0] interface arrays (ELAB-012),

match

## Report matching results for debugging
report_matched_points > reports/matched_points.rpt
report_unmatched_points > reports/unmatched_points.rpt

## verify
set successful [verify]
if {!$successful} {
diagnose
analyze_points -failing
}

## Generate comprehensive reports
report_passing_points > reports/passing_points.rpt
report_failing_points > reports/failing_points.rpt
report_aborted_points > reports/aborted_points.rpt
report_unverified_points > reports/unverified_points.rpt
report_unread_points > reports/unread_points.rpt
report_constants > reports/constants.rpt

## Summary
puts "\n=========================================="
puts "Verification Summary"
puts "=========================================="
puts "Note: Unread points ([sizeof_collection [get_cells -hierarchical -filter @is_unread==true]]) are expected due to:"
puts "  - PID_BITS=0 (NUM_THREADS=NUM_LANES=4)"
puts "  - UUID_WIDTH=1 (NDEBUG defined)"
puts "  - BLOCK_SIZE=1 (single block, no arbitration)"
puts "These are parameter-dependent generate blocks that are correctly"
puts "optimized away during synthesis."
puts "==========================================\n"




