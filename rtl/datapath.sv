`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: RM32 Datapath Top-Level
// Module Name: datapath
// Description:
// Single-cycle RV32I subset processor datapath supporting 15 instructions:
// lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui.
//
// Key Microarchitectural Features:
// - Harvard architecture with split instruction (imem) and data (dmem) memories.
// - Word-aligned memory addressing (address[1:0] == 2'b00).
// - Register x0 hardwired to zero.
// - Embedded SystemVerilog Assertions (SVA) for active-rule checking.
//////////////////////////////////////////////////////////////////////////////////

module datapath #(
    parameter int IMEM_WORDS = 128,
    parameter     IMEM_INIT  = "rtl/imemory.hex",
    parameter int DMEM_WORDS = 128,
    parameter     DMEM_INIT  = "rtl/dmem.hex"
)(
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] pc_out,
    output logic [31:0] alu_result_out,
    output logic [31:0] write_data_out,
    output logic        mem_write_out
);

    // =========================================================================
    // 1. PROGRAM COUNTER & NEXT-PC LOGIC
    // =========================================================================
    logic [31:0] pc;
    logic [31:0] pc_next;
    wire  [31:0] pc_plus_4;
    wire  [31:0] pc_target;
    wire         pc_src;

    assign pc_plus_4 = pc + 32'd4;

    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= 32'd0;
        end else begin
            pc <= pc_next;
        end
    end

    // =========================================================================
    // 2. INSTRUCTION MEMORY (Combinational read, word-aligned)
    // =========================================================================
    logic [31:0] instruction;

    imem #(
        .words(IMEM_WORDS),
        .mem_init(IMEM_INIT)
    ) instr_mem (
        .address(pc),
        .instruction(instruction)
    );

    // Instruction field breakdown
    wire [6:0] op  = instruction[6:0];
    wire [2:0] f3  = instruction[14:12];
    wire [6:0] f7  = instruction[31:25];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [4:0] rd  = instruction[11:7];

    // =========================================================================
    // 3. CONTROL UNIT
    // =========================================================================
    wire       reg_write;
    wire       mem_write;
    wire       alu_src;
    wire [1:0] result_src;
    wire [2:0] imm_src;
    wire [2:0] alu_ctrl;
    wire       alu_zero;

    controller control (
        .op_code   (op),
        .func3     (f3),
        .func7     (f7),
        .alu_zero  (alu_zero),
        .reg_write (reg_write),
        .mem_write (mem_write),
        .alu_src   (alu_src),
        .result_src(result_src),
        .imm_src   (imm_src),
        .alu_ctrl  (alu_ctrl),
        .pc_src    (pc_src)
    );

    // =========================================================================
    // 4. REGISTER FILE (Dual read, single write, x0 hardwired to 0)
    // =========================================================================
    logic [31:0] load_data;
    logic [31:0] data1;
    logic [31:0] data2;

    reg_file register (
        .address1   (rs1),
        .address2   (rs2),
        .address3   (rd),
        .write_data (load_data),
        .write_en   (reg_write),
        .reset      (reset),
        .clk        (clk),
        .data1      (data1),
        .data2      (data2)
    );

    // =========================================================================
    // 5. IMMEDIATE GENERATOR / SIGN EXTENDER
    // =========================================================================
    wire [31:0] immediate;

    signextn extn (
        .instr      (instruction),
        .imm_source (imm_src),
        .immediate  (immediate)
    );

    // Branch and Jump Target calculation (PC + immediate offset)
    assign pc_target = pc + immediate;
    assign pc_next   = pc_src ? pc_target : pc_plus_4;

    // =========================================================================
    // 6. ARITHMETIC LOGIC UNIT (ALU)
    // =========================================================================
    wire [31:0] alu_input_b = alu_src ? immediate : data2;
    wire [31:0] alu_result;

    alu alu1 (
        .alu_ctrl (alu_ctrl),
        .a        (data1),
        .b        (alu_input_b),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // =========================================================================
    // 7. DATA MEMORY (Synchronous write, combinational read)
    // =========================================================================
    logic [31:0] dmem_data;

    dmem #(
        .words(DMEM_WORDS),
        .mem_init(DMEM_INIT)
    ) data_memory (
        .clk        (clk),
        .reset      (reset),
        .address    (alu_result),
        .write_data (data2),
        .mem_write  (mem_write),
        .read_data  (dmem_data)
    );

    // =========================================================================
    // 8. RESULT WRITEBACK MULTIPLEXER
    // =========================================================================
    always_comb begin
        case (result_src)
            2'b00:   load_data = alu_result;  // R-type, I-type ALU
            2'b01:   load_data = dmem_data;   // LW
            2'b10:   load_data = pc_plus_4;   // JAL return address
            2'b11:   load_data = immediate;   // LUI
            default: load_data = alu_result;
        endcase
    end

    // Output signal assignments for top-level observability & synthesis
    assign pc_out         = pc;
    assign alu_result_out = alu_result;
    assign write_data_out = data2;
    assign mem_write_out  = mem_write;

    // =========================================================================
    // 9. SYSTEMVERILOG ASSERTIONS (Active invariant verification)
    // =========================================================================
`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (!reset) begin
            // Invariant 1: Register x0 must always remain zero
            assert (register.rf[0] == 32'd0)
                else $error("[SVA FAIL] Architectural violation: x0 != 0 (x0 = %h)", register.rf[0]);

            // Invariant 2: Simultaneous reg_write and mem_write cannot occur in RV32I subset
            assert (!(reg_write && mem_write))
                else $error("[SVA FAIL] Protocol violation: simultaneous reg_write and mem_write!");

            // Invariant 3: Instruction PC must be 4-byte word aligned
            assert (pc[1:0] == 2'b00)
                else $error("[SVA FAIL] Alignment violation: PC misaligned (pc = %h)", pc);
        end
    end
`endif

endmodule
