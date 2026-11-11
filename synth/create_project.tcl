# Creates the Quartus project (run from the "synth" folder):
#     quartus_sh -t create_project.tcl
# then compile:   quartus_sh --flow compile cpu8
# (or open cpu8.qpf in the Quartus GUI and press Start Compilation)

project_new cpu8 -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7
set_global_assignment -name TOP_LEVEL_ENTITY cpu8
set_global_assignment -name VHDL_INPUT_VERSION VHDL2008
set_global_assignment -name VHDL_FILE ../src/cpu_pkg.vhd
set_global_assignment -name VHDL_FILE ../src/alu8.vhd
set_global_assignment -name VHDL_FILE ../src/data_ram.vhd
set_global_assignment -name VHDL_FILE ../src/prog_rom.vhd
set_global_assignment -name VHDL_FILE ../src/cpu8.vhd
set_global_assignment -name SDC_FILE cpu8.sdc
project_close
