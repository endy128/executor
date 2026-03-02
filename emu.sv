module emu
(
    // Clocks and Reset
    input         CLK_50M,
    output        CLK_VIDEO,    // Driven perfectly by our new 25MHz PLL!
    input         CLK_AUDIO,    
    input         RESET,

    // Video Interface
    output [7:0]  VGA_R, output [7:0]  VGA_G, output [7:0]  VGA_B,
    output        VGA_HS, output        VGA_VS, output        VGA_DE,
    input         VGA_F1, output [1:0]  VGA_SL, output        CE_PIXEL,
    output        VGA_SCALER, output        VGA_DISABLE,

    // Audio Interface
    output [15:0] AUDIO_L, output [15:0] AUDIO_R,
    output        AUDIO_S, output [1:0]  AUDIO_MIX,

    // Framework Status
    output [31:0] OSD_STATUS,
    output [31:0] LED_USER,
    output        LED_POWER,
    output        LED_DISK,
    input  [63:0] BUTTONS,

    // Framework standard ports
    output [12:0] SDRAM_A, output [1:0] SDRAM_BA, inout [15:0] SDRAM_DQ, output SDRAM_DQML, output SDRAM_DQMH, output SDRAM_nWE, output SDRAM_nCAS, output SDRAM_nRAS, output SDRAM_nCS, output SDRAM_BA0, output SDRAM_BA1, output SDRAM_CLK, output SDRAM_CKE,
    input [15:0] UART_RXD, output [15:0] UART_TXD, output UART_RTS, input UART_CTS, output UART_DTR, input UART_DSR,
    
    input [3:0] ADC_BUS, 
    inout [48:0] HPS_BUS, 
    
    output [31:0] DDRAM_ADDR, output [7:0] DDRAM_BE, output DDRAM_WE, output DDRAM_RD, output [1:0] DDRAM_BURSTCNT, input [63:0] DDRAM_DOUT, input DDRAM_DOUT_READY, output [63:0] DDRAM_DIN, input DDRAM_BUSY, output DDRAM_CLK,
    input [15:0] HDMI_WIDTH, input [15:0] HDMI_HEIGHT, input HDMI_FREEZE, input HDMI_BLACKOUT, input HDMI_BOB_DEINT,
    output [12:0] VIDEO_ARX, output [12:0] VIDEO_ARY,
    input USER_IN, output USER_OUT, input SD_SCK, input SD_MOSI, output SD_MISO, input SD_CS, input SD_CD
);

    // --- 1. SYSTEM AND VIDEO CLOCKS ---
    wire clk_sys = CLK_50M; 
    
    // Create a flawless 25MHz PLL clock directly in code
    wire clk_25m;
    altera_pll #(
        .reference_clock_frequency("50.0 MHz"),
        .operation_mode("direct"),
        .number_of_clocks(1),
        .output_clock_frequency0("25.000000 MHz"),
        .phase_shift0("0 ps"),
        .duty_cycle0(50),
        .pll_type("General"),
        .pll_subtype("General")
    ) video_pll (
        .refclk(CLK_50M),
        .rst(1'b0),
        .outclk(clk_25m),
        .locked(), .fboutclk(), .fbclk(1'b0), .extswitch(1'b0), .adjpllin(1'b0)
    );
    
    // Satisfies the Quartus Router and gives us 60Hz!
    assign CLK_VIDEO = clk_25m; 

    // --- 2. THE LINUX SPI BRIDGE (hps_io) ---
    localparam CONF_STR = "MYSOUNDTOY;;O,1,Battery,Normal,Low;";
    
    wire [127:0] status;
    wire  [31:0] joystick_0;
    wire  [31:0] joystick_1;
    
    hps_io #(.CONF_STR(CONF_STR)) hps_io (
        .clk_sys(clk_sys),
        .HPS_BUS(HPS_BUS),
        .status(status),
        .joystick_0(joystick_0),
        .joystick_1(joystick_1)
    );

    assign OSD_STATUS = status[31:0]; 
    assign VGA_SL = 2'b00;

    // --- 3. AUDIO SUBSYSTEM ---
    wire [15:0] audio_out;
    hk628_core sound_toy (
        .clk(CLK_50M), // Runs safely on 50MHz               
        .btn(joystick_0[7:0]),        
        .low_batt_btn(status[1]),     
        .pcm_out(audio_out)
    );
    
    assign AUDIO_L = audio_out;
    assign AUDIO_R = audio_out;
    assign AUDIO_S = 1'b1;     
    assign AUDIO_MIX = 2'b00;  

    // --- 4. VIDEO TIMINGS (ROCK SOLID 60Hz) ---
    assign CE_PIXEL = 1'b1; // No divider needed, we are pure 25MHz now

    reg [9:0] h_cnt = 10'd0;
    reg [9:0] v_cnt = 10'd0;

    // Notice we step the video using clk_25m now!
    always @(posedge clk_25m) begin
        if (h_cnt < 10'd799) h_cnt <= h_cnt + 10'd1;
        else begin
            h_cnt <= 10'd0;
            if (v_cnt < 10'd524) v_cnt <= v_cnt + 10'd1;
            else v_cnt <= 10'd0;
        end
    end

    // Standard 640x480 VGA generation
    assign VGA_HS = ~(h_cnt >= 10'd656 && h_cnt < 10'd752);
    assign VGA_VS = ~(v_cnt >= 10'd490 && v_cnt < 10'd492);
    assign VGA_DE = (h_cnt < 10'd640 && v_cnt < 10'd480);
    
    wire [7:0] pattern = (h_cnt[5] ^ v_cnt[5]) ? 8'h33 : 8'h66;
    assign VGA_R = VGA_DE ? pattern : 8'h00; 
    assign VGA_G = VGA_DE ? pattern : 8'h00; 
    assign VGA_B = VGA_DE ? pattern : 8'h00;

    // --- 5. HOUSEKEEPING ---
    reg [25:0] heartbeat = 26'd0;
    always @(posedge CLK_50M) heartbeat <= heartbeat + 26'd1;
    
    assign LED_USER  = heartbeat[25]; 
    assign LED_DISK  = status[1]; 
    assign LED_POWER = 1'b1;          
        
    assign SDRAM_CLK = CLK_50M; assign SDRAM_CKE = 1;
    assign UART_TXD = 0; assign UART_RTS = 0; assign UART_DTR = 0;
    assign DDRAM_CLK = CLK_50M; assign USER_OUT = 0; assign SD_MISO = 0;
    assign VGA_SCALER = 0; assign VGA_DISABLE = 0;
    assign VIDEO_ARX = 13'd4; assign VIDEO_ARY = 13'd3;
    assign SDRAM_A = 0; assign SDRAM_BA = 0; assign SDRAM_DQMH = 0; assign SDRAM_DQML = 0; 
    assign SDRAM_nWE = 1; assign SDRAM_nCAS = 1; assign SDRAM_nRAS = 1; assign SDRAM_nCS = 1;
    assign SDRAM_BA0 = 0; assign SDRAM_BA1 = 0; assign DDRAM_ADDR = 0; assign DDRAM_BE = 0; 
    assign DDRAM_WE = 0; assign DDRAM_RD = 0; assign DDRAM_BURSTCNT = 0; assign DDRAM_DIN = 0;

endmodule
