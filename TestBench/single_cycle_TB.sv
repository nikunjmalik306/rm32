`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Single-Cycle Core Integration Testbench
// Module Name: single_cycle_TB
// Description:
// Self-checking integration testbench for the RM32 single-cycle datapath.
// Validates execution of initial load/store verification program.
//////////////////////////////////////////////////////////////////////////////////

module single_cycle_TB;

    logic clk;
    logic reset;

    always #5 clk = ~clk;

    datapath dut (
        .clk   (clk),
        .reset (reset)
    );

    int errors = 0;

    initial begin
        clk   = 0;
        reset = 1; // Active-high reset
        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        repeat (8) @(posedge clk);
        #1;

        if (dut.register.rf[19] !== 32'hDEADBEEF) begin
            $error("FAIL: x19 = %h, expected DEADBEEF", dut.register.rf[19]);
            errors++;
        end else begin
            $display("PASS: x19 = %h as expected", dut.register.rf[19]);
        end

        if (dut.data_memory.mem[3] !== 32'hDEADBEEF) begin
            $error("FAIL: datamem 12 = %h, expected DEADBEEF", dut.data_memory.mem[3]);
            errors++;
        end else begin
            $display("PASS: datamem 12 = %h as expected", dut.data_memory.mem[3]);
        end

        if (errors == 0) begin
            $display("ALL TESTS PASSED: single_cycle_TB");
        end else begin
            $display("TEST FAILED with %0d errors: single_cycle_TB", errors);
        end

        #20;
        $finish;
    end

endmodule
