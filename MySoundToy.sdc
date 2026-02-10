# Create the base 50MHz clock (Using CLK2 now!)
create_clock -name {FPGA_CLK2_50} -period 20.000 [get_ports {FPGA_CLK2_50}]

# Derive PLL clocks (Automagically finds the new PLL settings)
derive_pll_clocks
derive_clock_uncertainty

# Input delays
set_input_delay -clock {FPGA_CLK2_50} -max 3 [all_inputs]
set_input_delay -clock {FPGA_CLK2_50} -min 2 [all_inputs]
