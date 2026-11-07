`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Immediate Generator / Sign Extender
// Module Name: signextn
// Description:
// Decodes and sign-extends immediate fields for RV32I instructions:
// - I-type: lw, addi, andi, ori, slti (12-bit signed immediate)
// - S-type: sw (12-bit signed immediate split across bits [31:25] and [11:7])
// - B-type: beq, bne (13-bit signed branch offset, LSB is implicit 0)
// - J-type: jal (21-bit signed jump target offset, LSB is implicit 0)
// - U-type: lui (20-bit upper immediate, lower 12 bits zeroed)
//////////////////////////////////////////////////////////////////////////////////

module signextn (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_source,
    output logic [31:0] immediate
);

    // Opcode bits [6:0] are not part of immediate encoding
    wire _unused_opcode = &{1'b0, instr[6:0]};

    // RISC-V formats keep the sign bit at instr[31] across all immediate types
    // to simplify sign-extension logic and reduce decoding latency.
    always @(*) begin
        case (imm_source)
            // I-type: imm[11:0] = instr[31:20]
            3'b000: immediate = {{20{instr[31]}}, instr[31:20]};

            // S-type: imm[11:0] = {instr[31:25], instr[11:7]}
            3'b001: immediate = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: imm[12:1] = {instr[31], instr[7], instr[30:25], instr[11:8]}, imm[0] = 0
            3'b010: immediate = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

            // J-type: imm[20:1] = {instr[31], instr[19:12], instr[20], instr[30:21]}, imm[0] = 0
            3'b011: immediate = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

            // U-type: imm[31:12] = instr[31:12], imm[11:0] = 0
            3'b100: immediate = {instr[31:12], 12'b0};

            default: immediate = 32'b0;
        endcase
    end

endmodule
