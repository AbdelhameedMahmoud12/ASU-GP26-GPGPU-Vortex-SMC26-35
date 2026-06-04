########################### Define Top Module ############################

set top_module VX_commit

# Add the path of the libraries to the search_path variable
lappend search_path /home/IC/commit/std_cells
lappend search_path /home/IC/commit/VH
lappend search_path /home/IC/commit
lappend search_path /home/IC/commit/rtl



set SSLIB "NangateOpenCellLibrary_ff1p25vn40c.db"
set TTLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set FFLIB "NangateOpenCellLibrary_tt1p1v25c.db"

######################### Formality Setup File ###########################

set synopsys_auto_setup true

set_svf "/home/IC/commit/syn/VX_commit.svf"

######################### Reference (RTL) ################################

## Read technology libraries
read_db [list $SSLIB $TTLIB $FFLIB]

## Read Reference Design Files (RTL) using -r flag
read_verilog  -r -define {SYNTHESIS} [glob /home/IC/commit/VH/*.vh]
read_sverilog -r -define {EXT_F_ENABLE NDEBUG} /home/IC/commit/VX_gpu_pkg.sv
read_sverilog -r -define {SYNTHESIS} /home/IC/commit/VX_trace_pkg.sv
read_sverilog -r -define {SYNTHESIS} [glob /home/IC/commit/rtl/*.sv]

## Set the top Reference Design
set_top r:/WORK/$top_module

######################## Implementation (Netlist) #########################

## Read Implementation Design Files (Gate-level netlist) using -i flag
read_verilog -i -netlist /home/IC/commit/syn/VX_commit_netlist.v

## Set the top Implementation Design
set_top i:/WORK/$top_module

######################## Match & Verify ##################################

## Match compare points
match

## Verify equivalence
set successful [verify]
if {!$successful} {
    diagnose
    analyze_points -failing
}

######################## Reports #########################################

## Make sure reports directory exists
file mkdir reports

report_passing_points    > "reports/passing_points.rpt"
report_failing_points    > "reports/failing_points.rpt"
report_aborted_points    > "reports/aborted_points.rpt"
report_unverified_points > "reports/unverified_points.rpt"

start_gui

#exit


