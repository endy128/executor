module emu
(
    input         reset,
    input         clk_sys,
    input  [31:0] joystick_0,

    // Audio Signals
    output [15:0] audio_l,
    output [15:0] audio_r,

    // Video Signals (Standard Framework)
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,
    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    
    output [31:0] status // Connects to the Framework OSD
);

    // 1. THE NAME: Change the first word here to name your core
    localparam CONF_STR = "SoundToy;;";
    assign status[31:0] = 32'd0; 

    // 2. AUDIO: Connect the sound chip
    wire [15:0] audio_out;
    hk628_core sound_toy (
        .clk(clk_sys),
        .btn(joystick_0[7:0]),
        .low_batt_btn(joystick_0[8]),
        .pcm_out(audio_out)
    );
    assign audio_l = audio_out;
    assign audio_r = audio_out;

    // 3. VIDEO: Simple "Black Screen" Sync Generator
    // This stops the static by giving the TV a valid blank signal
    reg [9:0] h_cnt, v_cnt;
    always @(posedge clk_sys) begin
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
    
    // Set colors to 0 (Black)
    assign VGA_R = 8'd0;
    assign VGA_G = 8'd0;
    assign VGA_B = 8'd0;

endmodule
