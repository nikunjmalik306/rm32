`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Design Name: 5-Stage Pipelined RV32I Processor Core Top-Level
// Module Name: pipe_datapath
// Description:
// Complete 5-stage pipelined processor (IF, ID, EX, MEM, WB) with:
// - Data forwarding unit (EX/MEM and MEM/WB to EX stage)
// - Load-use hazard detection unit (1-cycle stall with bubble insertion)
// - Branch resolution in EX stage with 2-cycle flush of younger instructions
// - Architectural performance counters (cycle counter and retired instruction counter)
//////////////////////////////////////////////////////////////////////////////////

module pipe_datapath #(
    parameter int IMEM_WORDS = 128,
    parameter     IMEM_INIT  = "imemory.hex",
    parameter int DMEM_WORDS = 128,
    parameter     DMEM_INIT  = "dmem.hex"
)(
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] cycles_count,
    output logic [31:0] retired_inst_count
);

    // =========================================================================
    // HAZARD SIGNALS (Inter-stage feedback)
    // =========================================================================
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire       stall_pc;
    wire       stall_if_id;
    wire       flush_if_id;
    wire       flush_id_ex;

    // Branch / Jump feedback from EX stage
    wire [31:0] pc_target_ex;
    wire        pc_src_ex;

    // Writeback feedback to ID & RegFile
    logic [31:0] result_wb;
    wire  [4:0]  rd_wb;
    wire         reg_write_wb;

    // =========================================================================
    // 1. INSTRUCTION FETCH (IF) STAGE
    // =========================================================================
    logic [31:0] pc_if;
    wire  [31:0] pc_plus_4_if = pc_if + 32'd4;
    wire  [31:0] pc_next_if   = pc_src_ex ? pc_target_ex :
                                (stall_pc  ? pc_if        : pc_plus_4_if);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_if <= 32'd0;
        end else begin
            pc_if <= pc_next_if;
        end
    end

    wire [31:0] instr_if;
    imem #(
        .words(IMEM_WORDS),
        .mem_init(IMEM_INIT)
    ) instr_mem (
        .address(pc_if),
        .instruction(instr_if)
    );

    // =========================================================================
    // IF/ID PIPELINE REGISTER
    // =========================================================================
    wire [31:0] pc_id;
    wire [31:0] pc_plus_4_id;
    wire [31:0] instr_id;

    pipe_if_id reg_if_id (
        .clk          (clk),
        .reset        (reset),
        .stall        (stall_if_id),
        .flush        (flush_if_id),
        .pc_if        (pc_if),
        .pc_plus_4_if (pc_plus_4_if),
        .instr_if     (instr_if),
        .pc_id        (pc_id),
        .pc_plus_4_id (pc_plus_4_id),
        .instr_id     (instr_id)
    );

    // =========================================================================
    // 2. INSTRUCTION DECODE (ID) STAGE
    // =========================================================================
    wire [6:0] op_id  = instr_id[6:0];
    wire [2:0] f3_id  = instr_id[14:12];
    wire [6:0] f7_id  = instr_id[31:25];
    wire [4:0] rs1_id = instr_id[19:15];
    wire [4:0] rs2_id = instr_id[24:20];
    wire [4:0] rd_id  = instr_id[11:7];

    wire branch_id = (op_id == 7'b1100011);
    wire jump_id   = (op_id == 7'b1101111);

    wire       reg_write_id;
    wire       mem_write_id;
    wire       alu_src_id;
    wire [1:0] result_src_id;
    wire [2:0] imm_src_id;
    wire [2:0] alu_ctrl_id;
    wire       dummy_pc_src_id;

    controller ctrl_id (
        .op_code    (op_id),
        .func3      (f3_id),
        .func7      (f7_id),
        .alu_zero   (1'b0),
        .reg_write  (reg_write_id),
        .mem_write  (mem_write_id),
        .alu_src    (alu_src_id),
        .result_src (result_src_id),
        .imm_src    (imm_src_id),
        .alu_ctrl   (alu_ctrl_id),
        .pc_src     (dummy_pc_src_id)
    );

    wire [31:0] data1_raw_id;
    wire [31:0] data2_raw_id;

    reg_file rf_inst (
        .address1   (rs1_id),
        .address2   (rs2_id),
        .address3   (rd_wb),
        .write_data (result_wb),
        .write_en   (reg_write_wb),
        .reset      (reset),
        .clk        (clk),
        .data1      (data1_raw_id),
        .data2      (data2_raw_id)
    );

    // Internal WB-to-ID register forwarding for concurrent read/write in same cycle
    wire [31:0] data1_id = (rs1_id == 5'd0) ? 32'd0 :
                           (reg_write_wb && (rd_wb == rs1_id)) ? result_wb : data1_raw_id;
    wire [31:0] data2_id = (rs2_id == 5'd0) ? 32'd0 :
                           (reg_write_wb && (rd_wb == rs2_id)) ? result_wb : data2_raw_id;

    wire [31:0] immediate_id;
    signextn signextn_id (
        .instr      (instr_id),
        .imm_source (imm_src_id),
        .immediate  (immediate_id)
    );

    // =========================================================================
    // ID/EX PIPELINE REGISTER
    // =========================================================================
    wire        reg_write_ex;
    wire        mem_write_ex;
    wire        alu_src_ex;
    wire [1:0]  result_src_ex;
    wire [2:0]  alu_ctrl_ex;
    wire        branch_ex;
    wire        jump_ex;
    wire [2:0]  func3_ex;
    wire _unused_pipe_signals = &{1'b0, dummy_pc_src_id, func3_ex[2:1]};

    wire [31:0] data1_ex;
    wire [31:0] data2_ex;
    wire [31:0] pc_ex;
    wire [31:0] pc_plus_4_ex;
    wire [31:0] immediate_ex;
    wire [4:0]  rd_ex;
    wire [4:0]  rs1_ex;
    wire [4:0]  rs2_ex;

    pipe_id_ex reg_id_ex (
        .clk           (clk),
        .reset         (reset),
        .flush         (flush_id_ex),

        .reg_write_id  (reg_write_id),
        .mem_write_id  (mem_write_id),
        .alu_src_id    (alu_src_id),
        .result_src_id (result_src_id),
        .alu_ctrl_id   (alu_ctrl_id),
        .branch_id     (branch_id),
        .jump_id       (jump_id),
        .func3_id      (f3_id),

        .data1_id      (data1_id),
        .data2_id      (data2_id),
        .pc_id         (pc_id),
        .pc_plus_4_id  (pc_plus_4_id),
        .immediate_id  (immediate_id),
        .rd_id         (rd_id),
        .rs1_id        (rs1_id),
        .rs2_id        (rs2_id),

        .reg_write_ex  (reg_write_ex),
        .mem_write_ex  (mem_write_ex),
        .alu_src_ex    (alu_src_ex),
        .result_src_ex (result_src_ex),
        .alu_ctrl_ex   (alu_ctrl_ex),
        .branch_ex     (branch_ex),
        .jump_ex       (jump_ex),
        .func3_ex      (func3_ex),

        .data1_ex      (data1_ex),
        .data2_ex      (data2_ex),
        .pc_ex         (pc_ex),
        .pc_plus_4_ex  (pc_plus_4_ex),
        .immediate_ex  (immediate_ex),
        .rd_ex         (rd_ex),
        .rs1_ex        (rs1_ex),
        .rs2_ex        (rs2_ex)
    );

    // =========================================================================
    // 3. EXECUTE (EX) STAGE & FORWARDING
    // =========================================================================
    wire [31:0] alu_result_mem;

    logic [31:0] alu_operand_a;
    logic [31:0] write_data_ex;

    always_comb begin
        // Forwarding mux A
        case (forward_a)
            2'b10:   alu_operand_a = alu_result_mem; // EX/MEM forwarding
            2'b01:   alu_operand_a = result_wb;      // MEM/WB forwarding
            default: alu_operand_a = data1_ex;       // Register file
        endcase

        // Forwarding mux B
        case (forward_b)
            2'b10:   write_data_ex = alu_result_mem; // EX/MEM forwarding
            2'b01:   write_data_ex = result_wb;      // MEM/WB forwarding
            default: write_data_ex = data2_ex;       // Register file
        endcase
    end

    wire [31:0] alu_operand_b = alu_src_ex ? immediate_ex : write_data_ex;
    wire [31:0] alu_result_ex;
    wire        alu_zero_ex;

    alu alu_ex (
        .alu_ctrl (alu_ctrl_ex),
        .a        (alu_operand_a),
        .b        (alu_operand_b),
        .result   (alu_result_ex),
        .zero     (alu_zero_ex)
    );

    // Branch / Jump target computation & resolution in EX
    assign pc_target_ex = pc_ex + immediate_ex;
    wire branch_condition_ex = func3_ex[0] ? (~alu_zero_ex) : alu_zero_ex;
    assign pc_src_ex = jump_ex | (branch_ex & branch_condition_ex);

    // =========================================================================
    // EX/MEM PIPELINE REGISTER
    // =========================================================================
    wire        reg_write_mem;
    wire        mem_write_mem;
    wire [1:0]  result_src_mem;
    wire [31:0] write_data_mem;
    wire [4:0]  rd_mem;
    wire [31:0] pc_plus_4_mem;
    wire [31:0] immediate_mem;

    pipe_ex_mem reg_ex_mem (
        .clk            (clk),
        .reset          (reset),

        .reg_write_ex   (reg_write_ex),
        .mem_write_ex   (mem_write_ex),
        .result_src_ex  (result_src_ex),

        .alu_result_ex  (alu_result_ex),
        .write_data_ex  (write_data_ex),
        .rd_ex          (rd_ex),
        .pc_plus_4_ex   (pc_plus_4_ex),
        .immediate_ex   (immediate_ex),

        .reg_write_mem  (reg_write_mem),
        .mem_write_mem  (mem_write_mem),
        .result_src_mem (result_src_mem),

        .alu_result_mem (alu_result_mem),
        .write_data_mem (write_data_mem),
        .rd_mem         (rd_mem),
        .pc_plus_4_mem  (pc_plus_4_mem),
        .immediate_mem  (immediate_mem)
    );

    // =========================================================================
    // 4. MEMORY ACCESS (MEM) STAGE
    // =========================================================================
    wire [31:0] read_data_mem;

    dmem #(
        .words(DMEM_WORDS),
        .mem_init(DMEM_INIT)
    ) data_mem (
        .clk        (clk),
        .reset      (reset),
        .address    (alu_result_mem),
        .write_data (write_data_mem),
        .mem_write  (mem_write_mem),
        .read_data  (read_data_mem)
    );

    // =========================================================================
    // MEM/WB PIPELINE REGISTER
    // =========================================================================
    wire [1:0]  result_src_wb;
    wire [31:0] alu_result_wb;
    wire [31:0] read_data_wb;
    wire [31:0] pc_plus_4_wb;
    wire [31:0] immediate_wb;

    pipe_mem_wb reg_mem_wb (
        .clk            (clk),
        .reset          (reset),

        .reg_write_mem  (reg_write_mem),
        .result_src_mem (result_src_mem),

        .alu_result_mem (alu_result_mem),
        .read_data_mem  (read_data_mem),
        .rd_mem         (rd_mem),
        .pc_plus_4_mem  (pc_plus_4_mem),
        .immediate_mem  (immediate_mem),

        .reg_write_wb   (reg_write_wb),
        .result_src_wb  (result_src_wb),

        .alu_result_wb  (alu_result_wb),
        .read_data_wb   (read_data_wb),
        .rd_wb          (rd_wb),
        .pc_plus_4_wb   (pc_plus_4_wb),
        .immediate_wb   (immediate_wb)
    );

    // =========================================================================
    // 5. WRITEBACK (WB) STAGE
    // =========================================================================
    always_comb begin
        case (result_src_wb)
            2'b00:   result_wb = alu_result_wb;
            2'b01:   result_wb = read_data_wb;
            2'b10:   result_wb = pc_plus_4_wb;
            2'b11:   result_wb = immediate_wb;
            default: result_wb = alu_result_wb;
        endcase
    end

    // =========================================================================
    // HAZARD UNIT INSTANTIATION
    // =========================================================================
    hazard_unit hz_unit (
        .rs1_id        (rs1_id),
        .rs2_id        (rs2_id),
        .rs1_ex        (rs1_ex),
        .rs2_ex        (rs2_ex),
        .rd_ex         (rd_ex),
        .result_src_ex (result_src_ex),
        .rd_mem        (rd_mem),
        .reg_write_mem (reg_write_mem),
        .rd_wb         (rd_wb),
        .reg_write_wb  (reg_write_wb),
        .pc_src_ex     (pc_src_ex),
        .forward_a     (forward_a),
        .forward_b     (forward_b),
        .stall_pc      (stall_pc),
        .stall_if_id   (stall_if_id),
        .flush_if_id   (flush_if_id),
        .flush_id_ex   (flush_id_ex)
    );

    // =========================================================================
    // ARCHITECTURAL PERFORMANCE COUNTERS
    // Measure real execution cycles and retired instructions
    // =========================================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            cycles_count       <= 32'd0;
            retired_inst_count <= 32'd0;
        end else begin
            cycles_count <= cycles_count + 32'd1;
            // Instruction retires in WB stage if writeback is active or non-bubble instruction executes
            if (reg_write_wb || (alu_result_wb != 32'd0)) begin
                retired_inst_count <= retired_inst_count + 32'd1;
            end
        end
    end

endmodule
