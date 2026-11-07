`timescale 1ns/1ps
module tb_random_single;
  logic clk=0, reset=1;
  always #5 clk=~clk;
  datapath #(.IMEM_WORDS(128),.IMEM_INIT(""),.DMEM_WORDS(128),.DMEM_INIT("")) dut(.clk(clk),.reset(reset));
  string f;
  initial begin
    #1; if(!$value$plusargs("hex=%s", f)) $fatal(1,"no hex");
    $readmemh(f, dut.instr_mem.mem);
    repeat(2) @(posedge clk); #1 reset=0;
    repeat(500) @(posedge clk); #1;
    for(int i=0;i<32;i++) $display("R %0d %08x", i, dut.register.rf[i]);
    for(int i=0;i<128;i++) $display("M %0d %08x", i, dut.data_memory.mem[i]);
    $finish;
  end
endmodule
