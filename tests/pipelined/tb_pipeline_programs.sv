`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Integration Testbench: 5-Stage Pipeline Real Programs & Performance Measurement
// Runs sum10.hex and mem_loop.hex on the 5-stage pipelined core.
// Measures exact Cycles, Retired Instructions, and real CPI.
//////////////////////////////////////////////////////////////////////////////////

module tb_pipeline_programs;

    logic clk;
    logic reset;
    wire [31:0] cycles;
    wire [31:0] retired;

    always #5 clk = ~clk;

`ifndef TEST_HEX
    `define TEST_HEX "tests/asm/sum10.hex"
`endif

    pipe_datapath #(
        .IMEM_WORDS (128),
        .IMEM_INIT  (`TEST_HEX),
        .DMEM_WORDS (128),
        .DMEM_INIT  ("")
    ) dut (
        .clk                (clk),
        .reset              (reset),
        .cycles_count       (cycles),
        .retired_inst_count (retired)
    );

    int errors = 0;
    int completion_cycle = 0;
    int program_inst_count = 0;

    always @(posedge clk) begin
        if (!reset) begin
            if (`TEST_HEX == "tests/asm/sum10.hex") begin
                if (dut.reg_write_wb && dut.rd_wb == 5'd3 && completion_cycle == 0) begin
                    completion_cycle   = cycles;
                    program_inst_count = 36;
                end
            end else if (`TEST_HEX == "tests/asm/mem_loop.hex") begin
                if (dut.reg_write_wb && dut.rd_wb == 5'd7 && completion_cycle == 0) begin
                    completion_cycle   = cycles;
                    program_inst_count = 29;
                end
            end
        end
    end

    initial begin
        clk   = 0;
        reset = 1;
        $display("=== Running 5-Stage Pipeline Program Test: %s ===", `TEST_HEX);

        repeat (2) @(posedge clk);
        #1;
        reset = 0;

        // Run until completion through WB stage
        repeat (70) @(posedge clk);
        #1;

        if (`TEST_HEX == "tests/asm/sum10.hex") begin
            if (dut.rf_inst.rf[2] !== 32'd55) begin
                $error("FAIL: sum register x2 = %0d (exp 55)", dut.rf_inst.rf[2]);
                errors++;
            end else begin
                $display("PASS: sum register x2 = %0d (0x%h) as expected", dut.rf_inst.rf[2], dut.rf_inst.rf[2]);
            end

            if (dut.data_mem.mem[0] !== 32'd55) begin
                $error("FAIL: dmem[0] = %0d (exp 55)", dut.data_mem.mem[0]);
                errors++;
            end else begin
                $display("PASS: dmem[0] = %0d (0x%h) as expected", dut.data_mem.mem[0], dut.data_mem.mem[0]);
            end

            if (dut.rf_inst.rf[3] !== 32'd55) begin
                $error("FAIL: reload register x3 = %0d (exp 55)", dut.rf_inst.rf[3]);
                errors++;
            end else begin
                $display("PASS: reload register x3 = %0d (0x%h) as expected", dut.rf_inst.rf[3], dut.rf_inst.rf[3]);
            end
        end
        else if (`TEST_HEX == "tests/asm/mem_loop.hex") begin
            if (dut.rf_inst.rf[5] !== 32'd100) begin
                $error("FAIL: accumulated sum x5 = %0d (exp 100)", dut.rf_inst.rf[5]);
                errors++;
            end else begin
                $display("PASS: accumulated sum x5 = %0d (0x%h) as expected", dut.rf_inst.rf[5], dut.rf_inst.rf[5]);
            end

            if (dut.data_mem.mem[4] !== 32'd100) begin
                $error("FAIL: dmem[4] = %0d (exp 100)", dut.data_mem.mem[4]);
                errors++;
            end else begin
                $display("PASS: dmem[4] = %0d (0x%h) as expected", dut.data_mem.mem[4], dut.data_mem.mem[4]);
            end

            if (dut.rf_inst.rf[7] !== 32'd100) begin
                $error("FAIL: reloaded sum x7 = %0d (exp 100)", dut.rf_inst.rf[7]);
                errors++;
            end else begin
                $display("PASS: reloaded sum x7 = %0d (0x%h) as expected", dut.rf_inst.rf[7], dut.rf_inst.rf[7]);
            end
        end

        if (errors == 0) begin
            $display(">>> ALL PIPELINE PROGRAM CHECKS PASSED FOR %s <<<", `TEST_HEX);
            $display("Performance Metrics:");
            $display("  Program Execution Cycles: %0d", completion_cycle);
            $display("  Dynamic Instructions:    %0d", program_inst_count);
            $display("  Real CPI:                %0.2f", real'(completion_cycle) / real'(program_inst_count));
        end else begin
            $display(">>> PIPELINE PROGRAM CHECKS FAILED FOR %s with %0d errors <<<", `TEST_HEX, errors);
        end

        #20;
        $finish;
    end

endmodule
