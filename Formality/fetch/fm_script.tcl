
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

set_svf "/home/IC/fetch/syn/VX_fetch.svf"

###################################################################
###################### Reference Container ########################
###################################################################

lappend search_path /home/IC/fetch
lappend search_path /home/IC/fetch/interfaces
lappend search_path /home/IC/fetch/VH
lappend search_path /home/IC/fetch/std_cells

# Read Reference Design Verilog Files
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } "/home/IC/fetch/VX_gpu_pkg.sv"
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } "/home/IC/fetch/VX_fpu_pkg.sv"
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } "/home/IC/fetch/VX_trace_pkg.sv"
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } [glob /home/IC/fetch/interfaces/*.sv]
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } [glob /home/IC/fetch/rtl/*.sv]
read_sverilog -container Ref  -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } "/home/IC/fetch/VX_fetch.sv"
# Read Reference technology libraries
read_db -container Ref [list $SSLIB $TTLIB $FFLIB]

# set the top Reference Design 
set_reference_design VX_fetch
set_top VX_fetch



###################################################################
#################### Implementation Container #####################
###################################################################

# Read Implementation Design Files
read_verilog -container Imp -netlist "/home/IC/fetch/syn/VX_fetch_netlist.v"


# Read Implementation technology libraries
read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

# set the top Implementation Design
set_implementation_design VX_fetch
set_top VX_fetch



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

