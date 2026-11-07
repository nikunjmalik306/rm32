`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Integration Testbench: Instruction Classes & Corner Cases
// Loads tests/asm/edge_cases.hex and verifies:
// - x0 write protection
// - SLT/SLTI signed vs unsigned comparisons
// - Negative immediate arithmetic
// - Bitwise logic (AND, OR, ANDI, ORI)
// - Branch taken (BEQ) and branch not taken (BNE)
// - LUI upper 20 bits
// - JAL link address write and jump
//////////////////////////////////////////////////////////////////////////////////

module tb_instruction_classes;

    logic clk;
    logic reset;

    always #5 clk = ~clk;

    datapath #(
        .IMEM_WORDS (128),
        .IMEM_INIT  ("tests/asm/edge_cases.hex"),
        .DMEM_WORDS (128),
        .DMEM_INIT  ("")
    ) dut (
        .clk   (clk),
        .reset (reset)
    );

    int errors = 0;

    task check_reg(input [4:0] idx, input [31:0] exp, input string name);
        if (dut.register.rf[idx] !== exp) begin
            $error("FAIL [%s]: x%0d = %h (exp %h)", name, idx, dut.register.rf[idx], exp);
            errors++;
        end else begin
            $display("PASS [%s]: x%0d = %h as expected", name, idx, dut.register.rf[idx]);
        end
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        $display("=== Running Instruction Classes & Corner Cases Integration Test ===");

        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        // Run until edge_cases program finishes (approx 35 cycles)
        repeat (35) @(posedge clk);
        #1;

        // 1. x0 hardwired zero check
        check_reg(0, 32'h00000000, "x0 write protection invariant");

        // 2. SLT / SLTI signed comparisons
        check_reg(12, 32'd1, "SLT -5 < 5 (signed true)");
        check_reg(13, 32'd0, "SLT 5 < -5 (signed false)");
        check_reg(14, 32'd1, "SLTI -5 < 0 (signed true)");
        check_reg(15, 32'd0, "SLTI 5 < 0 (signed false)");

        // 3. Negative immediate addition
        check_reg(16, -32'd5, "ADDI 5 + (-10) = -5");

        // 4. Bitwise logic
        check_reg(19, 32'd5, "AND 15 & 5 = 5");
        check_reg(20, 32'd15, "OR 15 | 5 = 15");
        check_reg(21, 32'd3, "ANDI 15 & 3 = 3");
        check_reg(22, 32'd7, "ORI 5 | 2 = 7");

        // 5. Subtraction producing zero
        check_reg(23, 32'd0, "SUB 5 - 5 = 0");

        // 6. Branch taken (BEQ) and not taken (BNE)
        check_reg(24, 32'd1, "BEQ taken correctly branched");
        check_reg(25, 32'd1, "BNE not taken fell through correctly");

        // 7. LUI 20-bit immediate
        check_reg(26, 32'h12345000, "LUI 0x12345 loaded to upper 20 bits");

        // 8. JAL link register and target
        check_reg(1,  32'h00000064, "JAL link register x1 captured return address PC+4");
        check_reg(27, 32'd42,        "JAL jumped over trap to target");

        if (errors == 0) begin
            $display(">>> ALL INSTRUCTION CLASS INTEGRATION TESTS PASSED <<<");
        end else begin
            $display(">>> INSTRUCTION CLASS INTEGRATION TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
