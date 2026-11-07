`timescale 1ns/1ps
module tb_random_pipe;
  logic clk=0, reset=1;
  wire [31:0] cyc, ret;
  always #5 clk=~clk;
  pipe_datapath #(.IMEM_WORDS(128),.IMEM_INIT(""),.DMEM_WORDS(128),.DMEM_INIT("")) dut(.clk(clk),.reset(reset),.cycles_count(cyc),.retired_inst_count(ret));
  string f;
  initial begin
    #1; if(!$value$plusargs("hex=%s", f)) $fatal(1,"no hex");
    $readmemh(f, dut.instr_mem.mem);
    repeat(2) @(posedge clk); #1 reset=0;
    repeat(500) @(posedge clk); #1;
    for(int i=0;i<32;i++) $display("R %0d %08x", i, dut.rf_inst.rf[i]);
    for(int i=0;i<128;i++) $display("M %0d %08x", i, dut.data_mem.mem[i]);
    $finish;
  end
endmodule
