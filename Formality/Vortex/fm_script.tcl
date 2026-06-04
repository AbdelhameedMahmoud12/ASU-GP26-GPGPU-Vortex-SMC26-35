
###################################################################
########################### Variables #############################
###################################################################

set SSLIB "/home/IC/Vortex/std_cells/scmetro_tsmc_cl013g_rvt_ss_1p08v_125c.db"
set TTLIB "/home/IC/Vortex/std_cells/scmetro_tsmc_cl013g_rvt_tt_1p2v_25c.db"
set FFLIB "/home/IC/Vortex/std_cells/scmetro_tsmc_cl013g_rvt_ff_1p32v_m40c.db"

###################################################################
############################ Guidance #############################
###################################################################

# Synopsys setup variable

set synopsys_auto_setup true

# Formality Setup File

set_svf "/home/IC/Vortex/syn/Vortex_axi.svf"

###################################################################
###################### Reference Container ########################
###################################################################

lappend search_path /home/IC/Vortex
lappend search_path /home/IC/Vortex/interfaces
lappend search_path /home/IC/Vortex/VH
lappend search_path /home/IC/Vortex/std_cells

# Read Reference Design Verilog Files
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } "/home/IC/Vortex/VX_gpu_pkg.sv"
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } "/home/IC/Vortex/VX_fpu_pkg.sv"
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } "/home/IC/Vortex/VX_tcu_pkg.sv"
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } "/home/IC/Vortex/VX_trace_pkg.sv"
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } [glob /home/IC/Vortex/interfaces/*.sv]
read_sverilog -container Ref -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } [glob /home/IC/Vortex/rtl/*.sv]
# Read Reference technology libraries

read_db -container Ref [list $SSLIB $TTLIB $FFLIB]

# set the top Reference Design 
set_reference_design Vortex_axi
set_top Vortex_axi



###################################################################
#################### Implementation Container #####################
###################################################################

# Read Implementation Design Files
read_verilog -container Imp -netlist "/home/IC/Vortex/syn/Vortex_axi_netlist.v"


# Read Implementation technology libraries
read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

# set the top Implementation Design
set_implementation_design Vortex_axi
set_top Vortex_axi


###################################################################
#################### Pre-Match Settings ###########################
###################################################################

# Help FM handle synthesis optimizations
set_app_var verification_set_undriven_signals synthesis
set_app_var hdlin_ignore_full_case false

###################### Matching Compare points ####################

match

###################################################################
############# Post-Match: Exclude Unverifiable Points #############
###################################################################
#
# IMPORTANT: set_dont_verify_point must be called AFTER match
# because compare point names only exist after matching.
#



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


