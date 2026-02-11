module emu
(
	// Master Clocks
	input         CLK_50M,
	input         CLK_VIDEO,
	input         CLK_AUDIO,
	input         RESET,

	// Video Interface
	output [7:0]  VGA_R,
	output [7:0]  VGA_G,
	output [7:0]  VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,
	input         VGA_F1,
	output [1:0]  VGA_SL,
	output        CE_PIXEL,
	output        VGA_SCALER,
	output        VGA_DISABLE,

	// Audio Interface
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,
	output [1:0]  AUDIO_MIX, // Fixed: Changed from 1-bit to 2-bit to match sys_top

	// Control / Status
	input  [31:0] joystick_0,
	input  [31:0] joystick_1,
	input  [31:0] status_in,
	output [31:0] OSD_STATUS,
	output [31:0] LED_USER,
	output        LED_POWER,
	output        LED_DISK,
	input  [63:0] BUTTONS, // Fixed: sys_top connects a simplified button bus here

	// SDRAM Interface (Unused but required ports)
	output [12:0] SDRAM_A,
	output [1:0]  SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output        SDRAM_BA0,
	output        SDRAM_BA1,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

	// UART (Unused but required ports)
	input  [15:0] UART_RXD,
	output [15:0] UART_TXD,
	output        UART_RTS,
	input         UART_CTS,
	output        UART_DTR,
	input         UART_DSR,

    // System Bus (The source of the crash!)
	input  [3:0]  ADC_BUS,   // Fixed: sys_top sends 4 bits, not 16
	input  [63:0] HPS_BUS,   // Fixed: sys_top sends ~49 bits, widened to 64 to be safe
	
    // DDRAM (Unused but required)
    output [31:0] DDRAM_ADDR,
	output [7:0]  DDRAM_BE,
	output        DDRAM_WE,
	output        DDRAM_RD,
	output [1:0]  DDRAM_BURSTCNT,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output [63:0] DDRAM_DIN,
	input         DDRAM_BUSY,
	output        DDRAM_CLK,

    // HDMI Interface (Fixed directions to match sys_top)
	input  [15:0] HDMI_WIDTH,     // Fixed: Changed from Output to Input
	input  [15:0] HDMI_HEIGHT,    // Fixed: Changed from Output to Input
	input         HDMI_FREEZE,    // Fixed: Changed from Output to Input
	input         HDMI_BLACKOUT,  // Fixed: Changed from Output to Input
	input         HDMI_BOB_DEINT, // Fixed: Changed from Output to Input
	
    output [12:0] VIDEO_ARX,      // Fixed: Widened to 13 bits to match sys_top
	output [12:0] VIDEO_ARY,      // Fixed: Widened to 13 bits to match sys_top
	
    input         USER_IN,
	output        USER_OUT,
	input         SD_SCK,
	input         SD_MOSI,
	output        SD_MISO,
	input         SD_CS,
	input         SD_CD
);

    // 1. Core Name
	localparam CONF_STR = "S0U,SoundToy;S;O1,Battery,Normal,Low;"; // The 'S0U' tells the framework to initialize the OSD properly
    assign OSD_STATUS = 32'd0;

    // 2. Sound Logic
    wire [15:0] audio_out;
    hk628_core sound_toy (
        .clk(CLK_50M),
        .btn(joystick_0[7:0]) | status_in[7:0]), // Use Joystick OR OSD buttons
        .low_batt_btn(status_in[1]),
        .pcm_out(audio_out)
    );
    
    assign AUDIO_L = audio_out;
    assign AUDIO_R = audio_out;
    assign AUDIO_S = 1'b1;     // Signal that audio is present
    assign AUDIO_MIX = 2'b00;  // 00 usually means 'No extra mixing/Pass through'

    // 3. Black Screen Generator (Prevents Static)
    reg [9:0] h_cnt, v_cnt;
    always @(posedge CLK_50M) begin
        if (h_cnt < 799) h_cnt <= h_cnt + 1;
        else begin
            h_cnt <= 0;
            if (v_cnt < 524) v_cnt <= v_cnt + 1;
            else v_cnt <= 0;
        end
    end
    assign VGA_HS = !(h_cnt >= 656 && h_cnt < 752);
    assign VGA_VS = !(v_cnt >= 490 && v_cnt < 492);
    assign VGA_DE = (h_cnt < 640 && v_cnt < 480);
    assign VGA_R = 8'h10; // Very dark grey instead of pure black
    assign VGA_G = 8'h10; 
    assign VGA_B = 8'h10;
    assign CE_PIXEL = 1;

    // --- HEARTBEAT SENSOR ---
	reg [24:0] heartbeat;
	always @(posedge CLK_50M) heartbeat <= heartbeat + 1;
	
	// Redirect debug signals to your front panel LEDs
	assign LED_USER  = 0;                // Internal LED
	assign LED_POWER = 1;                // Stay solid on
	assign LED_DISK  = heartbeat[24];    // THIS WILL BLINK THE HDD LED ON YOUR CASE
    // 4. Tie off unused outputs to 0
    assign SDRAM_CLK = CLK_50M; assign SDRAM_CKE = 1;
    assign UART_TXD = 0; assign UART_RTS = 0; assign UART_DTR = 0;
    assign DDRAM_CLK = CLK_50M; assign USER_OUT = 0; assign SD_MISO = 0;
    assign VGA_SCALER = 0; assign VGA_DISABLE = 0;
    
    // Default Aspect Ratio (4:3)
    assign VIDEO_ARX = 13'd4; 
    assign VIDEO_ARY = 13'd3;
    
    // Unused SDRAM/DDRAM
    assign SDRAM_A = 0; assign SDRAM_BA = 0; assign SDRAM_DQMH = 0; assign SDRAM_DQML = 0; 
    assign SDRAM_nWE = 1; assign SDRAM_nCAS = 1; assign SDRAM_nRAS = 1; assign SDRAM_nCS = 1;
    assign SDRAM_BA0 = 0; assign SDRAM_BA1 = 0;
    assign DDRAM_ADDR = 0; assign DDRAM_BE = 0; assign DDRAM_WE = 0; assign DDRAM_RD = 0; 
    assign DDRAM_BURSTCNT = 0; assign DDRAM_DIN = 0;

endmodule
