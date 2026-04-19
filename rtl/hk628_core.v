module hk628_core (
    input wire clk,           // 50MHz
    input wire [7:0] btn,     // 8 Sound Buttons
    input wire low_batt_btn,  // Hold this to simulate dying battery
    output reg signed [15:0] pcm_out // 16-bit Signed Audio
);

    // --- Dual Clock Domain (The Timing Fix) ---
    // 1. The Micro Timer generates a ~1MHz clock for the audio pitch
    reg [15:0] micro_limit;
    always @(posedge clk) begin
        // 50MHz / 50 = 1MHz (Normal). 50MHz / 120 = 416kHz (Dying Battery)
        micro_limit <= low_batt_btn ? 16'd120 : 16'd50; 
    end

    reg [15:0] micro_cnt;
    wire micro_tick = (micro_cnt >= micro_limit);
    always @(posedge clk) micro_cnt <= micro_tick ? 16'd0 : micro_cnt + 16'd1;

    // 2. The Macro Timer divides the 1MHz clock down to ~20kHz for the tempo/LFSR
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

    // --- MACRO DOMAIN: Tempo and LFSR (Updates at ~20kHz) ---
    always @(posedge clk) begin
        if (macro_tick) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            
            if (state == 0) begin
                if (btn != 0) begin
                    if (btn[0]) state <= 1; // Rifle
                    if (btn[1]) state <= 2; // Echo Rifle
                    if (btn[2]) state <= 3; // Phone
                    if (btn[3]) state <= 4; // Dual Tone
                    if (btn[4]) state <= 5; // Bomb Drop (Falling Pitch)
                    if (btn[5]) state <= 6; // Explosion (Noise)
                    if (btn[6]) state <= 7; // Electric Zapper
                    if (btn[7]) state <= 8; // Machine Gun
                    counter <= 0;
                end
            end else begin
                counter <= counter + 1;
                if (counter > 30000) state <= 0; // Reset after ~1.5s
            end

            // Synthesis Logic (Tuned for 90s Toy Sounds)
            case (state)
                1: freq_period <= 200 + counter[10:0];         
                2: freq_period <= 200 + {counter[9:0], 2'b00}; 
                3: freq_period <= counter[11] ? 800 : 500;     
                4: freq_period <= counter[10] ? 400 : 300;     
                5: freq_period <= 200 + counter[13:3];         
                6: freq_period <= 0;                           
                7: freq_period <= 150 + lfsr[5:0];             
                8: freq_period <= 300;                         
                default: freq_period <= 0;
            endcase
        end
    end

    // --- MICRO DOMAIN: Audio Pitch Generation (Updates at ~1MHz) ---
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

    // --- Output Mixer (Flattened & Crash-Proof) ---
    always @(posedge clk) begin
        if (state == 0) begin
            // Perfect silence when off
            pcm_out <= 16'd0;
            
        end else if (state == 5 || state == 6) begin
            // Bombs: Play LFSR noise for a short burst, then true silence
            if (counter < 15000) begin
                pcm_out <= lfsr[0] ? 16'h3000 : 16'hD000;
            end else begin
                pcm_out <= 16'd0;
            end
            
        end else if (state == 8) begin
            // Machine Gun: Tone bursts alternating with true silence
            if (counter[11]) begin
                pcm_out <= speaker_state ? 16'h3000 : 16'hD000;
            end else begin
                pcm_out <= 16'd0;
            end
            
        end else begin
            // States 1-4 (D-Pad) & 7: Standard continuous tone
            pcm_out <= speaker_state ? 16'h3000 : 16'hD000;
        end
    end

endmodule
