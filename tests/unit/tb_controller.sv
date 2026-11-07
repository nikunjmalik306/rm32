`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: Controller (controller)
// Self-checking testbench covering instruction decoding across all 15 instructions
// in the RV32I subset, including branch resolution conditions.
//////////////////////////////////////////////////////////////////////////////////

module tb_controller;

    logic [6:0] op_code;
    logic [2:0] func3;
    logic [6:0] func7;
    logic       alu_zero;

    wire        reg_write;
    wire        mem_write;
    wire        alu_src;
    wire [1:0]  result_src;
    wire [2:0]  imm_src;
    wire [2:0]  alu_ctrl;
    wire        pc_src;

    controller dut (
        .op_code    (op_code),
        .func3      (func3),
        .func7      (func7),
        .alu_zero   (alu_zero),
        .reg_write  (reg_write),
        .mem_write  (mem_write),
        .alu_src    (alu_src),
        .result_src (result_src),
        .imm_src    (imm_src),
        .alu_ctrl   (alu_ctrl),
        .pc_src     (pc_src)
    );

    int errors = 0;

    task check_ctrl(
        input        exp_rw,
        input        exp_mw,
        input        exp_asrc,
        input [1:0]  exp_rsrc,
        input [2:0]  exp_isrc,
        input [2:0]  exp_actrl,
        input        exp_pcsrc,
        input string name
    );
        #1;
        if (reg_write !== exp_rw || mem_write !== exp_mw || alu_src !== exp_asrc ||
            result_src !== exp_rsrc || imm_src !== exp_isrc || alu_ctrl !== exp_actrl ||
            pc_src !== exp_pcsrc) begin
            $error("FAIL [%s]: rw=%b(exp %b) mw=%b(exp %b) asrc=%b(exp %b) rsrc=%b(exp %b) isrc=%b(exp %b) actrl=%b(exp %b) pcsrc=%b(exp %b)",
                   name, reg_write, exp_rw, mem_write, exp_mw, alu_src, exp_asrc,
                   result_src, exp_rsrc, imm_src, exp_isrc, alu_ctrl, exp_actrl, pc_src, exp_pcsrc);
            errors++;
        end else begin
            $display("PASS [%s]: rw=%b mw=%b asrc=%b rsrc=%b isrc=%b actrl=%b pcsrc=%b",
                     name, reg_write, mem_write, alu_src, result_src, imm_src, alu_ctrl, pc_src);
        end
    endtask

    initial begin
        $display("=== Starting Controller Unit Tests ===");

        // 1. LW (I-type load)
        op_code = 7'b0000011; func3 = 3'b010; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b01, 3'b000, 3'b000, 1'b0, "LW");

        // 2. SW (S-type store)
        op_code = 7'b0100011; func3 = 3'b010; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b0, 1'b1, 1'b1, 2'b00, 3'b001, 3'b000, 1'b0, "SW");

        // 3. R-type: ADD
        op_code = 7'b0110011; func3 = 3'b000; func7 = 7'b0000000; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 3'b000, 1'b0, "R-type ADD");

        // 4. R-type: SUB
        op_code = 7'b0110011; func3 = 3'b000; func7 = 7'b0100000; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 3'b001, 1'b0, "R-type SUB");

        // 5. R-type: AND
        op_code = 7'b0110011; func3 = 3'b111; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 3'b010, 1'b0, "R-type AND");

        // 6. R-type: OR
        op_code = 7'b0110011; func3 = 3'b110; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 3'b011, 1'b0, "R-type OR");

        // 7. R-type: SLT
        op_code = 7'b0110011; func3 = 3'b010; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b00, 3'b000, 3'b101, 1'b0, "R-type SLT");

        // 8. I-type: ADDI
        op_code = 7'b0010011; func3 = 3'b000; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b00, 3'b000, 3'b000, 1'b0, "I-type ADDI");

        // 9. I-type: ANDI
        op_code = 7'b0010011; func3 = 3'b111; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b00, 3'b000, 3'b010, 1'b0, "I-type ANDI");

        // 10. I-type: ORI
        op_code = 7'b0010011; func3 = 3'b110; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b00, 3'b000, 3'b011, 1'b0, "I-type ORI");

        // 11. I-type: SLTI
        op_code = 7'b0010011; func3 = 3'b010; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b00, 3'b000, 3'b101, 1'b0, "I-type SLTI");

        // 12. BEQ taken (zero=1)
        op_code = 7'b1100011; func3 = 3'b000; func7 = 7'b0; alu_zero = 1;
        check_ctrl(1'b0, 1'b0, 1'b0, 2'b00, 3'b010, 3'b001, 1'b1, "BEQ taken");

        // 13. BEQ not taken (zero=0)
        op_code = 7'b1100011; func3 = 3'b000; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b0, 1'b0, 1'b0, 2'b00, 3'b010, 3'b001, 1'b0, "BEQ not taken");

        // 14. BNE taken (zero=0)
        op_code = 7'b1100011; func3 = 3'b001; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b0, 1'b0, 1'b0, 2'b00, 3'b010, 3'b001, 1'b1, "BNE taken");

        // 15. BNE not taken (zero=1)
        op_code = 7'b1100011; func3 = 3'b001; func7 = 7'b0; alu_zero = 1;
        check_ctrl(1'b0, 1'b0, 1'b0, 2'b00, 3'b010, 3'b001, 1'b0, "BNE not taken");

        // 16. JAL
        op_code = 7'b1101111; func3 = 3'b000; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b0, 2'b10, 3'b011, 3'b000, 1'b1, "JAL");

        // 17. LUI
        op_code = 7'b0110111; func3 = 3'b000; func7 = 7'b0; alu_zero = 0;
        check_ctrl(1'b1, 1'b0, 1'b1, 2'b11, 3'b100, 3'b000, 1'b0, "LUI");

        if (errors == 0) begin
            $display(">>> ALL CONTROLLER TESTS PASSED <<<");
        end else begin
            $display(">>> CONTROLLER TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
