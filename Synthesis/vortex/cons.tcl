
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


# --- Constraints for 'm_axi_aw' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_awready*]

set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awvalid*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awaddr*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awid*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awlen*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awsize*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awburst*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awlock*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awcache*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awprot*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awqos*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_awregion*]

# --- Constraints for 'm_axi_w' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_wready*]

set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_wvalid*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_wdata*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_wstrb*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_wlast*]

# --- Constraints for 'm_axi_b' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_bvalid*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_bid*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_bresp*]

set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_bready*]

# --- Constraints for 'm_axi_ar' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_arready*]

set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arvalid*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_araddr*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arid*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arlen*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arsize*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arburst*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arlock*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arcache*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arprot*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arqos*]
set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_arregion*]

# --- Constraints for 'm_axi_r' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_rvalid*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_rdata*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_rlast*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_rid*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports m_axi_rresp*]

set_output_delay $out_delay -clock $CLK_NAME [get_ports m_axi_rready*]

# --- Constraints for 'dcr' ---
set_input_delay $in_delay -clock $CLK_NAME [get_ports dcr_wr_valid]
set_input_delay $in_delay -clock $CLK_NAME [get_ports dcr_wr_addr*]
set_input_delay $in_delay -clock $CLK_NAME [get_ports dcr_wr_data*]

# --- Constraints for 'busy' ---
set_output_delay $out_delay -clock $CLK_NAME [get_ports busy]


####################################################################################
####################################################################################
           #########################################################
                  #### Section 4 : Driving cells ####
           #########################################################
####################################################################################

set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_awready*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_wready*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_bvalid*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_bid*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_bresp*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_arready*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_rvalid*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_rdata*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_rlast*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_rid*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports m_axi_rresp*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports dcr_wr_valid]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports dcr_wr_addr*]
set_driving_cell -library NangateOpenCellLibrary_ss0p95v125c -lib_cell BUF_X2 -pin Z [get_ports dcr_wr_data*]

####################################################################################
           #########################################################
                  #### Section 5 : Output load ####
           #########################################################
####################################################################################

set_load 0.5 [get_ports m_axi_awvalid*]
set_load 0.5 [get_ports m_axi_awaddr*]
set_load 0.5 [get_ports m_axi_awid*]
set_load 0.5 [get_ports m_axi_awlen*]
set_load 0.5 [get_ports m_axi_awsize*]
set_load 0.5 [get_ports m_axi_awburst*]
set_load 0.5 [get_ports m_axi_awlock*]
set_load 0.5 [get_ports m_axi_awcache*]
set_load 0.5 [get_ports m_axi_awprot*]
set_load 0.5 [get_ports m_axi_awqos*]
set_load 0.5 [get_ports m_axi_awregion*]
set_load 0.5 [get_ports m_axi_wvalid*]
set_load 0.5 [get_ports m_axi_wdata*]
set_load 0.5 [get_ports m_axi_wstrb*]
set_load 0.5 [get_ports m_axi_wlast*]
set_load 0.5 [get_ports m_axi_bready*]
set_load 0.5 [get_ports m_axi_arvalid*]
set_load 0.5 [get_ports m_axi_araddr*]
set_load 0.5 [get_ports m_axi_arid*]
set_load 0.5 [get_ports m_axi_arlen*]
set_load 0.5 [get_ports m_axi_arsize*]
set_load 0.5 [get_ports m_axi_arburst*]
set_load 0.5 [get_ports m_axi_arlock*]
set_load 0.5 [get_ports m_axi_arcache*]
set_load 0.5 [get_ports m_axi_arprot*]
set_load 0.5 [get_ports m_axi_arqos*]
set_load 0.5 [get_ports m_axi_arregion*]
set_load 0.5 [get_ports m_axi_rready*]
set_load 0.5 [get_ports busy]

####################################################################################
           #########################################################
                 #### Section 6 : Operating Condition ####
           #########################################################
####################################################################################

# Define the Worst Library for Max(#setup) analysis
# Define the Best Library for Min(hold) analysis

set_operating_conditions -min_library "NangateOpenCellLibrary_ff1p25vn40c" -min "low_temp" -max_library "NangateOpenCellLibrary_ss0p95v125c" -max "slow"

