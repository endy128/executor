# Automatically derive all standard clocks
derive_pll_clocks
derive_clock_uncertainty

# Tell Quartus that our inline 25MHz video PLL is asynchronous to the system clocks.
# This isolates the video scaler and stops the SPI bus from crashing!
set_clock_groups -asynchronous \
    -group [get_clocks {FPGA_CLK1_50 FPGA_CLK2_50 FPGA_CLK3_50}] \
    -group [get_clocks {emu|video_pll|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
