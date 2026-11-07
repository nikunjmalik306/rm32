`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: Register File (reg_file)
// Self-checking testbench validating x0 write-suppression, dual-read, and reset.
//////////////////////////////////////////////////////////////////////////////////

module tb_reg_file;

    logic [4:0]  address1, address2, address3;
    logic [31:0] write_data;
    logic        write_en;
    logic        reset;
    logic        clk;
    wire  [31:0] data1;
    wire  [31:0] data2;

    always #5 clk = ~clk;

    reg_file dut (
        .address1   (address1),
        .address2   (address2),
        .address3   (address3),
        .write_data (write_data),
        .write_en   (write_en),
        .reset      (reset),
        .clk        (clk),
        .data1      (data1),
        .data2      (data2)
    );

    int errors = 0;

    task check_reads(input [31:0] exp1, input [31:0] exp2, input string msg);
        #1;
        if (data1 !== exp1 || data2 !== exp2) begin
            $error("FAIL [%s]: data1=%h (exp %h), data2=%h (exp %h)", msg, data1, exp1, data2, exp2);
            errors++;
        end else begin
            $display("PASS [%s]: data1=%h, data2=%h", msg, data1, data2);
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        write_en = 0;
        address1 = 0; address2 = 0; address3 = 0; write_data = 0;

        $display("=== Starting Register File Unit Tests ===");

        // 1. Reset check
        repeat (2) @(posedge clk);
        #1;
        reset = 0;
        address1 = 5'd0; address2 = 5'd1;
        check_reads(32'h0, 32'h0, "Post-reset zeroes");

        // 2. Normal write to register x1 and x2
        @(negedge clk);
        address3 = 5'd1; write_data = 32'h12345678; write_en = 1;
        @(negedge clk);
        address3 = 5'd2; write_data = 32'h87654321; write_en = 1;
        @(negedge clk);
        write_en = 0;

        // Dual read ports
        address1 = 5'd1; address2 = 5'd2;
        check_reads(32'h12345678, 32'h87654321, "Dual read x1 and x2");

        // Simultaneous read of the same register on both ports
        address1 = 5'd1; address2 = 5'd1;
        check_reads(32'h12345678, 32'h12345678, "Simultaneous read of x1 on both ports");

        // 3. Architectural Invariant: Writes to x0 must be completely ignored
        @(negedge clk);
        address3 = 5'd0; write_data = 32'hDEADBEEF; write_en = 1;
        @(negedge clk);
        write_en = 0;
        address1 = 5'd0; address2 = 5'd1;
        check_reads(32'h0, 32'h12345678, "x0 write suppression verification");

        // 4. Synchronous write disable: ensure no write occurs when write_en=0
        @(negedge clk);
        address3 = 5'd1; write_data = 32'hCAFEBABE; write_en = 0;
        @(negedge clk);
        address1 = 5'd1; address2 = 5'd0;
        check_reads(32'h12345678, 32'h0, "write_en=0 maintains register state");

        if (errors == 0) begin
            $display(">>> ALL REGISTER FILE TESTS PASSED <<<");
        end else begin
            $display(">>> REGISTER FILE TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
