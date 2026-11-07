`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Pipeline Register: EX/MEM Stage
//////////////////////////////////////////////////////////////////////////////////

module pipe_ex_mem (
    input  logic        clk,
    input  logic        reset,

    // Controls in
    input  logic        reg_write_ex,
    input  logic        mem_write_ex,
    input  logic [1:0]  result_src_ex,

    // Data in
    input  logic [31:0] alu_result_ex,
    input  logic [31:0] write_data_ex,
    input  logic [4:0]  rd_ex,
    input  logic [31:0] pc_plus_4_ex,
    input  logic [31:0] immediate_ex,

    // Controls out
    output logic        reg_write_mem,
    output logic        mem_write_mem,
    output logic [1:0]  result_src_mem,

    // Data out
    output logic [31:0] alu_result_mem,
    output logic [31:0] write_data_mem,
    output logic [4:0]  rd_mem,
    output logic [31:0] pc_plus_4_mem,
    output logic [31:0] immediate_mem
);

    always_ff @(posedge clk) begin
        if (reset) begin
            reg_write_mem  <= 1'b0;
            mem_write_mem  <= 1'b0;
            result_src_mem <= 2'b00;

            alu_result_mem <= 32'd0;
            write_data_mem <= 32'd0;
            rd_mem         <= 5'd0;
            pc_plus_4_mem  <= 32'd0;
            immediate_mem  <= 32'd0;
        end else begin
            reg_write_mem  <= reg_write_ex;
            mem_write_mem  <= mem_write_ex;
            result_src_mem <= result_src_ex;

            alu_result_mem <= alu_result_ex;
            write_data_mem <= write_data_ex;
            rd_mem         <= rd_ex;
            pc_plus_4_mem  <= pc_plus_4_ex;
            immediate_mem  <= immediate_ex;
        end
    end

endmodule
