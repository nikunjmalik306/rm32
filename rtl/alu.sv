`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: ALU
// Module Name: alu
// Description:
// 32-bit Arithmetic Logic Unit supporting RV32I operations:
// - ADD (000), SUB (001), AND (010), OR (011), SLT (101)
// - Computes zero flag for branch equality comparisons
//////////////////////////////////////////////////////////////////////////////////

module alu (
    input  logic [2:0]  alu_ctrl,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result,
    output logic        zero
);

    always_comb begin
        case (alu_ctrl)
            3'b000:  result = a + b;                                // ADD / ADDI / Address calculation
            3'b001:  result = a - b;                                // SUB / Branch condition compare
            3'b010:  result = a & b;                                // AND / ANDI
            3'b011:  result = a | b;                                // OR / ORI
            3'b101:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT / SLTI (signed comparison)
            default: result = 32'd0;
        endcase
    end

    // Zero flag indicates equality when doing subtraction (used by BEQ / BNE)
    assign zero = (result == 32'd0);

endmodule
