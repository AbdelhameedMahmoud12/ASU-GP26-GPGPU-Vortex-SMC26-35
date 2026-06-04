
###################################################################
########################### Variables #############################
###################################################################

set SSLIB "NangateOpenCellLibrary_ff1p25vn40c.db"
set TTLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set FFLIB "NangateOpenCellLibrary_tt1p1v25c.db"


###################################################################
############################ Guidance #############################
###################################################################

# Synopsys setup variable

set synopsys_auto_setup true

# Formality Setup File

set_svf "/home/IC/schedule/syn/VX_schedule.svf"

###################################################################
###################### Reference Container ########################
###################################################################

lappend search_path /home/IC/schedule
lappend search_path /home/IC/schedule/interfaces
lappend search_path /home/IC/schedule/VH
lappend search_path /home/IC/schedule/std_cells

# Read Reference Design Verilog Files
read_sverilog -container Ref -define {EXT_F_ENABLE NDEBUG} "/home/IC/schedule/VX_gpu_pkg.sv"
read_sverilog -container Ref "/home/IC/schedule/VX_fpu_pkg.sv"
read_sverilog -container Ref [glob /home/IC/schedule/rtl/*.sv]
read_sverilog -container Ref [glob /home/IC/schedule/interfaces/*.sv]

# Read Reference technology libraries
read_db -container Ref [list $SSLIB $TTLIB $FFLIB]

# set the top Reference Design 
set_reference_design VX_schedule
set_top VX_schedule



###################################################################
#################### Implementation Container #####################
###################################################################

# Read Implementation Design Files
read_verilog -container Imp -netlist "/home/IC/schedule/syn/VX_schedule_netlist.v"


# Read Implementation technology libraries
read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

# set the top Implementation Design
set_implementation_design VX_schedule
set_top VX_schedule



###################### Matching Compare points ####################

match

######################### Run Verification ########################

set successful [verify]
if {!$successful} {
diagnose
analyze_points -failing
}

########################### Reporting ############################# 
report_passing_points > "passing_points.rpt"
report_failing_points > "failing_points.rpt"
report_aborted_points > "aborted_points.rpt"
report_unverified_points > "unverified_points.rpt"


start_gui

