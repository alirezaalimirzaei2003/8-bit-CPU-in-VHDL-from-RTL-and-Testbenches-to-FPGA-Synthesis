# 100 MHz target clock; Fmax is read from the Timing Analyzer report
create_clock -name clk -period 10.000 [get_ports clk]
derive_clock_uncertainty
