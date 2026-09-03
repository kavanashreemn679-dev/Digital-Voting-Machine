`timescale 1ns/1ps

//======================================================
// DIGITAL VOTING MACHINE WITH SECURE MEMORY
//======================================================

module digital_voting_machine (
    input clk,
    input reset,

    input vote_A,
    input vote_B,
    input vote_C,

    input show_result,

    output reg [3:0] count_A,
    output reg [3:0] count_B,
    output reg [3:0] count_C,

    output reg [6:0] seg_A,
    output reg [6:0] seg_B,
    output reg [6:0] seg_C,

    output reg memory_valid
);

    //==================================================
    // FSM STATES
    //==================================================

    parameter IDLE    = 2'b00;
    parameter VOTING  = 2'b01;
    parameter RESULTS = 2'b10;

    reg [1:0] state;

    //==================================================
    // DEBOUNCE REGISTERS
    //==================================================

    reg [2:0] debounce_A;
    reg [2:0] debounce_B;
    reg [2:0] debounce_C;

    reg vote_A_prev;
    reg vote_B_prev;
    reg vote_C_prev;

    wire clean_A;
    wire clean_B;
    wire clean_C;

    assign clean_A = (debounce_A == 3'b111);
    assign clean_B = (debounce_B == 3'b111);
    assign clean_C = (debounce_C == 3'b111);

    //==================================================
    // EEPROM / FLASH MEMORY MODEL
    //==================================================

    reg [3:0] eeprom_A;
    reg [3:0] eeprom_B;
    reg [3:0] eeprom_C;

    reg [3:0] checksum;

    //==================================================
    // 7-SEGMENT DISPLAY
    //==================================================

    function [6:0] seven_segment;
        input [3:0] number;

        begin
            case (number)

                4'd0: seven_segment = 7'b1111110;
                4'd1: seven_segment = 7'b0110000;
                4'd2: seven_segment = 7'b1101101;
                4'd3: seven_segment = 7'b1111001;
                4'd4: seven_segment = 7'b0110011;
                4'd5: seven_segment = 7'b1011011;
                4'd6: seven_segment = 7'b1011111;
                4'd7: seven_segment = 7'b1110000;
                4'd8: seven_segment = 7'b1111111;
                4'd9: seven_segment = 7'b1111011;

                default:
                    seven_segment = 7'b0000000;

            endcase
        end
    endfunction

    //==================================================
    // BUTTON DEBOUNCING
    //==================================================

    always @(posedge clk) begin

        if (reset) begin

            debounce_A <= 3'b000;
            debounce_B <= 3'b000;
            debounce_C <= 3'b000;

        end
        else begin

            debounce_A <= {debounce_A[1:0], vote_A};
            debounce_B <= {debounce_B[1:0], vote_B};
            debounce_C <= {debounce_C[1:0], vote_C};

        end

    end

    //==================================================
    // MAIN FSM AND VOTE COUNTER
    //==================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;

            count_A <= 4'd0;
            count_B <= 4'd0;
            count_C <= 4'd0;

            eeprom_A <= 4'd0;
            eeprom_B <= 4'd0;
            eeprom_C <= 4'd0;

            checksum <= 4'd0;

            vote_A_prev <= 1'b0;
            vote_B_prev <= 1'b0;
            vote_C_prev <= 1'b0;

            memory_valid <= 1'b0;

        end
        else begin

            // Save previous button states
            vote_A_prev <= clean_A;
            vote_B_prev <= clean_B;
            vote_C_prev <= clean_C;

            case (state)

                //======================================
                // IDLE
                //======================================

                IDLE: begin

                    memory_valid <= 1'b0;

                    if (clean_A || clean_B || clean_C)
                        state <= VOTING;

                end

                //======================================
                // VOTING
                //======================================

                VOTING: begin

                    // Candidate A
                    if (clean_A && !vote_A_prev) begin

                        if (count_A < 4'd9)
                            count_A <= count_A + 1'b1;

                    end

                    // Candidate B
                    if (clean_B && !vote_B_prev) begin

                        if (count_B < 4'd9)
                            count_B <= count_B + 1'b1;

                    end

                    // Candidate C
                    if (clean_C && !vote_C_prev) begin

                        if (count_C < 4'd9)
                            count_C <= count_C + 1'b1;

                    end

                    // Store results
                    if (show_result) begin

                        eeprom_A <= count_A;
                        eeprom_B <= count_B;
                        eeprom_C <= count_C;

                        // Simple data integrity check
                        checksum <= count_A ^ count_B ^ count_C;

                        state <= RESULTS;

                    end

                end

                //======================================
                // RESULTS
                //======================================

                RESULTS: begin

                    // Check stored memory data
                    if ((eeprom_A ^ eeprom_B ^ eeprom_C)
                         == checksum)

                        memory_valid <= 1'b1;

                    else

                        memory_valid <= 1'b0;

                    // Return to voting
                    if (!show_result)
                        state <= VOTING;

                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end

    end

    //==================================================
    // 7-SEGMENT OUTPUT
    //==================================================

    always @(*) begin

        seg_A = seven_segment(count_A);
        seg_B = seven_segment(count_B);
        seg_C = seven_segment(count_C);

    end

endmodule


//======================================================
// TESTBENCH
//======================================================

module tb;

    reg clk;
    reg reset;

    reg vote_A;
    reg vote_B;
    reg vote_C;

    reg show_result;

    wire [3:0] count_A;
    wire [3:0] count_B;
    wire [3:0] count_C;

    wire [6:0] seg_A;
    wire [6:0] seg_B;
    wire [6:0] seg_C;

    wire memory_valid;

    //==================================================
    // CONNECT VOTING MACHINE
    //==================================================

    digital_voting_machine DUT (

        .clk(clk),
        .reset(reset),

        .vote_A(vote_A),
        .vote_B(vote_B),
        .vote_C(vote_C),

        .show_result(show_result),

        .count_A(count_A),
        .count_B(count_B),
        .count_C(count_C),

        .seg_A(seg_A),
        .seg_B(seg_B),
        .seg_C(seg_C),

        .memory_valid(memory_valid)

    );

    //==================================================
    // CLOCK GENERATION
    //==================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end

    //==================================================
    // WAVEFORM GENERATION
    // IMPORTANT: EcrioniX Wave uses dump.vcd
    //==================================================

    initial begin

        $dumpfile("dump.vcd");
        $dumpvars(0, tb);

    end

    //==================================================
    // TEST SEQUENCE
    //==================================================

    initial begin

        // Initial values
        reset = 1'b1;

        vote_A = 1'b0;
        vote_B = 1'b0;
        vote_C = 1'b0;

        show_result = 1'b0;

        // Reset
        #20;

        reset = 1'b0;

        //==============================================
        // VOTE 1 - CANDIDATE A
        //==============================================

        #10;
        vote_A = 1'b1;

        #40;
        vote_A = 1'b0;

        #20;

        //==============================================
        // VOTE 2 - CANDIDATE A
        //==============================================

        vote_A = 1'b1;

        #40;
        vote_A = 1'b0;

        #20;

        //==============================================
        // VOTE 3 - CANDIDATE B
        //==============================================

        vote_B = 1'b1;

        #40;
        vote_B = 1'b0;

        #20;

        //==============================================
        // VOTE 4 - CANDIDATE B
        //==============================================

        vote_B = 1'b1;

        #40;
        vote_B = 1'b0;

        #20;

        //==============================================
        // VOTE 5 - CANDIDATE C
        //==============================================

        vote_C = 1'b1;

        #40;
        vote_C = 1'b0;

        #20;

        //==============================================
        // SHOW RESULTS
        //==============================================

        show_result = 1'b1;

        #30;

        show_result = 1'b0;

        #20;

        //==============================================
        // PRINT FINAL RESULTS
        //==============================================

        $display("");
        $display("======================================");
        $display("       DIGITAL VOTING MACHINE");
        $display("======================================");

        $display("Candidate A Votes = %d", count_A);
        $display("Candidate B Votes = %d", count_B);
        $display("Candidate C Votes = %d", count_C);

        $display("--------------------------------------");

        $display("Memory Integrity = %b", memory_valid);

        $display("======================================");
        $display("");

        #20;

        $finish;

    end

    //==================================================
    // CONSOLE MONITOR
    //==================================================

    initial begin

        $monitor(
            "TIME=%0t | A=%d B=%d C=%d | Buttons=%b%b%b | Memory Valid=%b",
            $time,
            count_A,
            count_B,
            count_C,
            vote_A,
            vote_B,
            vote_C,
            memory_valid
        );

    end

endmodule