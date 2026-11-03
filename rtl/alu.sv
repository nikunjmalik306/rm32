
module alu (
    input logic [2:0] alu_ctrl,
    input logic [31:0]a,b,
    output logic [31:0]result,
    output logic zero
    );
    
    always_comb begin
        case(alu_ctrl)
            3'b010 : result = a + b;
            default : result = 0;
        endcase   
    end
    assign zero = (result == 32'b0);
    
endmodule
    