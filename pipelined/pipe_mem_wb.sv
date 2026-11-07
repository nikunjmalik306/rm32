`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Pipeline Register: MEM/WB Stage
//////////////////////////////////////////////////////////////////////////////////

module pipe_mem_wb (
    input  logic        clk,
    input  logic        reset,

    // Controls in
    input  logic        reg_write_mem,
    input  logic [1:0]  result_src_mem,

    // Data in
    input  logic [31:0] alu_result_mem,
    input  logic [31:0] read_data_mem,
    input  logic [4:0]  rd_mem,
    input  logic [31:0] pc_plus_4_mem,
    input  logic [31:0] immediate_mem,

    // Controls out
    output logic        reg_write_wb,
    output logic [1:0]  result_src_wb,

    // Data out
    output logic [31:0] alu_result_wb,
    output logic [31:0] read_data_wb,
    output logic [4:0]  rd_wb,
    output logic [31:0] pc_plus_4_wb,
    output logic [31:0] immediate_wb
);

    always_ff @(posedge clk) begin
        if (reset) begin
            reg_write_wb  <= 1'b0;
            result_src_wb <= 2'b00;

            alu_result_wb <= 32'd0;
            read_data_wb  <= 32'd0;
            rd_wb         <= 5'd0;
            pc_plus_4_wb  <= 32'd0;
            immediate_wb  <= 32'd0;
        end else begin
            reg_write_wb  <= reg_write_mem;
            result_src_wb <= result_src_mem;

            alu_result_wb <= alu_result_mem;
            read_data_wb  <= read_data_mem;
            rd_wb         <= rd_mem;
            pc_plus_4_wb  <= pc_plus_4_mem;
            immediate_wb  <= immediate_mem;
        end
    end

endmodule
