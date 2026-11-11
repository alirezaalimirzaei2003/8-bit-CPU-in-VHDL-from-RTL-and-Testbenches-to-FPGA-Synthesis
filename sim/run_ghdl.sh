#!/usr/bin/env bash
# Linux / macOS / WSL / Git-Bash version of run_ghdl.bat. Run from the "sim" folder.
set -e
STD=--std=08
SRC="../src/cpu_pkg.vhd ../src/alu8.vhd ../src/data_ram.vhd ../src/prog_rom.vhd ../src/cpu8.vhd"
TB="../tb/alu8_tb.vhd ../tb/ram_tb.vhd ../tb/cpu_tb.vhd"
ghdl -a $STD $SRC $TB
for t in alu8_tb ram_tb; do ghdl -e $STD $t; ghdl -r $STD $t; done
ghdl -e $STD cpu_tb
ghdl -r $STD cpu_tb --wave=cpu.ghw
echo "Open the waveform with:  gtkwave cpu.ghw"
