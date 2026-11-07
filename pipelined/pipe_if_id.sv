`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Pipeline Register: IF/ID Stage
//////////////////////////////////////////////////////////////////////////////////

module pipe_if_id (
    input  logic        clk,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,
    input  logic [31:0] pc_if,
    input  logic [31:0] pc_plus_4_if,
    input  logic [31:0] instr_if,
    output logic [31:0] pc_id,
    output logic [31:0] pc_plus_4_id,
    output logic [31:0] instr_id
);

    always_ff @(posedge clk) begin
        if (reset || flush) begin
            pc_id        <= 32'd0;
            pc_plus_4_id <= 32'd0;
            instr_id     <= 32'h00000013; // addi x0, x0, 0 (NOP bubble)
        end else if (!stall) begin
            pc_id        <= pc_if;
            pc_plus_4_id <= pc_plus_4_if;
            instr_id     <= instr_if;
        end
    end

endmodule
