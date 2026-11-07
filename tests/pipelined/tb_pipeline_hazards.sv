`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Integration Testbench: 5-Stage Pipeline Hazards & Forwarding
// Verifies:
// - RAW back-to-back forwarding
// - x0 forwarding suppression
// - Load-use stall (1-cycle bubble)
// - Branch taken with 2-cycle flush
//////////////////////////////////////////////////////////////////////////////////

module tb_pipeline_hazards;

    logic clk;
    logic reset;
    wire [31:0] cycles;
    wire [31:0] retired;

    always #5 clk = ~clk;

    pipe_datapath #(
        .IMEM_WORDS (128),
        .IMEM_INIT  ("tests/asm/hazard_tests.hex"),
        .DMEM_WORDS (128),
        .DMEM_INIT  ("")
    ) dut (
        .clk                (clk),
        .reset              (reset),
        .cycles_count       (cycles),
        .retired_inst_count (retired)
    );

    int errors = 0;

    task check_reg(input [4:0] idx, input [31:0] exp, input string msg);
        if (dut.rf_inst.rf[idx] !== exp) begin
            $error("FAIL [%s]: x%0d = %h (exp %h)", msg, idx, dut.rf_inst.rf[idx], exp);
            errors++;
        end else begin
            $display("PASS [%s]: x%0d = %h as expected", msg, idx, dut.rf_inst.rf[idx]);
        end
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        $display("=== Running 5-Stage Pipeline Hazard Unit Verification ===");

        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        // Run until program completes through writeback
        repeat (30) @(posedge clk);
        #1;

        // 1. RAW forwarding
        check_reg(1, 32'd10, "Base value in x1");
        check_reg(2, 32'd20, "RAW EX/MEM -> EX forward to x2");
        check_reg(3, 32'd30, "RAW EX/MEM & MEM/WB forward to x3");

        // 2. x0 forwarding corner case
        check_reg(4, 32'd5,  "x0 forwarding suppression (x4 = 5, not 35)");

        // 3. Load-use stall & forward
        check_reg(5, 32'd30, "Loaded value in x5");
        check_reg(6, 32'd42, "Load-use 1-cycle stall then forward to x6");

        // 4. Branch taken after dependent instruction & flush
        check_reg(7, 32'd15, "Branch operand 1 in x7");
        check_reg(8, 32'd0,  "Branch operand 2 in x8");
        check_reg(9, 32'd77, "Branch taken after dependent instruction, flushed target skipped");

        if (errors == 0) begin
            $display(">>> ALL PIPELINE HAZARD TESTS PASSED <<<");
            $display("Pipeline Cycles: %0d | Retired Instructions: %0d", cycles, retired);
        end else begin
            $display(">>> PIPELINE HAZARD TESTS FAILED with %0d errors <<<", errors);
        end

        #20;
        $finish;
    end

endmodule
