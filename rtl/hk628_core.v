module hk628_core (
    input wire clk,           // 50MHz
    input wire [7:0] btn,     // 8 Sound Buttons
    input wire low_batt_btn,  // Hold this to simulate dying battery
    output reg [15:0] pcm_out // 16-bit Signed Audio
);

    // --- Dual Clock Domain (The Timing Fix) ---
    reg [15:0] micro_limit;
    always @(posedge clk) begin
        micro_limit <= low_batt_btn ? 16'd120 : 16'd50; 
    end

    reg [15:0] micro_cnt;
    wire micro_tick = (micro_cnt >= micro_limit);
    always @(posedge clk) micro_cnt <= micro_tick ? 16'd0 : micro_cnt + 16'd1;

    reg [5:0] macro_cnt;
    wire macro_tick = micro_tick && (macro_cnt == 6'd49);
    always @(posedge clk) begin
        if (micro_tick) begin
            macro_cnt <= macro_tick ? 6'd0 : macro_cnt + 6'd1;
        end
    end

    // --- State Machine ---
    reg [3:0] state = 1;
    reg [23:0] counter = 0;
    reg [15:0] freq_period, tone_cnt;
    reg speaker_state;
    reg [15:0] lfsr = 16'hACE1;

    always @(posedge clk) begin
        if (macro_tick) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            
            if (state == 0) begin
                if (btn != 0) begin
                    if (btn[0]) state <= 1; // Rifle
                    if (btn[1]) state <= 2; // Echo Rifle
                    if (btn[2]) state <= 3; // Phone
                    if (btn[3]) state <= 4; // Dual Tone
                    if (btn[4]) state <= 5; // Bomb 1
                    if (btn[5]) state <= 6; // Bomb 2
                    if (btn[6]) state <= 7; // Electric Gun
                    if (btn[7]) state <= 8; // Machine Gun
                    counter <= 0;
                end
            end else begin
                counter <= counter + 1;
                if (counter > 30000) state <= 0; // Reset after ~1.5s
            end

            case (state)
                1: freq_period <= 200 + counter[10:0];
                2: freq_period <= 200 + {counter[9:0], 2'b00};
                3: freq_period <= counter[11] ? 800 : 500;
                4: freq_period <= counter[10] ? 400 : 300;
                7: freq_period <= 100 + (lfsr[5:0] << 2);
                8: freq_period <= 300;
                default: freq_period <= 0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (micro_tick) begin
            if (freq_period > 0) begin
                if (tone_cnt >= freq_period) begin
                    tone_cnt <= 0;
                    speaker_state <= ~speaker_state;
                end else begin
                    tone_cnt <= tone_cnt + 1;
                end
            end
        end
    end

    // --- Output Mixer ---
    always @(posedge clk) begin
        case (state)
            5, 6: begin
                // Bombs: LFSR noise, then true silence
                if (counter < 15000) begin
                    pcm_out <= lfsr[0] ? 16'h3000 : 16'hD000;
                end else begin
                    pcm_out <= 16'd0;
                end
            end
            8: begin
                // Machine Gun: Tone bursts, then true silence
                if (counter[11]) begin
                    pcm_out <= speaker_state ? 16'h3000 : 16'hD000;
                end else begin
                    pcm_out <= 16'd0;
                end
            end
            0: begin
                // Perfect silence when off
                pcm_out <= 16'd0;
            end
            default: begin
                // D-Pad and standard tones
                pcm_out <= speaker_state ? 16'h3000 : 16'hD000;
            end
        endcase
    end
endmodule
