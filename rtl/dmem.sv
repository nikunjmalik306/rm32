module memory #( parameter words = 64, parameter mem_init = "")(
    input logic clk,
    input logic [31:0]address,
    input logic [31:0]write_data,
    input logic write_en,           //Control signal
    input logic reset_n,
    output logic [31:0]read_data 
    );
    int i;
    reg [31:0] mem [0:words-1];
    initial begin
        if (mem_init != "")
        $readmemh(mem_init, mem);
    end 
    always @(posedge clk) begin
        if (write_en == 1) begin
            if(address[1:0] == 2'b00) begin
                mem[address[31:2]] <= write_data;
            end
        end
     end
     always_comb begin
        read_data = mem[address[31:2]];
     end            
             
 endmodule
    