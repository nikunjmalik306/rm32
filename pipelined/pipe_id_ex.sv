`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Pipeline Register: ID/EX Stage
//////////////////////////////////////////////////////////////////////////////////

module pipe_id_ex (
    input  logic        clk,
    input  logic        reset,
    input  logic        flush,

    // Control signals in
    input  logic        reg_write_id,
    input  logic        mem_write_id,
    input  logic        alu_src_id,
    input  logic [1:0]  result_src_id,
    input  logic [2:0]  alu_ctrl_id,
    input  logic        branch_id,
    input  logic        jump_id,
    input  logic [2:0]  func3_id,

    // Data signals in
    input  logic [31:0] data1_id,
    input  logic [31:0] data2_id,
    input  logic [31:0] pc_id,
    input  logic [31:0] pc_plus_4_id,
    input  logic [31:0] immediate_id,
    input  logic [4:0]  rd_id,
    input  logic [4:0]  rs1_id,
    input  logic [4:0]  rs2_id,

    // Control signals out
    output logic        reg_write_ex,
    output logic        mem_write_ex,
    output logic        alu_src_ex,
    output logic [1:0]  result_src_ex,
    output logic [2:0]  alu_ctrl_ex,
    output logic        branch_ex,
    output logic        jump_ex,
    output logic [2:0]  func3_ex,

    // Data signals out
    output logic [31:0] data1_ex,
    output logic [31:0] data2_ex,
    output logic [31:0] pc_ex,
    output logic [31:0] pc_plus_4_ex,
    output logic [31:0] immediate_ex,
    output logic [4:0]  rd_ex,
    output logic [4:0]  rs1_ex,
    output logic [4:0]  rs2_ex
);

    always_ff @(posedge clk) begin
        if (reset || flush) begin
            reg_write_ex  <= 1'b0;
            mem_write_ex  <= 1'b0;
            alu_src_ex    <= 1'b0;
            result_src_ex <= 2'b00;
            alu_ctrl_ex   <= 3'b000;
            branch_ex     <= 1'b0;
            jump_ex       <= 1'b0;
            func3_ex      <= 3'b000;

            data1_ex      <= 32'd0;
            data2_ex      <= 32'd0;
            pc_ex         <= 32'd0;
            pc_plus_4_ex  <= 32'd0;
            immediate_ex  <= 32'd0;
            rd_ex         <= 5'd0;
            rs1_ex        <= 5'd0;
            rs2_ex        <= 5'd0;
        end else begin
            reg_write_ex  <= reg_write_id;
            mem_write_ex  <= mem_write_id;
            alu_src_ex    <= alu_src_id;
            result_src_ex <= result_src_id;
            alu_ctrl_ex   <= alu_ctrl_id;
            branch_ex     <= branch_id;
            jump_ex       <= jump_id;
            func3_ex      <= func3_id;

            data1_ex      <= data1_id;
            data2_ex      <= data2_id;
            pc_ex         <= pc_id;
            pc_plus_4_ex  <= pc_plus_4_id;
            immediate_ex  <= immediate_id;
            rd_ex         <= rd_id;
            rs1_ex        <= rs1_id;
            rs2_ex        <= rs2_id;
        end
    end

endmodule
