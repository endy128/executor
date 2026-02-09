module emu (
    input         reset,
    input         clk_sys,
    input  [31:0] joystick_0, 
    output [15:0] audio_l,
    output [15:0] audio_r
);

    wire [15:0] audio_data;

    hk628_core sound_toy (
        .clk(clk_sys),
        .btn(joystick_0[7:0]),        // Buttons 1-8
        .low_batt_btn(joystick_0[8]), // Button 9 (L2/R2) for Low Battery FX
        .pcm_out(audio_data)
    );

    assign audio_l = audio_data;
    assign audio_r = audio_data;

endmodule
