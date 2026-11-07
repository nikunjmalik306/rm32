`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Instruction Memory
// Module Name: imem
// Description:
// Read-only instruction memory with word-aligned addressing.
// - Parameterized depth (default 128 words / 512 bytes).
// - Initialized via $readmemh with hexadecimal machine code.
// - Combinational read: returns word at address[8:2].
// - Out-of-range or unaligned addresses return NOP (0x00000013: addi x0, x0, 0).
//////////////////////////////////////////////////////////////////////////////////

module imem #(
    parameter int words = 128,
    parameter mem_init  = ""
)(
    input  logic [31:0] address,
    output logic [31:0] instruction
);

    logic [31:0] mem [0:words-1];

    wire [29:0] word_addr = address[31:2];
    wire [6:0]  mem_idx   = address[8:2];
    wire        in_bounds = (word_addr < 30'(words));

    initial begin
        for (int i = 0; i < words; i++) begin
            mem[i] = 32'h00000013; // addi x0, x0, 0 (NOP)
        end
        if (mem_init != "") begin
            $readmemh(mem_init, mem);
        end
    end

    // Combinational instruction fetch:
    // Enforces word alignment (address[1:0] == 2'b00) and bounds check.
    assign instruction = ((address[1:0] == 2'b00) && in_bounds)
                         ? mem[mem_idx]
                         : 32'h00000013;

endmodule
