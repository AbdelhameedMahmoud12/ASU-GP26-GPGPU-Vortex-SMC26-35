
########################### Define Top Module ############################
                                                   
set top_module VX_execute

########################### Formality Setup file ############################

set_svf "VX_execute.svf"

##################### Define Working Library Directory ######################
                                                   
define_design_lib work -path ./work

################## Design Compiler Library Files #setup ######################

puts "###########################################"
puts "#      #setting Design Libraries           #"
puts "###########################################"

#Add the path of the libraries to the search_path variable
lappend search_path /home/IC/execute/std_cells
lappend search_path /home/IC/execute/VH
lappend search_path /home/IC/execute/interfaces
lappend search_path /home/IC/execute
lappend search_path /home/IC/execute/rtl


set FFLIB "NangateOpenCellLibrary_ff1p25vn40c.db"
set SSLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set TTLIB "NangateOpenCellLibrary_tt1p1v25c.db"

## Standard Cell libraries 
set target_library [list $SSLIB $TTLIB $FFLIB]

## Standard Cell & Hard Macros libraries 
set link_library [list * $SSLIB $TTLIB $FFLIB]  

######################## Reading RTL Files #################################

puts "###########################################"
puts "#             Reading RTL Files           #"
puts "###########################################"

set file_format sverilog 

analyze -format $file_format -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } VX_gpu_pkg.sv

# 1. Analyze the package file FIRST

analyze -format $file_format VX_fpu_pkg.sv
analyze -format $file_format VX_trace_pkg.sv


# 2. Analyze the interfaces files that uses the package

analyze -format $file_format -define {NDEBUG EXT_F_ENABLE  FPU_DSP ASIC } [glob /home/IC/execute/interfaces/*.sv]


# 3. Now analyze all other sub-modules

analyze -format $file_format -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } [glob /home/IC/execute/rtl/*.sv]
analyze -format $file_format -define {NDEBUG EXT_F_ENABLE   FPU_DSP ASIC } VX_execute.sv

elaborate -lib work VX_execute

###################### Defining toplevel ###################################

current_design $top_module


#################### Liniking All The Design Parts #########################
puts "###############################################"
puts "######## Liniking All The Design Parts ########"
puts "###############################################"

link 

#################### Liniking All The Design Parts #########################
puts "###############################################"
puts "######## checking design consistency ##########"
puts "###############################################"

check_design

############################### Path groups ################################
puts "###############################################"
puts "################ Path groups ##################"
puts "###############################################"

group_path -name INREG -from [all_inputs]
group_path -name REGOUT -to [all_outputs]
group_path -name INOUT -from [all_inputs] -to [all_outputs]

#################### Define Design Constraints #########################
puts "###############################################"
puts "############ Design Constraints #### ##########"
puts "###############################################"

source -echo ./cons.tcl

###################### Mapping and optimization ########################
puts "###############################################"
puts "########## Mapping & Optimization #############"
puts "###############################################"

ungroup -all -flatten
compile_ultra

##################### Close Formality Setup file ###########################

set_svf -off

#############################################################################
# Write out Design after initial compile
#############################################################################

write_file -format verilog -hierarchy -output VX_execute_netlist.v
write_file -format ddc -hierarchy -output VX_execute_netlist.ddc
write_sdc  -nosplit VX_execute.sdc
write_sdf           VX_execute.sdf


################# reporting #######################

report_area -hierarchy > area.rpt
report_power -hierarchy > power.rpt
report_timing -max_paths 100 -delay_type min > hold.rpt
report_timing -max_paths 100 -delay_type max > setup.rpt
report_clock -attributes > clocks.rpt
report_constraint -all_violators > constraints.rpt

################# starting graphical user interface #######################

#gui_start

exit
