# decode_syn.tcl

########################### Define Top Module ############################
set top_level VX_decode

########################### Formality Setup file ############################

set_svf "VX_decode.svf"

##################### Define Working Library Directory ######################
                                                   
define_design_lib work -path ./work

################## Design Compiler Library Files #setup ######################

puts "###########################################"
puts "#      #setting Design Libraries           #"
puts "###########################################"

#Add the path of the libraries to the search_path variable
lappend search_path /home/IC/Graduation_Project/std_cells
lappend search_path /home/IC/Graduation_Project/Decode_Stage/rtl

set SSLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set TTLIB "NangateOpenCellLibrary_tt1p1v25c.db"
set FFLIB "NangateOpenCellLibrary_ff1p25vn40c.db"

## Standard Cell libraries 
set target_library [list $SSLIB $TTLIB $FFLIB]

## Standard Cell & Hard Macros libraries 
set link_library [list * $SSLIB $TTLIB $FFLIB]


puts "###########################################"
puts "#             Reading RTL Files           #"
puts "###########################################"

set verilog_files [list \
    VX_gpu_pkg.sv \
    VX_placeholder.sv \
    VX_reduce_tree.sv \
    VX_popcount.sv \
    VX_edge_trigger.sv \
    VX_reset_relay.sv \
    VX_shift_register.sv \
    VX_async_ram_patch.sv \
    VX_dp_ram.sv \
    VX_pending_size.sv \
    VX_pipe_register.sv \
    VX_pipe_buffer.sv \
    VX_stream_buffer.sv \
    VX_fifo_queue.sv \
    VX_elastic_buffer.sv \
    VX_fetch_if.sv \
    VX_decode_if.sv \
    VX_decode_sched_if.sv \
    VX_decode.sv \
]

# 4. Clean and Analyze
remove_design -all
analyze -format sverilog $verilog_files
elaborate $top_level

###################### Defining toplevel ###################################

current_design $top_level

# 5. Check for Linking Issues
link
check_design
############################### Path groups ################################
#group_path -name INREG -from [all_inputs]
#group_path -name REGOUT -to [all_outputs]
#group_path -name INOUT -from [all_inputs] -to [all_outputs]

# 6. Apply Constraints
source -echo ./cons.tcl

# 7. Compile
# Use compile with high map effort for best results
compile -map_effort high

##################### Close Formality Setup file ###########################
set_svf -off

# 8. Report Results
report_area -hierarchy > Reports/area.rpt
report_power -hierarchy > Reports/power.rpt
report_timing -max_paths 1 -delay_type min > Reports/hold.rpt
report_timing -max_paths 1 -delay_type max > Reports/setup.rpt
report_clock -attributes > Reports/clocks.rpt
report_constraint -all_violators > Reports/constraints.rpt

# 9. Save Results
write -hierarchy -format verilog -hierarchy -output ${top_level}_netlist.v
write -hierarchy -format ddc -hierarchy -output ${top_level}.ddc
write_sdc -nosplit ${top_level}.sdc
write_sdf          ${top_level}.sdf

#exit
