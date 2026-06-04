
##################### Define Working Library Directory ######################
if {[file exists ./work]} {
    file delete -force ./work
}
                                               
define_design_lib work -path ./work

################## Design Compiler Library Files #setup ######################
set_svf VX_issue.svf
puts "###########################################"
puts "#      #setting Design Libraries          #"
puts "###########################################"

#Add the path of the libraries to the search_path variable
lappend search_path /home/IC/Issue/std_cells
lappend search_path /home/IC/Issue/VHDL
lappend search_path /home/IC/Issue/RTL
lappend search_path /home/IC/Issue/RTL/interfaces


## Decrelation libraries 
set SSLIB "NangateOpenCellLibrary_ss0p95v125c.db"
set TTLIB "NangateOpenCellLibrary_tt1p1v25c.db"
set FFLIB "NangateOpenCellLibrary_ff1p25vn40c.db"
## Standard Cell libraries 
## Standard Cell & Hard Macros libraries 
set target_library [list $TTLIB $FFLIB $SSLIB]
set link_library   [list * $TTLIB $FFLIB $SSLIB]


######################## Reading RTL Files #################################


puts "###########################################"
puts "#             Reading RTL Files           #"
puts "###########################################"

# --- STEP 1: ANALYZE PACKAGES ---
analyze -format sverilog -define {NDEBUG} ../VX_gpu_pkg.sv

# --- STEP 2: ANALYZE INTERFACES ---
analyze -format sverilog -define {NDEBUG} [glob ../RTL/interfaces/*.sv]

# --- STEP 3: ANALYZE SUBMODULES ---

# Dispatch
analyze -format sverilog -define {NDEBUG}  [glob ../RTL/*.sv]

analyze -format sverilog -define {NDEBUG}  ../VX_issue_slice.sv
analyze -format sverilog -define {NDEBUG}  ../VX_issue.sv

set base_top_module VX_issue

# 1. Run elaborate. Do NOT save its return value.
elaborate -lib work $base_top_module

###################### Defining toplevel ###################################

# 2. NOW, ask the tool for the current design name and save it.
#    `current_design` with no arguments *returns* the name.
set top_module [current_design]

# 3. This line will now work correctly (it's even optional now)
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

group_path -name VX_issue_IN -from [all_inputs]
group_path -name VX_issue_OUT -to [all_outputs]

group_path -name VX_issue_in_out -from [all_inputs] -to [all_outputs]

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

set_svf -off
#############################################################################
################ Write out Design after initial compile######################
#############################################################################

write_file -format verilog -hierarchy -output VX_issue_netlist.v
write_file -format ddc -hierarchy -output $top_module.ddc
write_sdc  -nosplit $top_module.sdc
write_sdf           $top_module.sdf
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
