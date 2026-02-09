module emu
(
    input         reset,
    input         clk_sys,
    input  [31:0] joystick_0,

    // Audio Signals
    output [15:0] audio_l,
    output [15:0] audio_r,

    // Video Signals
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,
    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    
    // Framework Signals
    output [31:0] status,
    // Add these to satisfy the UART warning
    output        UART_DSR,
    output        UART_CTS
);

    // 1. THE NAME & STATUS
    // We only assign 'status' ONCE here to prevent the "multiple constant drivers" error.
    localparam CONF_STR = "SoundToy;;";
    assign status = 32'd0; 
    
    // Tie off unused UART ports to fix the Warning (10034)
    assign UART_DSR = 1'b0;
    assign UART_CTS = 1'b0;

    // 2. AUDIO: Connect your sound logic
    wire [15:0] audio_out;
    hk628_core sound_toy (
        .clk(clk_sys),
        .btn(joystick_0[7:0]),        
        .low_batt_btn(joystick_0[8]), 
        .pcm_out(audio_out)
    );
    assign audio_l = audio_out;
    assign audio_r = audio_out;

    // 3. VIDEO: Logic to generate a clean "Black Screen"
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
    assign VGA_R = 8'd0; 
    assign VGA_G = 8'd0; 
    assign VGA_B = 8'd0;

endmodule
