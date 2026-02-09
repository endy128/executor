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
	output        AUDIO_MIX,

	// Control / Status
	input  [31:0] joystick_0,
	input  [31:0] joystick_1,
	input  [31:0] status_in,
	output [31:0] OSD_STATUS,
	output [31:0] LED_USER,
	output        LED_POWER,
	output        LED_DISK,
	input  [63:0] BUTTONS,

	// SDRAM Interface (Unused but required)
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

	// Other Required Framework Ports
	input  [15:0] UART_RXD,
	output [15:0] UART_TXD,
	output        UART_RTS,
	input         UART_CTS,
	output        UART_DTR,
	input         UART_DSR,
	input  [15:0] ADC_BUS,
	input  [31:0] HPS_BUS,
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
	output [15:0] HDMI_WIDTH,
	output [15:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,
	output [3:0]  VIDEO_ARX,
	output [3:0]  VIDEO_ARY,
	input         USER_IN,
	output        USER_OUT,
	input         SD_SCK,
	input         SD_MOSI,
	output        SD_MISO,
	input         SD_CS,
	input         SD_CD
);

    // 1. Core Name in OSD
    localparam CONF_STR = "SoundToy;;";
    assign OSD_STATUS = 32'd0;

    // 2. Connect Sound Logic
    wire [15:0] audio_out;
    hk628_core sound_toy (
        .clk(CLK_50M),
        .btn(joystick_0[7:0]),
        .low_batt_btn(joystick_0[8]),
        .pcm_out(audio_out)
    );
    
    assign AUDIO_L = audio_out;
    assign AUDIO_R = audio_out;
    assign AUDIO_S = 0;
    assign AUDIO_MIX = 0;

    // 3. Simple Black Screen Generator
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

    // 4. Tie off unused outputs (Required to prevent errors)
    assign LED_USER = 0; assign LED_POWER = 1; assign LED_DISK = 0;
    assign SDRAM_CLK = CLK_50M; assign SDRAM_CKE = 1;
    assign UART_TXD = 0; assign UART_RTS = 0; assign UART_DTR = 0;
    assign DDRAM_CLK = CLK_50M; assign USER_OUT = 0; assign SD_MISO = 0;
    assign VGA_SCALER = 0; assign VGA_DISABLE = 0;

endmodule
