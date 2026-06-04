
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
set_dont_touch_network [get_ports reset]

####################################################################################
           #########################################################
             #### Section 3 : set input/output delay on ports ####
           #########################################################
####################################################################################

set in_delay  [expr 0.3*$CLK_PER]
set out_delay [expr 0.3*$CLK_PER]




# --- Constraints for 'commit_if' (slave) ---
#Constrain Input
set_input_delay $in_delay -clock $CLK_NAME [get_ports commit_if[*].valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports commit_if[*].data[*]]
#Constrain Output
set_output_delay $out_delay -clock $CLK_NAME [get_ports commit_if[*].ready]
# --- Constraints for 'write_back_if' (master) ---

#Constrain Output
set_output_delay $out_delay -clock $CLK_NAME [get_ports writeback_if[*].valid]
set_output_delay $out_delay -clock $CLK_NAME [get_ports writeback_if[*].data[*]]
# --- Constraints for 'commit_csr_if' (master) ---
#Constrain Output
set_output_delay $out_delay -clock $CLK_NAME [get_ports commit_csr_if.instret]
# --- Constraints for 'commit_sched_if' (master) ---

#Constrain Output
set_output_delay $out_delay -clock $CLK_NAME [get_ports commit_sched_if.committed_warps]

####################################################################################
####################################################################################
           #########################################################
                  #### Section 4 : Driving cells ####
           #########################################################
####################################################################################

# --- Input Ports ---
# --- commit_if inputs ---


set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c \
                 -lib_cell BUF_X2 -pin Z \
                 [get_ports commit_if[*].valid]

set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c \
                 -lib_cell BUF_X2 -pin Z \
                 [get_ports commit_if[*].data[*]]
####################################################################################
           #########################################################
                  #### Section 5 : Output load ####
           #########################################################
####################################################################################


# --- commit_if outputs ---
set_load 0.5 [get_ports commit_if[*].ready]
# --- writeback_if outputs ---
set_load 0.5 [get_ports writeback_if[*].valid]
set_load 0.5 [get_ports writeback_if[*].data[*]]
# --- commit_csr_if outputs ---
set_load 0.5 [get_ports commit_csr_if.instret]
# --- commit_sched_if outputs ---
set_load 0.5 [get_ports commit_sched_if.committed_warps]
####################################################################################
           #########################################################
                 #### Section 6 : Operating Condition ####
           #########################################################
####################################################################################

# Define the Worst Library for Max(#setup) analysis
# Define the Best Library for Min(hold) analysis

set_operating_conditions -min_library "NangateOpenCellLibrary_ff1p25vn40c" -min "low_temp" -max_library "NangateOpenCellLibrary_ss0p95v125c" -max "slow"





