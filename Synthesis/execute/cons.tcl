
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
set CLK_PER 30
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

set_input_delay $in_delay -clock $CLK_NAME [get_ports base_dcrs[*]]
# --- Constraints for 'lsu_mem_if' (master) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].req_ready]
set_input_delay $in_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].rsp_valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].rsp_data[*]]
#Constrain Output 

set_output_delay $out_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].req_valid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].rsp_ready]
set_output_delay $out_delay -clock $CLK_NAME [get_ports lsu_mem_if[*].req_data[*]]

####################################################################################

# --- Constraints for 'dispatch_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports dispatch_if[*].valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports dispatch_if[*].data[*]]

#Constrain Output 

set_output_delay $out_delay -clock $CLK_NAME [get_ports dispatch_if[*].ready]


####################################################################################

# --- Constraints for 'commit_if' (master) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports commit_if[*].ready]

#Constrain Output 

set_output_delay $out_delay -clock $CLK_NAME [get_ports commit_if[*].valid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports commit_if[*].data[*]]


####################################################################################

# --- Constraints for 'schedule_csr_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports sched_csr_if.cycles]
set_input_delay $in_delay -clock $CLK_NAME [get_ports sched_csr_if.active_warps]
set_input_delay $in_delay -clock $CLK_NAME [get_ports sched_csr_if.thread_masks]
set_input_delay $in_delay -clock $CLK_NAME [get_ports sched_csr_if.alm_empty]
#Constrain Output 

set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.alm_empty_wid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.unlock_wid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports sched_csr_if.unlock_warp]

####################################################################################

# --- Constraints for 'branch_ctl_if' (master) ---
#Constrain Input
set_output_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].valid]
set_output_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].wid]
set_output_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].taken]
set_output_delay $in_delay -clock $CLK_NAME [get_ports branch_ctl_if[*].dest]

####################################################################################

# --- Constraints for 'warp_ctl_if' (master) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports warp_ctl_if.dvstack_ptr]

#Constrain Output 


set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.valid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.wid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.wspawn[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.tmc[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.split[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.sjoin[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.barrier[*]]
set_output_delay $out_delay -clock $CLK_NAME [get_ports warp_ctl_if.dvstack_wid]
####################################################################################

# --- Constraints for 'commit_csr_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports commit_csr_if.instret]


####################################################################################
           #########################################################
                  #### Section 4 : Driving cells ####
           #########################################################
####################################################################################

set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports base_dcrs[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports lsu_mem_if[*].req_ready]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports lsu_mem_if[*].rsp_valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports lsu_mem_if[*].rsp_data[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports dispatch_if[*].valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports dispatch_if[*].data[*]]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports commit_if[*].ready]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.cycles]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.active_warps]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.thread_masks]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports sched_csr_if.alm_empty]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports warp_ctl_if.dvstack_ptr]

####################################################################################
           #########################################################
                  #### Section 5 : Output load ####
           #########################################################
####################################################################################

set_load 0.5  [get_ports lsu_mem_if[*].req_valid]
set_load 0.5  [get_ports lsu_mem_if[*].rsp_ready]
set_load 0.5  [get_ports lsu_mem_if[*].req_data[*]]
set_load 0.5  [get_ports dispatch_if[*].ready]
set_load 0.5  [get_ports commit_if[*].valid]
set_load 0.5  [get_ports commit_if[*].data[*]]
set_load 0.5  [get_ports sched_csr_if.alm_empty_wid]
set_load 0.5  [get_ports sched_csr_if.unlock_wid]
set_load 0.5  [get_ports sched_csr_if.unlock_warp]
set_load 0.5  [get_ports warp_ctl_if.valid]
set_load 0.5  [get_ports warp_ctl_if.wid]
set_load 0.5  [get_ports warp_ctl_if.wspawn[*]]
set_load 0.5  [get_ports warp_ctl_if.tmc[*]]
set_load 0.5  [get_ports warp_ctl_if.split[*]]
set_load 0.5  [get_ports warp_ctl_if.sjoin[*]]
set_load 0.5  [get_ports warp_ctl_if.barrier[*]]
set_load 0.5  [get_ports warp_ctl_if.dvstack_wid]
set_load 0.5 [get_ports branch_ctl_if[*].valid]
set_load 0.5 [get_ports branch_ctl_if[*].wid]
set_load 0.5 [get_ports branch_ctl_if[*].taken]
set_load 0.5 [get_ports branch_ctl_if[*].dest]
####################################################################################
           #########################################################
                 #### Section 6 : Operating Condition ####
           #########################################################
####################################################################################

# Define the Worst Library for Max(#setup) analysis
# Define the Best Library for Min(hold) analysis

set_operating_conditions -min_library "NangateOpenCellLibrary_ff1p25vn40c" -min "low_temp" -max_library "NangateOpenCellLibrary_ss0p95v125c" -max "slow"


####################################################################################
           #########################################################
                 #### Section 7 : Low Power ####
           #########################################################
####################################################################################
# Leakage power optimization — WORKS with single-Vt library
# DC will select smaller/lower-leakage cell variants to minimize static power
set_max_leakage_power 0

# Dynamic power optimization — WORKS with single-Vt library
# DC will optimize cell sizing to reduce switching activity
set_max_dynamic_power 0
