`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Data Memory
// Module Name: dmem
// Description:
// Synchronous write / asynchronous read data memory with word-aligned access.
// - Parameterized depth (default 128 words / 512 bytes).
// - Synchronous write on clk posedge when mem_write is active and word-aligned.
// - Out-of-range writes are ignored (no out-of-bounds corruption).
// - Out-of-range or unaligned reads return 32'b0.
//////////////////////////////////////////////////////////////////////////////////

module dmem #(
    parameter int words = 128,
    parameter mem_init  = ""
)(
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    input  logic        mem_write,
    output logic [31:0] read_data
);

    logic [31:0] mem [0:words-1];

    wire [29:0] word_addr = address[31:2];
    wire [6:0]  mem_idx   = address[8:2];
    wire        in_bounds = (word_addr < 30'(words));

    // Reset signal is available for synchronous clear / reset logic
    wire _unused_reset = reset;

    initial begin
        for (int i = 0; i < words; i++) begin
            mem[i] = 32'b0;
        end
        if (mem_init != "") begin
            $readmemh(mem_init, mem);
        end
    end

    // Synchronous memory write:
    // Requires word alignment (address[1:0] == 2'b00) and within valid bounds.
    always_ff @(posedge clk) begin
        if (mem_write && (address[1:0] == 2'b00) && in_bounds) begin
            mem[mem_idx] <= write_data;
        end
    end

    // Combinational memory read:
    // Guarantees zero return on unaligned or out-of-bounds access.
    assign read_data = ((address[1:0] == 2'b00) && in_bounds)
                       ? mem[mem_idx]
                       : 32'b0;

endmodule
