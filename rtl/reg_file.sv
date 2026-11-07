`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: Register File
// Module Name: reg_file
// Description:
// 32 x 32-bit dual-read, single-write register file.
// - Register x0 is architecturally hardwired to 0 (reads always return 0;
//   writes to x0 are discarded).
// - Synchronous write on clk posedge; combinational/asynchronous dual reads.
// - Active-high synchronous reset clears all registers.
//////////////////////////////////////////////////////////////////////////////////

module reg_file (
    input  logic [4:0]  address1,
    input  logic [4:0]  address2,
    input  logic [4:0]  address3,
    input  logic [31:0] write_data,
    input  logic        write_en,
    input  logic        reset,
    input  logic        clk,
    output logic [31:0] data1,
    output logic [31:0] data2
);

    logic [31:0] rf [0:31];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++) begin
                rf[i] <= 32'b0;
            end
        end else if (write_en && (address3 != 5'b0)) begin
            // Architectural constraint: x0 cannot be overwritten
            rf[address3] <= write_data;
        end
    end

    // Combinational reads: x0 always reads 0 even if internal state is corrupted or uninitialized
    assign data1 = (address1 == 5'b0) ? 32'b0 : rf[address1];
    assign data2 = (address2 == 5'b0) ? 32'b0 : rf[address2];

endmodule
