`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: Arithmetic Logic Unit (alu)
// Self-checking testbench covering all supported RV32I ALU operations and edge cases.
//////////////////////////////////////////////////////////////////////////////////

module tb_alu;

    logic [2:0]  alu_ctrl;
    logic [31:0] a, b;
    logic [31:0] result;
    logic        zero;

    alu dut (
        .alu_ctrl (alu_ctrl),
        .a        (a),
        .b        (b),
        .result   (result),
        .zero     (zero)
    );

    int errors = 0;

    task check(input [31:0] exp_res, input exp_zero, input string test_name);
        #1;
        if (result !== exp_res || zero !== exp_zero) begin
            $error("FAIL [%s]: alu_ctrl=%b a=%h b=%h -> result=%h (exp %h), zero=%b (exp %b)",
                   test_name, alu_ctrl, a, b, result, exp_res, zero, exp_zero);
            errors++;
        end else begin
            $display("PASS [%s]: result=%h, zero=%b", test_name, result, zero);
        end
    endtask

    initial begin
        $display("=== Starting ALU Unit Tests ===");

        // 1. ADD
        alu_ctrl = 3'b000; a = 32'd15; b = 32'd25;
        check(32'd40, 1'b0, "ADD positive");

        alu_ctrl = 3'b000; a = -32'd10; b = 32'd10;
        check(32'd0, 1'b1, "ADD zero result / zero flag");

        // 2. SUB
        alu_ctrl = 3'b001; a = 32'd50; b = 32'd20;
        check(32'd30, 1'b0, "SUB positive");

        alu_ctrl = 3'b001; a = 32'd42; b = 32'd42;
        check(32'd0, 1'b1, "SUB equal -> zero flag asserted");

        // 3. AND
        alu_ctrl = 3'b010; a = 32'hFFFF0000; b = 32'h00FFFF00;
        check(32'h00FF0000, 1'b0, "AND bitwise");

        // 4. OR
        alu_ctrl = 3'b011; a = 32'hF0F00000; b = 32'h0F0F0000;
        check(32'hFFFF0000, 1'b0, "OR bitwise");

        // 5. SLT (Signed Comparison)
        // Edge Case A: Negative (-5) < Positive (5) -> true (1)
        alu_ctrl = 3'b101; a = -32'd5; b = 32'd5;
        check(32'd1, 1'b0, "SLT negative < positive");

        // Edge Case B: Positive (5) < Negative (-5) -> false (0)
        alu_ctrl = 3'b101; a = 32'd5; b = -32'd5;
        check(32'd0, 1'b1, "SLT positive < negative");

        // Edge Case C: Equal numbers
        alu_ctrl = 3'b101; a = 32'd7; b = 32'd7;
        check(32'd0, 1'b1, "SLT equal values");

        // Edge Case D: Two negative numbers (-10 < -5) -> true (1)
        alu_ctrl = 3'b101; a = -32'd10; b = -32'd5;
        check(32'd1, 1'b0, "SLT negative < less negative");

        if (errors == 0) begin
            $display(">>> ALL ALU TESTS PASSED <<<");
        end else begin
            $display(">>> ALU TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
