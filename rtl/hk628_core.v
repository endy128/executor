module hk628_core (
    input wire clk,           // 50MHz
    input wire [7:0] btn,     // 8 Sound Buttons
    input wire low_batt_btn,  // Hold this to simulate dying battery
    output reg signed [15:0] pcm_out // Explicitly SIGNED 16-bit Audio
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
            // LFSR generates pseudo-random noise for explosions
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            
            if (state == 0) begin
                if (btn != 0) begin
                    if (btn[0]) state <= 1; // Rifle
                    if (btn[1]) state <= 2; // Echo Rifle
                    if (btn[2]) state <= 3; // Phone
                    if (btn[3]) state <= 4; // Dual Tone
                    if (btn[4]) state <= 5; // Bomb 1 (Whistle)
                    if (btn[5]) state <= 6; // Bomb 2 (Explosion)
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
                5: freq_period <= 200 + counter[13:3];         // Bomb Drop (Falling pitch)
                6: freq_period <= 0;                           // Explosion (Uses LFSR noise)
                7: freq_period <= 100 + (lfsr[5:0] << 2);      // Electric Gun (Pitch jitter)
                8: freq_period <= 300;                         // Machine Gun
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
        if (state == 0) begin
            // Perfect silence when off
            pcm_out <= 16'sd0;
            
        end else if (state == 5) begin
            // Bomb 1: Falling Whistle (Tone based!)
            if (counter < 20000) begin
                pcm_out <= speaker_state ? 16'sd12288 : -16'sd12288;
            end else begin
                pcm_out <= 16'sd0;
            end
            
        end else if (state == 6) begin
            // Bomb 2: Explosion (Noise based!)
            if (counter < 15000) begin
                pcm_out <= lfsr[0] ? 16'sd12288 : -16'sd12288;
            end else begin
                pcm_out <= 16'sd0;
            end
            
        end else if (state == 8) begin
            // Machine Gun: Tone bursts alternating with true silence
            if (counter[11]) begin
                pcm_out <= speaker_state ? 16'sd12288 : -16'sd12288;
            end else begin
                pcm_out <= 16'sd0;
            end
            
        end else begin
            // States 1-4 (D-Pad) and 7 (Electric Zap)
            pcm_out <= speaker_state ? 16'sd12288 : -16'sd12288;
        end
    end
endmodule
