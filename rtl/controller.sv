`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Controller
// Module Name: controller
// Description:
// Decodes RISC-V 32-bit instructions (RV32I subset):
// - Instructions: lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui
// - Contains Main Decoder and ALU Decoder (Harris & Harris microarchitecture style)
// - Generates control signals for datapath multiplexers, register file, and memory
//////////////////////////////////////////////////////////////////////////////////

module controller (
    input  logic [6:0] op_code,
    input  logic [2:0] func3,
    input  logic [6:0] func7,
    input  logic       alu_zero,
    output logic       reg_write,
    output logic       mem_write,
    output logic       alu_src,
    output logic [1:0] result_src,
    output logic [2:0] imm_src,
    output logic [2:0] alu_ctrl,
    output logic       pc_src
);

    logic [1:0] alu_op;
    logic       branch;
    logic       jump;

    // =========================================================================
    // MAIN DECODER
    // Translates 7-bit opcode into high-level datapath controls
    // =========================================================================
    always_comb begin
        case (op_code)
            // LW: Load Word (I-type)
            7'b0000011: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type
                alu_src    = 1'b1;   // immediate
                mem_write  = 1'b0;
                result_src = 2'b01;  // memory read data
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b00;  // ADD (base + offset)
            end

            // SW: Store Word (S-type)
            7'b0100011: begin
                reg_write  = 1'b0;
                imm_src    = 3'b001; // S-type
                alu_src    = 1'b1;   // immediate
                mem_write  = 1'b1;
                result_src = 2'b00;  // don't care
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b00;  // ADD (base + offset)
            end

            // R-type: add, sub, and, or, slt
            7'b0110011: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // unused
                alu_src    = 1'b0;   // rs2 data
                mem_write  = 1'b0;
                result_src = 2'b00;  // ALU result
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b10;  // Determined by funct3/funct7
            end

            // I-type ALU: addi, andi, ori, slti
            7'b0010011: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type
                alu_src    = 1'b1;   // immediate
                mem_write  = 1'b0;
                result_src = 2'b00;  // ALU result
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b10;  // Determined by funct3
            end

            // Branch: beq, bne (B-type)
            7'b1100011: begin
                reg_write  = 1'b0;
                imm_src    = 3'b010; // B-type
                alu_src    = 1'b0;   // rs2 data for comparison
                mem_write  = 1'b0;
                result_src = 2'b00;  // don't care
                branch     = 1'b1;
                jump       = 1'b0;
                alu_op     = 2'b01;  // SUB for equality test
            end

            // JAL: Jump and Link (J-type)
            7'b1101111: begin
                reg_write  = 1'b1;
                imm_src    = 3'b011; // J-type
                alu_src    = 1'b0;   // don't care
                mem_write  = 1'b0;
                result_src = 2'b10;  // PC + 4 to rd
                branch     = 1'b0;
                jump       = 1'b1;
                alu_op     = 2'b00;
            end

            // LUI: Load Upper Immediate (U-type)
            7'b0110111: begin
                reg_write  = 1'b1;
                imm_src    = 3'b100; // U-type
                alu_src    = 1'b1;   // don't care
                mem_write  = 1'b0;
                result_src = 2'b11;  // immediate to rd
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b00;
            end

            default: begin
                reg_write  = 1'b0;
                imm_src    = 3'b000;
                alu_src    = 1'b0;
                mem_write  = 1'b0;
                result_src = 2'b00;
                branch     = 1'b0;
                jump       = 1'b0;
                alu_op     = 2'b00;
            end
        endcase
    end

    // =========================================================================
    // ALU DECODER
    // Translates alu_op, func3, and func7[5] into 3-bit alu_ctrl
    // =========================================================================
    wire op_5     = op_code[5];
    wire func7_5  = func7[5];
    wire _unused_func7 = &{1'b0, func7[6], func7[4:0]};

    always_comb begin
        case (alu_op)
            2'b00: alu_ctrl = 3'b000; // ADD (lw, sw, jal, lui)
            2'b01: alu_ctrl = 3'b001; // SUB (beq, bne)
            2'b10: begin             // R-type and I-type ALU
                case (func3)
                    3'b000: begin
                        // R-type SUB has op_code[5]==1 AND func7[5]==1; ADDI/ADD have 0
                        if (op_5 & func7_5)
                            alu_ctrl = 3'b001; // SUB
                        else
                            alu_ctrl = 3'b000; // ADD / ADDI
                    end
                    3'b010:  alu_ctrl = 3'b101; // SLT / SLTI (signed)
                    3'b110:  alu_ctrl = 3'b011; // OR / ORI
                    3'b111:  alu_ctrl = 3'b010; // AND / ANDI
                    default: alu_ctrl = 3'b000;
                endcase
            end
            default: alu_ctrl = 3'b000;
        endcase
    end

    // =========================================================================
    // BRANCH CONDITION LOGIC
    // func3[0] == 0: BEQ (branch when zero == 1)
    // func3[0] == 1: BNE (branch when zero == 0)
    // =========================================================================
    wire branch_condition = func3[0] ? (~alu_zero) : alu_zero;
    assign pc_src = jump | (branch & branch_condition);

endmodule
