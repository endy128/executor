# Create the base 50MHz clock for the FPGA
create_clock -name {FPGA_CLK1_50} -period 20.000 [get_ports {FPGA_CLK1_50}]

# Derive PLL clocks (this finds your clk_sys)
derive_pll_clocks
derive_clock_uncertainty

# Core-specific constraints (optional but good practice)
set_input_delay -clock {FPGA_CLK1_50} -max 3 [all_inputs]
set_input_delay -clock {FPGA_CLK1_50} -min 2 [all_inputs]
