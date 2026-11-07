`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Pipeline Hazard Unit
// Module Name: hazard_unit
// Description:
// Coordinates data forwarding and pipeline hazard resolution for 5-stage core:
// 1. Data Forwarding:
//    - EX/MEM -> EX (ForwardA/B = 2'b10)
//    - MEM/WB -> EX (ForwardA/B = 2'b01)
//    - x0 write suppression: rd != 5'd0 enforced on all forwarding paths.
//    - Priority: EX/MEM has priority over MEM/WB (most recent data).
// 2. Load-Use Hazard Detection:
//    - Detects when instruction in EX is a load and destination matches ID rs1/rs2.
//    - Stalls PC and IF/ID stages for 1 cycle; flushes ID/EX stage (bubble).
// 3. Control Hazard Resolution:
//    - Branch and jump resolution occurs in EX stage.
//    - When pc_src_ex is taken: flushes IF/ID and ID/EX stages (2-cycle branch penalty).
//////////////////////////////////////////////////////////////////////////////////

module hazard_unit (
    // Instruction Decode stage register sources
    input  logic [4:0]  rs1_id,
    input  logic [4:0]  rs2_id,

    // Execute stage register sources & destination
    input  logic [4:0]  rs1_ex,
    input  logic [4:0]  rs2_ex,
    input  logic [4:0]  rd_ex,
    input  logic [1:0]  result_src_ex,

    // Memory stage register writeback info
    input  logic [4:0]  rd_mem,
    input  logic        reg_write_mem,

    // Writeback stage register writeback info
    input  logic [4:0]  rd_wb,
    input  logic        reg_write_wb,

    // Branch / Jump decision from EX stage
    input  logic        pc_src_ex,

    // Hazard control outputs
    output logic [1:0]  forward_a,
    output logic [1:0]  forward_b,
    output logic        stall_pc,
    output logic        stall_if_id,
    output logic        flush_if_id,
    output logic        flush_id_ex
);

    // =========================================================================
    // 1. DATA FORWARDING TO ALU OPERANDS
    // =========================================================================
    always_comb begin
        // Forwarding logic for ALU Operand A
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs1_ex)) begin
            forward_a = 2'b10; // Forward from EX/MEM stage
        end else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs1_ex)) begin
            forward_a = 2'b01; // Forward from MEM/WB stage
        end else begin
            forward_a = 2'b00; // No forwarding (use register file read)
        end

        // Forwarding logic for ALU Operand B
        if (reg_write_mem && (rd_mem != 5'd0) && (rd_mem == rs2_ex)) begin
            forward_b = 2'b10; // Forward from EX/MEM stage
        end else if (reg_write_wb && (rd_wb != 5'd0) && (rd_wb == rs2_ex)) begin
            forward_b = 2'b01; // Forward from MEM/WB stage
        end else begin
            forward_b = 2'b00; // No forwarding (use register file read)
        end
    end

    // =========================================================================
    // 2. LOAD-USE HAZARD DETECTION
    // Load instruction is currently in EX (result_src_ex == 2'b01) and its
    // destination register rd_ex is needed by the instruction in ID.
    // =========================================================================
    wire is_load_ex = (result_src_ex == 2'b01);
    wire load_use_hazard = is_load_ex && (rd_ex != 5'd0) &&
                           ((rd_ex == rs1_id) || (rd_ex == rs2_id));

    // =========================================================================
    // 3. STALL & FLUSH GENERATION
    // =========================================================================
    always_comb begin
        if (pc_src_ex) begin
            // Branch taken or Jump in EX: flush the two younger instructions
            stall_pc    = 1'b0;
            stall_if_id = 1'b0;
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end else if (load_use_hazard) begin
            // Load-use stall: freeze PC and IF/ID, insert bubble into ID/EX
            stall_pc    = 1'b1;
            stall_if_id = 1'b1;
            flush_if_id = 1'b0;
            flush_id_ex = 1'b1;
        end else begin
            // Normal sequential execution
            stall_pc    = 1'b0;
            stall_if_id = 1'b0;
            flush_if_id = 1'b0;
            flush_id_ex = 1'b0;
        end
    end

endmodule
