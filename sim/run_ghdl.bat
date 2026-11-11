@echo off
rem ============================================================
rem  Run from the "sim" folder:   run_ghdl.bat
rem  1) analyse (compile) all VHDL files   2) run 3 testbenches
rem  The order of files matters: cpu_pkg.vhd must come first.
rem ============================================================
set STD=--std=08
set SRC=../src/cpu_pkg.vhd ../src/alu8.vhd ../src/data_ram.vhd ../src/prog_rom.vhd ../src/cpu8.vhd
set TB=../tb/alu8_tb.vhd ../tb/ram_tb.vhd ../tb/cpu_tb.vhd

ghdl -a %STD% %SRC% %TB%
if errorlevel 1 exit /b 1

echo.
echo === ALU testbench ===
ghdl -e %STD% alu8_tb
if errorlevel 1 exit /b 1
ghdl -r %STD% alu8_tb
if errorlevel 1 exit /b 1

echo.
echo === RAM testbench ===
ghdl -e %STD% ram_tb
if errorlevel 1 exit /b 1
ghdl -r %STD% ram_tb
if errorlevel 1 exit /b 1

echo.
echo === Full CPU testbench (7 CPUs, 7 programs) ===
ghdl -e %STD% cpu_tb
if errorlevel 1 exit /b 1
ghdl -r %STD% cpu_tb --wave=cpu.ghw
if errorlevel 1 exit /b 1

echo.
echo Open the waveform with:  gtkwave cpu.ghw
