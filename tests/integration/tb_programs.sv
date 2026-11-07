`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Integration Testbench: Real Assembly Programs & Trace Generation
// Validates end-to-end program execution for:
//   Program 1: Sum 1..10 (sum10.hex) -> calculates sum=55 (0x37)
//   Program 2: Memory Loop (mem_loop.hex) -> stores 4 words, reads & sums to 100 (0x64)
// Dumps execution trace for automated trace-diff comparison with Python ISS golden model.
//////////////////////////////////////////////////////////////////////////////////

module tb_programs;

    logic clk;
    logic reset;

    always #5 clk = ~clk;

    // Use string parameter or define for test program
`ifndef TEST_HEX
    `define TEST_HEX "tests/asm/sum10.hex"
`endif

`ifndef TRACE_FILE
    `define TRACE_FILE "trace_rtl.txt"
`endif

    datapath #(
        .IMEM_WORDS (128),
        .IMEM_INIT  (`TEST_HEX),
        .DMEM_WORDS (128),
        .DMEM_INIT  ("")
    ) dut (
        .clk   (clk),
        .reset (reset)
    );

    int errors = 0;
    int trace_fd;
    int cycle_count = 0;

    // Trace logging on negedge clk
    always @(negedge clk) begin
        if (!reset && trace_fd != 0 && dut.pc < 128*4) begin
            $fwrite(trace_fd, "PC:%08x INSTR:%08x", dut.pc, dut.instruction);
            for (int i = 1; i < 32; i++) begin
                if (dut.register.rf[i] !== 32'd0) begin
                    $fwrite(trace_fd, " x%0d=%08x", i, dut.register.rf[i]);
                end
            end
            $fwrite(trace_fd, "\n");
        end
    end

    initial begin
        clk   = 0;
        reset = 1;
        trace_fd = $fopen(`TRACE_FILE, "w");

        $display("=== Running Program Test: %s ===", `TEST_HEX);

        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        // Run until program completion
        repeat (60) begin
            @(posedge clk);
            cycle_count++;
        end
        #1;

        $fclose(trace_fd);
        trace_fd = 0;

        // Conditional checks depending on which program was run
        if (`TEST_HEX == "tests/asm/sum10.hex") begin
            if (dut.register.rf[2] !== 32'd55) begin
                $error("FAIL: sum register x2 = %0d (exp 55)", dut.register.rf[2]);
                errors++;
            end else begin
                $display("PASS: sum register x2 = %0d (0x%h) as expected", dut.register.rf[2], dut.register.rf[2]);
            end

            if (dut.data_memory.mem[0] !== 32'd55) begin
                $error("FAIL: dmem[0] = %0d (exp 55)", dut.data_memory.mem[0]);
                errors++;
            end else begin
                $display("PASS: dmem[0] = %0d (0x%h) as expected", dut.data_memory.mem[0], dut.data_memory.mem[0]);
            end

            if (dut.register.rf[3] !== 32'd55) begin
                $error("FAIL: reload register x3 = %0d (exp 55)", dut.register.rf[3]);
                errors++;
            end else begin
                $display("PASS: reload register x3 = %0d (0x%h) as expected", dut.register.rf[3], dut.register.rf[3]);
            end
        end
        else if (`TEST_HEX == "tests/asm/mem_loop.hex") begin
            if (dut.register.rf[5] !== 32'd100) begin
                $error("FAIL: accumulated sum x5 = %0d (exp 100)", dut.register.rf[5]);
                errors++;
            end else begin
                $display("PASS: accumulated sum x5 = %0d (0x%h) as expected", dut.register.rf[5], dut.register.rf[5]);
            end

            if (dut.data_memory.mem[4] !== 32'd100) begin
                $error("FAIL: dmem[4] = %0d (exp 100)", dut.data_memory.mem[4]);
                errors++;
            end else begin
                $display("PASS: dmem[4] = %0d (0x%h) as expected", dut.data_memory.mem[4], dut.data_memory.mem[4]);
            end

            if (dut.register.rf[7] !== 32'd100) begin
                $error("FAIL: reloaded sum x7 = %0d (exp 100)", dut.register.rf[7]);
                errors++;
            end else begin
                $display("PASS: reloaded sum x7 = %0d (0x%h) as expected", dut.register.rf[7], dut.register.rf[7]);
            end
        end

        if (errors == 0) begin
            $display(">>> ALL CHECKS PASSED FOR %s <<<", `TEST_HEX);
        end else begin
            $display(">>> CHECKS FAILED FOR %s with %0d errors <<<", `TEST_HEX, errors);
        end

        #20;
        $finish;
    end

endmodule
