`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: Sign Extender / Immediate Generator (signextn)
// Tests I, S, B, J, and U immediate assembly and sign extension.
//////////////////////////////////////////////////////////////////////////////////

module tb_signextn;

    logic [31:0] instr;
    logic [2:0]  imm_source;
    wire  [31:0] immediate;

    signextn dut (
        .instr      (instr),
        .imm_source (imm_source),
        .immediate  (immediate)
    );

    int errors = 0;

    task check(input [31:0] exp, input string name);
        #1;
        if (immediate !== exp) begin
            $error("FAIL [%s]: instr=%h imm_src=%b -> got %h, expected %h",
                   name, instr, imm_source, immediate, exp);
            errors++;
        end else begin
            $display("PASS [%s]: immediate=%h", name, immediate);
        end
    endtask

    initial begin
        $display("=== Starting Sign Extender Unit Tests ===");

        // 1. I-type: lw x1, 4(x0) -> imm=4 (positive)
        // [31:20] = 12'h004
        instr = 32'h00402083; imm_source = 3'b000;
        check(32'h00000004, "I-type positive 4");

        // I-type: addi x1, x0, -4 -> imm=-4 (negative, sign-extended)
        // [31:20] = 12'hFFC
        instr = 32'hFFC00093; imm_source = 3'b000;
        check(32'hFFFFFFFC, "I-type negative -4");

        // 2. S-type: sw x2, 12(x1) -> imm=12 (0x00C)
        // imm[11:5]=0000000, imm[4:0]=01100 -> [31:25]=0, [11:7]=12
        instr = 32'h0020A623; imm_source = 3'b001;
        check(32'h0000000C, "S-type positive 12");

        // S-type: sw x2, -12(x1) -> imm=-12 (0xFF4)
        // imm[11:5]=1111111, imm[4:0]=10100
        instr = 32'hFE20AA23; imm_source = 3'b001;
        check(32'hFFFFFFF4, "S-type negative -12");

        // 3. B-type: beq x1, x2, +8 -> imm=8 (0x008)
        // imm[12]=0, imm[11]=0, imm[10:5]=0, imm[4:1]=4, imm[0]=0
        // instr[31]=0, instr[7]=0, instr[30:25]=0, instr[11:8]=4
        instr = 32'h00208463; imm_source = 3'b010;
        check(32'h00000008, "B-type forward branch +8 (bit 0 is 0)");

        // B-type: beq x1, x2, -8 -> imm=-8 (0xFFFFFFF8)
        // imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1100, imm[0]=0
        instr = 32'hFE208CE3; imm_source = 3'b010;
        check(32'hFFFFFFF8, "B-type backward branch -8");

        // 4. J-type: jal x1, +16 -> imm=16 (0x00010)
        // imm[20]=0, imm[10:1]=8, imm[11]=0, imm[19:12]=0
        instr = 32'h010000EF; imm_source = 3'b011;
        check(32'h00000010, "J-type jump forward +16");

        // 5. U-type: lui x1, 0x12345 -> imm=0x12345000
        instr = 32'h123450B7; imm_source = 3'b100;
        check(32'h12345000, "U-type LUI 20-bit immediate (lower 12 bits zeroed)");

        if (errors == 0) begin
            $display(">>> ALL SIGN EXTENDER TESTS PASSED <<<");
        end else begin
            $display(">>> SIGN EXTENDER TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
