`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Unit Testbench: Data Memory (dmem)
// Self-checking testbench validating synchronous word-aligned write, combinational
// read, unaligned address handling, and out-of-bounds boundary protection.
//////////////////////////////////////////////////////////////////////////////////

module tb_dmem;

    logic        clk;
    logic        reset;
    logic [31:0] address;
    logic [31:0] write_data;
    logic        mem_write;
    wire  [31:0] read_data;

    always #5 clk = ~clk;

    dmem #(.words(64)) dut (
        .clk        (clk),
        .reset      (reset),
        .address    (address),
        .write_data (write_data),
        .mem_write  (mem_write),
        .read_data  (read_data)
    );

    int errors = 0;

    task check_read(input [31:0] exp, input string msg);
        #1;
        if (read_data !== exp) begin
            $error("FAIL [%s]: addr=%h got %h, expected %h", msg, address, read_data, exp);
            errors++;
        end else begin
            $display("PASS [%s]: addr=%h data=%h", msg, address, read_data);
        end
    endtask

    initial begin
        clk = 0;
        reset = 0;
        mem_write = 0;
        address = 0;
        write_data = 0;

        $display("=== Starting Data Memory Unit Tests ===");

        // 1. Initial contents check (default 0)
        address = 32'h00000000;
        check_read(32'h0, "Initial unwritten memory reads zero");

        // 2. Synchronous write to word-aligned address 0x04
        @(negedge clk);
        address = 32'h00000004;
        write_data = 32'hA5A5A5A5;
        mem_write = 1;
        @(negedge clk);
        mem_write = 0;

        // Combinational read
        address = 32'h00000004;
        check_read(32'hA5A5A5A5, "Read back from word-aligned 0x04");

        // 3. Write to word-aligned address 0x08
        @(negedge clk);
        address = 32'h00000008;
        write_data = 32'h5A5A5A5A;
        mem_write = 1;
        @(negedge clk);
        mem_write = 0;
        address = 32'h00000008;
        check_read(32'h5A5A5A5A, "Read back from word-aligned 0x08");

        // 4. Misaligned write rejection: attempt write to address 0x06 (address[1:0] == 2'b10)
        @(negedge clk);
        address = 32'h00000006;
        write_data = 32'hDEADBEEF;
        mem_write = 1;
        @(negedge clk);
        mem_write = 0;
        // Verify original word at 0x04 was NOT corrupted
        address = 32'h00000004;
        check_read(32'hA5A5A5A5, "Unaligned write rejected, memory preserved");

        // 5. Misaligned read returns 0
        address = 32'h00000005; // Misaligned
        check_read(32'h00000000, "Misaligned read returns 0");

        // 6. Out-of-bounds write protection (depth is 64 words, address 0x100 is word 64 - out of bounds)
        @(negedge clk);
        address = 32'h00000100;
        write_data = 32'hFFFFFFFF;
        mem_write = 1;
        @(negedge clk);
        mem_write = 0;
        address = 32'h00000100;
        check_read(32'h00000000, "Out-of-bounds read returns 0");

        if (errors == 0) begin
            $display(">>> ALL DATA MEMORY TESTS PASSED <<<");
        end else begin
            $display(">>> DATA MEMORY TESTS FAILED with %0d errors <<<", errors);
        end
        $finish;
    end

endmodule
