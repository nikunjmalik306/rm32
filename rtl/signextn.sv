`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.08.2026 15:58:26
// Design Name: 
// Module Name: signextn
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module signextn(
    input logic [24:0]instr,
    input logic [1:0]imm_source,
    output logic [31:0] immediate
    );
    logic [11:0]gathered_imm;
    always_comb begin
        case(imm_source) 
            2'b00 : gathered_imm = {instr[24:13]};
            2'b01 : gathered_imm = {instr[24:18],instr[4:0]};
            default: gathered_imm = {12{1'b0}};
         endcase
    end
    assign immediate = {{20{gathered_imm[11]}}, gathered_imm};
endmodule
