# Questa: run from the "sim" folder:   vsim -do run_questa.do      (opens the GUI)
#   batch mode (no GUI): vsim -c -do "do run_questa.do; quit -f"  (the add wave lines are ignored without GUI)
# NOTE: # Tested with Questa Intel FPGA Edition (Quartus Prime Lite 25.1): all three testbenches pass.
vlib work
vmap work work
vcom -2008 ../src/cpu_pkg.vhd ../src/alu8.vhd ../src/data_ram.vhd ../src/prog_rom.vhd ../src/cpu8.vhd
vcom -2008 ../tb/alu8_tb.vhd ../tb/ram_tb.vhd ../tb/cpu_tb.vhd

foreach tb {alu8_tb ram_tb} {
  vsim work.$tb
  run -all
  quit -sim
}

vsim -voptargs=+acc work.cpu_tb
# signals of the CPU that runs program 6 (the 5-instruction demo); change gen(6) to see another program
add wave -radix unsigned /cpu_tb/clk
add wave {/cpu_tb/gen(6)/dut/state}
add wave -radix unsigned {/cpu_tb/gen(6)/dut/pc}
add wave -radix hex      {/cpu_tb/gen(6)/dut/ir}
add wave -radix unsigned {/cpu_tb/gen(6)/dut/acc}
add wave -radix unsigned {/cpu_tb/gen(6)/dut/cnt}
add wave                 {/cpu_tb/gen(6)/dut/flag_z}
add wave                 {/cpu_tb/gen(6)/dut/flag_c}
add wave -radix unsigned {/cpu_tb/gen(6)/dut/out_port}
add wave                 {/cpu_tb/gen(6)/dut/out_strobe}
add wave                 {/cpu_tb/gen(6)/dut/halted}
run -all
wave zoom full
