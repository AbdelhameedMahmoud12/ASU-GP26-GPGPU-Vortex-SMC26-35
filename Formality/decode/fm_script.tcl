
###################################################################
########################### Variables #############################
###################################################################
set SSLIB "/home/IC/Graduation_Project/std_cells/NangateOpenCellLibrary_ss0p95v125c.db"
set TTLIB "/home/IC/Graduation_Project/std_cells/NangateOpenCellLibrary_tt1p1v25c.db"
set FFLIB "/home/IC/Graduation_Project/std_cells/NangateOpenCellLibrary_ff1p25vn40c.db"


###################################################################
############################ Guidance #############################
###################################################################

# Synopsys setup variable
set synopsys_auto_setup true

# Formality Setup File
set_svf "/home/IC/Graduation_Project/Decode_Stage/Baseline_32_(RV32IMF)/syn/VX_decode.svf"

###################################################################
###################### Reference Container ########################
###################################################################
# Read Reference Design Verilog Files
read_sverilog -container REF {
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_gpu_pkg.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_placeholder.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_reduce_tree.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_popcount.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_edge_trigger.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_reset_relay.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_shift_register.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_async_ram_patch.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_dp_ram.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_pending_size.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_pipe_register.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_pipe_buffer.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_stream_buffer.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_fifo_queue.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_elastic_buffer.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_fetch_if.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_decode_if.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_decode_sched_if.sv"
    "/home/IC/Graduation_Project/Decode_Stage/rtl/VX_decode.sv"
}

# Read Reference technology libraries
read_db -container Ref [list $SSLIB $TTLIB $FFLIB]

# set the top Reference Design 
set_reference_design VX_decode
set_top VX_decode


###################################################################
#################### Implementation Container #####################
###################################################################

# Read Implementation Design Files
read_verilog -container Imp -netlist "/home/IC/Graduation_Project/Decode_Stage/Baseline_32_(RV32IMF)/syn/VX_decode_netlist.v"

# Read Implementation technology libraries
read_db -container Imp [list $SSLIB $TTLIB $FFLIB]

# set the top Implementation Design
set_implementation_design VX_decode
set_top VX_decode

###################### Matching Compare points ####################

match

######################### Run Verification ########################

set successful [verify]
if {!$successful} {
diagnose
analyze_points -failing
}

########################### Reporting ############################# 
report_passing_points > "Reports/passing_points.rpt"
report_failing_points > "Reports/failing_points.rpt"
report_aborted_points > "Reports/aborted_points.rpt"
report_unverified_points > "Reports/unverified_points.rpt"


start_gui

