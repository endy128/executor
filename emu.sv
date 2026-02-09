`define NO_VGA_CLK_SW
`define MISTER_SMALL

module emu
(
	// Master Clocks
	input         CLK_50M,
	input         CLK_VIDEO,
	input         CLK_AUDIO,

	// Pins for the MiSTer Framework (Must be UPPERCASE)
	input         RESET,
	input  [31:0] JOYSTICK_0,
	input  [31:0] JOYSTICK_1,
	input  [31:0] STATUS,
	output [31:0] INFO,
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,
	output [1:0]  AUDIO_MIX,

	// Video Output
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        CE_PIXEL,
	output        VGA_SL,
	output        VGA_F1,
	output [1:0]  VGA_SCALER,
	output        VGA_DISABLE,

	// Framework Communication
	input  [64:0] HPS_BUS,
	output [31:0] OSD_STATUS,
	output  [7:0] LED_USER,
	output  [7:0] LED_POWER,
	output  [7:0] LED_DISK,
	
	// SDRAM/DDRAM (Required - DQ MUST BE INOUT)
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
	output        SDRAM_nCS,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

	// Extra framework connections
	input  [11:0] ADC_BUS,
	input  [31:0] BUTTONS,
	input         HDMI_WIDTH,
	input         HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,
	output [27:0] DDRAM_ADDR,
	output [7:0]  DDRAM_BE,
	output [2:0]  DDRAM_BURSTCNT,
	input         DDRAM_BUSY,
	output        DDRAM_CLK,
	output [63:0] DDRAM_DIN,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output        DDRAM_WE,
	output [1:0]  VIDEO_ARX,
	output [1:0]  VIDEO_ARY,
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_CTS,
	input         UART_RTS,
	input         UART_DTR,
	output        UART_DSR,
	input  [15:0] USER_IN,
	output [15:0] USER_OUT
);

    // 1. CORE CONFIG
    localparam CONF_STR = "SoundToy;;";
    assign INFO = 32'd0;
    assign OSD_STATUS = 32'd0;

    // 2. AUDIO LOGIC: Connect your core to UPPERCASE ports
    wire [15:0] toy_audio;
    hk628_core your_sound_toy (
        .clk(CLK_50M),
        .btn(JOYSTICK_0[7:0]),
        .low_batt_btn(JOYSTICK_0[8]),
        .pcm_out(toy_audio)
    );

    assign AUDIO_L = toy_audio;
    assign AUDIO_R = toy_audio;
    assign AUDIO_S = 0;
    assign AUDIO_MIX = 0;

    // 3. VIDEO LOGIC
    reg [9:0] h_cnt, v_cnt;
    
    // We explicitly use CLK_VIDEO for logic to "pull" the clock through the netlist
    always @(posedge CLK_VIDEO) begin
        if (h_cnt < 799) h_cnt <= h_cnt + 1;
        else begin
            h_cnt <= 0;
            if (v_cnt < 524) v_cnt <= v_cnt + 1;
            else v_cnt <= 0;
        end
    end

    // 4. CLEANUP & CLOCK "TOUCHING"
    // This is the fix for Error 15834: 
    // We combine all clocks into a dummy signal so Quartus sees them as "used"
    wire clk_gate = CLK_50M & CLK_VIDEO & CLK_AUDIO;
    assign OSD_STATUS = {31'd0, clk_gate}; 
    
    assign LED_USER = 8'b0;
    assign LED_POWER = 1;
    assign LED_DISK = 0;

endmodule
