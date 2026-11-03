module reg_file (
    input logic [4:0]address1,address2,address3,
    input logic [31:0]write_data,
    input logic write_en,
    input logic reset_n,
    input logic clk,
    output logic [31:0]data1,
    output logic [31:0]data2
    );
    reg [31:0] register [31:0];
    always @(posedge clk) begin
        if(reset_n == 1'b1) begin
            for(int i = 0; i<32; i++) begin
                register[i] <= 32'b0;
            end
        end 
        else if(write_en == 1'b1 && address3 != 0) begin
            register[address3] <= write_data;
        end
    end
always_comb begin
    data1 = register[address1];
    data2 = register[address2];
end
 endmodule