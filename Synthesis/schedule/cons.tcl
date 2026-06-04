
# Constraints
# ----------------------------------------------------------------------------
#
# 1. Master Clock Definitions
#
# 2. Generated Clock Definitions
#
# 3. Clock Uncertainties
#
# 4. Clock Latencies 
#
# 5. Clock Relationships
#
# 6. set input/output delay on ports
#
# 7. Driving cells
#
# 8. Output load

####################################################################################
           #########################################################
                  #### Section 1 : Clock Definition ####
           #########################################################
#################################################################################### 
# 1. Master Clock Definitions 
# 2. Generated Clock Definitions
# 3. Clock Latencies
# 4. Clock Uncertainties
# 4. Clock Transitions
####################################################################################

set CLK_NAME CLK
set CLK_PER 4
set CLK_SETUP_SKEW 0.25
set CLK_HOLD_SKEW 0.05
set CLK_LAT 0
set CLK_RISE 0.1
set CLK_FALL 0.1
			  

####################################################################################
           #########################################################
                  #### Section 2 : Clocks Relationships ####
           #########################################################
####################################################################################

create_clock -name $CLK_NAME -period $CLK_PER -waveform "0 [expr $CLK_PER/2]" [get_ports clk]
set_clock_uncertainty -setup $CLK_SETUP_SKEW [get_clocks $CLK_NAME]
set_clock_uncertainty -hold $CLK_HOLD_SKEW  [get_clocks $CLK_NAME]
set_clock_transition -rise $CLK_RISE  [get_clocks $CLK_NAME]
set_clock_transition -fall $CLK_FALL  [get_clocks $CLK_NAME]
set_clock_latency $CLK_LAT [get_clocks $CLK_NAME]

set_dont_touch_network CLK

####################################################################################
           #########################################################
             #### Section 3 : set input/output delay on ports ####
           #########################################################
####################################################################################

set in_delay  [expr 0.3*$CLK_PER]
set out_delay [expr 0.3*$CLK_PER]
#Indvidual Ports
set_input_delay $in_delay -clock $CLK_NAME [get_ports base_dcrs[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports busy]
# --- Constraints for 'warp_ctl_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.wid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.wspawn[*]]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.tmc[*]]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.split[*]]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.sjoin[*]]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.barrier[*]]
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.dvstack_wid]
#Constrain Output 
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.dvstack_ptr]


# --- Constraints for 'branch_ctl_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].wid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].taken]
set_input_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].dest]

# --- Constraints for 'issue_sched_if.' (slave) ---
#Constrain Input 

set_input_delay $in_delay -clock $CLK_NAME [get_ports issue_sched_if[*].valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports issue_sched_if[*].wis]

# --- Constraints for 'schedule_csr_if' (Master) ---
#Constrain Input

set_input_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.alm_empty_wid]
set_input_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.unlock_wid]
set_input_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.unlock_warp]

#Constrain Output 
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.cycles]
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.active_warps]
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.thread_masks]
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.alm_empty]

# --- Constraints for 'decode_sched_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports decode_sched_if.valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports decode_sched_if.unlock]
set_input_delay $in_delay -clock $CLK_NAME [get_ports decode_sched_if.wid]

# --- Constraints for 'commit_sched_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports commit_sched_if.committed_warps]

# --- Constraints for 'schedule_if' (master) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports schedule_if.ready]
#Constrain Output 
set_output_delay $out_delay -clock $CLK_NAME [get_ports schedule_if.valid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports schedule_if.data[*]]

####################################################################################
####################################################################################
           #########################################################
                  #### Section 4 : Driving cells ####
           #########################################################
####################################################################################

# --- Individual Ports ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports base_dcrs[*]]

# --- warp_ctl_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.wid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.wspawn[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.tmc[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.split[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.sjoin[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.barrier[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.dvstack_wid]

# --- branch_ctl_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports branch_ctl_if[*].valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports branch_ctl_if[*].wid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports branch_ctl_if[*].taken]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports branch_ctl_if[*].dest]

# --- issue_sched_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports issue_sched_if[*].valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports issue_sched_if[*].wis]

# --- sched_csr_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.alm_empty_wid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.unlock_wid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.unlock_warp]

# --- decode_sched_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports decode_sched_if.valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports decode_sched_if.unlock]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports decode_sched_if.wid]

# --- commit_sched_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports commit_sched_if.committed_warps]

# --- schedule_if inputs ---
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports schedule_if.ready]

####################################################################################
           #########################################################
                  #### Section 5 : Output load ####
           #########################################################
####################################################################################

# --- Individual Outputs ---
set_load 0.5 [get_ports busy]

# --- warp_ctl_if outputs ---
set_load 0.5 [get_ports warp_ctl_if.dvstack_ptr]

# --- sched_csr_if outputs ---
set_load 0.5 [get_ports sched_csr_if.cycles]
set_load 0.5 [get_ports sched_csr_if.active_warps]
set_load 0.5 [get_ports sched_csr_if.thread_masks]
set_load 0.5 [get_ports sched_csr_if.alm_empty]

# --- schedule_if outputs ---
set_load 0.5 [get_ports schedule_if.valid]
set_load 0.5 [get_ports schedule_if.data[*]]
####################################################################################
           #########################################################
                 #### Section 6 : Operating Condition ####
           #########################################################
####################################################################################

# Define the Worst Library for Max(#setup) analysis
# Define the Best Library for Min(hold) analysis

set_operating_conditions -min_library "NangateOpenCellLibrary_ff1p25vn40c" -min "low_temp" -max_library "NangateOpenCellLibrary_ss0p95v125c" -max "slow"





