module emu
(
	// Master Clocks
	input         CLK_50M,
	input         CLK_VIDEO,
	input         CLK_AUDIO,

	// Pins for the MiSTer Framework (All must be UPPERCASE)
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
	
	// SDRAM/DDRAM (Required even if unused)
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

    // 1. CORE NAME
    localparam CONF_STR = "SoundToy;;";
    assign INFO = 32'd0;
    assign OSD_STATUS = 32'd0;

    // 2. AUDIO LOGIC
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

    // 3. VIDEO LOGIC (Black Screen)
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
    assign VGA_R = 0; assign VGA_G = 0; assign VGA_B = 0;
    assign CE_PIXEL = 1;
    assign VGA_SL = 0; assign VGA_F1 = 0; assign VGA_SCALER = 0; assign VGA_DISABLE = 0;
    assign VIDEO_ARX = 0; assign VIDEO_ARY = 0;

    // 4. CLEANUP (Tying unused pins)
    assign LED_USER = 0; assign LED_POWER = 1; assign LED_DISK = 0;
    assign SDRAM_A = 0; assign SDRAM_BA = 0; assign SDRAM_nCAS = 1;
    assign SDRAM_nRAS = 1; assign SDRAM_nWE = 1; assign SDRAM_nCS = 1;
    assign SDRAM_DQ = 16'hZZZZ; assign SDRAM_DQML = 0; assign SDRAM_DQMH = 0;
    assign SDRAM_CLK = 0; assign SDRAM_CKE = 0;
    assign HDMI_FREEZE = 0; assign HDMI_BLACKOUT = 0; assign HDMI_BOB_DEINT = 0;
    assign DDRAM_ADDR = 0; assign DDRAM_BE = 0; assign DDRAM_BURSTCNT = 0;
    assign DDRAM_CLK = 0; assign DDRAM_DIN = 0; assign DDRAM_RD = 0; assign DDRAM_WE = 0;
    assign SD_SCK = 0; assign SD_MOSI = 0; assign SD_CS = 1;
    assign UART_TXD = 0; assign UART_CTS = 0; assign UART_DSR = 0;
    assign USER_OUT = 0;

endmodule
