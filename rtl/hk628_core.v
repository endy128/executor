module hk628_core (
    input wire clk,           // 50MHz
    input wire [7:0] btn,     // 8 Sound Buttons
    input wire low_batt_btn,  // Hold this to simulate dying battery
    output reg [15:0] pcm_out // 16-bit Signed Audio
);

    // --- Low Battery / Turbo Logic ---
    // Normally 2500 for a crisp sound. Increasing this slows the "chip" down.
    reg [15:0] tick_limit;
    always @(posedge clk) begin
        tick_limit <= low_batt_btn ? 6000 : 2500; 
    end

    reg [15:0] tick_cnt;
    wire tick = (tick_cnt >= tick_limit);
    always @(posedge clk) tick_cnt <= tick ? 0 : tick_cnt + 1;

    // --- State Machine ---
    reg [3:0] state = 0;
    reg [23:0] counter = 0;
    reg [15:0] freq_period, tone_cnt;
    reg speaker_state;
    reg [15:0] lfsr = 16'hACE1;

    always @(posedge clk) begin
        if (tick) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            
            if (state == 0) begin
                if (btn != 0) begin
                    // Assign state based on button pressed
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

            // --- Synthesis Logic for each Sound ---
            case (state)
                1: freq_period <= 200 + counter[10:0]; // Rifle Sweep
                2: freq_period <= 200 + {counter[9:0], 2'b00}; // Echo Rifle
                3: freq_period <= counter[11] ? 800 : 500; // Telephone
                4: freq_period <= counter[10] ? 400 : 300; // Dual Tone Rifle
                7: freq_period <= 100 + (lfsr[5:0] << 2); // Electric Gun (Chaos)
                8: freq_period <= 300; // Machine Gun base pitch
                default: freq_period <= 0;
            endcase
            
            if (freq_period > 0) begin
                if (tone_cnt >= freq_period) begin
                    tone_cnt <= 0;
                    speaker_state <= ~speaker_state;
                end else tone_cnt <= tone_cnt + 1;
            end
        end
    end

    // --- Output Mixer ---
    always @(posedge clk) begin
        case (state)
            5, 6: pcm_out <= (lfsr[0] && counter < 15000) ? 16'h3000 : 16'hD000; // Bombs
            8:    pcm_out <= (speaker_state && counter[11]) ? 16'h3000 : 16'hD000; // Machine Gun Burst
            0:    pcm_out <= 0;
            default: pcm_out <= speaker_state ? 16'h3000 : 16'hD000;
        endcase
    end
endmodule
