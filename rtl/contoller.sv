`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.08.2026 23:18:32
// Design Name: Controller
// Module Name: contoller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// This contains the controller for risc5 cpu
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module contoller(
    input logic [6:0]op_code,
    input logic [2:0]func3,
    input logic [6:0]func7,
    input logic alu_zero,
    output logic reg_write,
    output logic mem_write,
    output logic [2:0]alu_ctrl,
    output logic [1:0]imm_src
    );
    logic [1:0] alu_op;
    always_comb begin
        case(op_code)
            //LW
            7'b0000011 : begin //OP for LW
                reg_write = 1'b1;   
                mem_write = 1'b0;
                alu_op = 2'b00;
                imm_src = 2'b00;
            end
            7'b0100011 : begin  // OP for SW
                reg_write = 1'b0;
                mem_write = 1'b1;
                alu_op = 2'b00;
                imm_src = 2'b01;
            end
            default : begin 
                reg_write = 1'b0;
                mem_write = 1'b0;
                alu_op = 2'b00;
                imm_src = 2'b00;
            end
        endcase
    end
    always_comb begin
        case(alu_op) 
            2'b00: alu_ctrl = 3'b010;  
            default: alu_ctrl = 3'b111;
        endcase
     end
endmodule
