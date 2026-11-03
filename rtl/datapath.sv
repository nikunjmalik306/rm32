module datapath (
    input logic clk,
    input logic reset_n
);
    //PROGRAM COUNTER
    logic [31:0]pc,pc_next; //PC is the current instruction PC next will be loaded next
    always @(posedge clk) begin
        if (reset_n) begin
            pc <= 0;
        end
        else begin
            pc <= pc_next;
        end
    end
    assign pc_next = pc + 32'b100;
    
    
   //INSTRUCTION MEMORY
   logic [31:0] instruction;
   memory#(.mem_init("imemory.hex")) instr_mem (clk, pc, 32'b0, 1'b0 , reset_n,instruction);
   
   //ControlPath
   
    logic [6:0] op;
    assign op = instruction[6:0];       //opcode extraction
    logic [2:0] f3;
    assign f3 = instruction[14:12];     //f3 extractiom
    wire alu_zero;
    
    wire [2:0] alu_ctrl;
    wire [1:0] imm_src;
    wire mem_write;
    wire reg_write;
    
    
    contoller  control(op, f3, 7'b0, alu_zero, reg_write, mem_write, alu_ctrl, imm_src);
   
   //REGISTER FILE
   
   logic [4:0]source1;
   assign source1 =instruction[19:15];
   logic [4:0]source2;
   assign source2 = instruction[24:20];
   logic [4:0]load_address;
   assign load_address = instruction[11:7];
   logic [31:0]load_data;
   logic [31:0] data1;
   logic [31:0] data2;
   
    always_comb begin
        load_data = dmem_data;
    end
   
   reg_file register(source1,source2,load_address,load_data,reg_write,reset_n,clk,data1,data2);
   
   //SIGN EXTEND
   
   logic [24:0]instr;
   assign instr = instruction[31:7];
   wire [31:0] immediate;
   signextn extn(instr,imm_src,immediate);
   
   //ALU
   
   wire [31:0]alu_result;
   logic [31:0]data_input2;
   always_comb begin 
        data_input2 = immediate;
   end
   
   alu alu1(alu_ctrl,data1,data_input2,alu_result,alu_zero);     
           
   // DATA MEMORY
   logic [31:0]addr;
   logic [31:0]write_data;
   logic [31:0]dmem_data;
   
   assign write_data = data2;
   assign addr = alu_result; 
    memory #(.mem_init("dmem.hex")) data_memory(
    clk,
    addr,
    write_data,        
    mem_write,           //Control signal
    reset_n,
    dmem_data 
    );
   
   
   
   
endmodule