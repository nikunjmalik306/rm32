# RM32 Technical Interview Guide — 25 RTL & Computer Architecture Questions

This document prepares the engineer for hardware design and verification technical interviews, grounded directly in the implementation of the RM32 processor.

---

### Q1: What pipeline hazards exist in a classic 5-stage RISC processor, and which ones are present in RM32?
**Answer:**
There are three classes of hazards:
1. **Structural Hazards:** Concurrent access to a shared resource. Avoided in RM32 by using Harvard architecture (split `imem` and `dmem`) and a dual-read/single-write register file.
2. **Data Hazards (RAW, WAR, WAW):** 
   - **RAW (Read-After-Write):** Solved in RM32 via EX/MEM and MEM/WB data forwarding to EX, and a 1-cycle stall for load-use hazards.
   - **WAR & WAW:** Do not occur in an in-order, 5-stage pipeline because instructions read operands in ID and write back in WB in strict program order.
3. **Control Hazards:** Caused by branches and jumps. Solved in RM32 by branch resolution in the EX stage, which flushes the two younger instructions in IF/ID and ID/EX on a taken branch (2-cycle penalty).

---

### Q2: How does data forwarding work in RM32?
**Answer:**
The forwarding unit in `pipelined/hazard_unit.sv` monitors the source register specifiers (`rs1_ex`, `rs2_ex`) against the destination registers of older in-flight instructions in EX/MEM (`rd_mem`) and MEM/WB (`rd_wb`). If a match occurs and the older instruction asserts `reg_write`, the ALU inputs are multiplexed from the pipeline register rather than the register file:
- `forward_a = 2'b10`: forwarded from `alu_result_mem` (EX/MEM).
- `forward_a = 2'b01`: forwarded from `result_wb` (MEM/WB).
- `forward_a = 2'b00`: no forwarding (register file output `data1_ex`).

---

### Q3: Why does EX/MEM forwarding take priority over MEM/WB forwarding?
**Answer:**
When back-to-back instructions write to the same register, the most recently executed instruction is in the EX/MEM stage, while the older instruction is in MEM/WB. The EX stage needs the newest architectural value. Checking `rd_mem` before `rd_wb` in the `if-else` priority ladder guarantees that the most recent write takes precedence.

---

### Q4: What is the `x0` forwarding corner case?
**Answer:**
In RISC-V, writes to `x0` are discarded and `x0` must always read zero. However, an instruction like `addi x0, x1, 5` computes a non-zero value that sits in `alu_result_ex` and `alu_result_mem`. If the forwarding unit checks only `(rd_mem == rs1_ex)` without checking `(rd_mem != 5'd0)`, a subsequent instruction reading `x0` would receive the temporary non-zero forwarded result. RM32 explicitly requires `(rd_mem != 5'd0)` and `(rd_wb != 5'd0)` on all forwarding paths.

---

### Q5: Why can't data forwarding eliminate the load-use hazard?
**Answer:**
A load instruction (`lw`) reads data from memory during the MEM stage. The read data is only available at the output of `dmem` at the end of the MEM clock cycle. An immediately following dependent instruction requires the operand at the beginning of the EX stage. Because data cannot travel backward in time, forwarding alone is physically impossible. RM32 stalls the pipeline for 1 clock cycle to allow the load to reach the MEM/WB boundary, where it is forwarded to EX.

---

### Q6: How is the load-use stall implemented in hardware?
**Answer:**
The hazard unit detects:
```systemverilog
wire load_use_hazard = (result_src_ex == 2'b01) && (rd_ex != 5'd0) &&
                       ((rd_ex == rs1_id) || (rd_ex == rs2_id));
```
When asserted:
1. `stall_pc = 1`: PC holds its current value.
2. `stall_if_id = 1`: IF/ID register holds the current instruction.
3. `flush_id_ex = 1`: ID/EX control registers are cleared to 0, inserting a NOP bubble into the EX stage.

---

### Q7: What is the branch penalty in RM32, and why?
**Answer:**
The branch penalty is **2 clock cycles**. RM32 resolves branches in the EX stage using the main ALU to evaluate the condition and calculate the branch target (`PC + immediate`). When a branch is taken, the two instructions fetched behind it (currently in IF/ID and ID/EX) are invalid and must be flushed by asserting `flush_if_id` and `flush_id_ex`.

---

### Q8: What are the trade-offs of moving branch resolution to the ID stage?
**Answer:**
- **Pros:** Reduces branch penalty from 2 cycles to 1 cycle, improving CPI on branch-heavy workloads.
- **Cons:** Requires a dedicated 32-bit adder in the ID stage (to calculate `PC + imm`) and an early comparator in ID. Additionally, it requires extra forwarding multiplexers in the ID stage from EX/MEM and MEM/WB, which lengthens the ID stage critical path and can reduce the overall processor clock frequency ($F_{\max}$).

---

### Q9: Why does `slt` require signed comparison, and how is it implemented?
**Answer:**
In RISC-V, `slt` (Set Less Than) treats register values as signed two's complement integers. Without signed comparison, `-5` (`0xFFFFFFFB`) would be interpreted as `4,294,967,291`, making `-5 < 5` false. RM32 implements signed comparison in `rtl/alu.sv` using:
```systemverilog
result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
```

---

### Q10: Why did RISC-V architects keep bit 31 as the sign bit across all formats?
**Answer:**
In the RISC-V ISA, bit 31 is invariant across I, S, B, and J instruction formats. This allows the sign-extension circuit in `rtl/signextn.sv` to replicate `instr[31]` directly without waiting for opcode decoding, minimizing the critical path delay of immediate generation.

---

### Q11: How does JAL work in RM32?
**Answer:**
`jal rd, offset` performs two simultaneous operations:
1. Computes the target address: `pc_target = pc + imm_j`, which updates the PC via `pc_src = 1`.
2. Computes the return address: `pc_plus_4 = pc + 4`, which routes through `result_src = 2'b10` to `rd` in the register file.

---

### Q12: How does LUI work in the datapath?
**Answer:**
`lui rd, imm` (Load Upper Immediate) takes a 20-bit immediate, shifts it left by 12 bits (`{instr[31:12], 12'b0}`), and writes it to `rd`. In RM32, `result_src = 2'b11` selects the immediate directly at the writeback multiplexer, writing it directly into the register file without consuming ALU cycles.

---

### Q13: Why is single-cycle CPI strictly 1.0, while pipelined CPI is greater than 1.0?
**Answer:**
In a single-cycle core, each instruction completes all phases in one long clock cycle, yielding an architectural $\text{CPI} = 1.0$. In a pipelined core, throughput is ideally 1 instruction per cycle, but data hazards (load-use stalls) and control hazards (branch flushes) introduce bubble cycles, causing real CPI to exceed 1.0 (e.g., 1.56 on `sum10`). However, because pipelining drastically reduces the clock period, total execution time ($T = N \times \text{CPI} \times T_{\text{clk}}$) is significantly lower on the pipeline.

---

### Q14: What were the measured CPI numbers on the test programs, and why?
**Answer:**
From real simulation logs:
- `sum10`: Single-cycle CPI = **1.00**; Pipelined CPI = **1.56** (56 cycles for 36 instructions). 9 taken branches in the loop incur 18 flush cycles ($9 \times 2$).
- `mem_loop`: Single-cycle CPI = **1.00**; Pipelined CPI = **1.45** (42 cycles for 29 instructions). Loop incurs 4 load-use stall cycles and 6 branch flush cycles ($3 \times 2$).

---

### Q15: How do you prove functional correctness without FPGA silicon?
**Answer:**
By establishing a multi-layered verification strategy:
1. **Self-checking unit testbenches** for every component (ALU, RF, SignExt, Controller, DMem).
2. **SystemVerilog Assertions (SVAs)** checking architectural invariants (e.g. `x0 == 0`, no simultaneous read/write conflict).
3. **Directed edge case tests** (signed/unsigned comparisons, x0 write suppression, backward branches).
4. **Golden Reference Model (Python ISS)** execution trace comparison matching architectural state after every single instruction.

---

### Q16: How does the Python Golden Model flow work?
**Answer:**
`tools/rv32i_iss.py` simulates the instruction semantics sequentially. During RTL simulation, `tests/integration/tb_programs.sv` dumps an execution trace (`PC`, `INSTR`, non-zero registers). `tools/run_trace_diff.py` parses both traces and verifies that the PC sequence, instruction stream, and register values match bit-for-bit across every instruction cycle.

---

### Q17: What are the trade-offs of synchronous vs asynchronous reset?
**Answer:**
- **Synchronous Reset:** Immune to glitches on reset lines, predictable static timing analysis (treated as normal data path), and maps directly to FPGA slice flip-flops. However, the reset clock must be toggling to take effect.
- **Asynchronous Reset:** Resets the chip immediately without a running clock, essential for low-power sleep modes or unclocked system power-up. However, deassertion must be synchronized to prevent metastability (reset recovery/removal violations).

---

### Q18: What SystemVerilog Assertions (SVAs) are embedded in RM32?
**Answer:**
In `rtl/datapath.sv`:
1. `assert (register.rf[0] == 32'd0)`: Invariant that `x0` is never corrupted.
2. `assert (!(reg_write && mem_write))`: Protocol check preventing simultaneous register writeback and memory write.
3. `assert (pc[1:0] == 2'b00)`: Word alignment invariant for instruction fetch.

---

### Q19: What happens on an unaligned memory access in RM32?
**Answer:**
In `rtl/dmem.sv`:
- An unaligned write (`address[1:0] != 2'b00`) is suppressed and memory state is preserved.
- An unaligned read returns `32'b0`.
This deterministic behavior guards against simulation corruption without requiring a full trap/exception handler.

---

### Q20: What is the critical path in the single-cycle core vs the 5-stage pipeline?
**Answer:**
- **Single-Cycle:** The critical path spans all stages in one cycle: `PC clk-to-q -> IMEM read -> RegFile read -> ALU operand mux -> ALU -> DMEM read -> Result mux -> RegFile setup time`.
- **Pipelined:** Broken into 5 balanced stages. The critical path is typically in the EX stage (`ALU forward mux -> ALU -> Zero flag logic`) or MEM stage (`DMEM address -> read data output`), allowing significantly higher clock frequency.

---

### Q21: What were the results of the Yosys generic synthesis check?
**Answer:**
Using Yosys 0.70+post generic synthesis:
- `alu`: 610 generic cells, critical path depth 64 gates.
- `controller`: 44 generic cells, critical path depth 6 gates.
- `hazard_unit`: 88 generic cells, critical path depth 8 gates.
- `reg_file`: 4,585 generic cells (including 992 flip-flops and dual 32:1 read muxes).
- Single-cycle core top: 94 cells (driving observable ports).
- 5-stage pipelined core top: 202 cells (with pipeline registers and hazard unit).

---

### Q22: What instructions from the full RV32I base ISA are omitted from this core?
**Answer:**
The implemented subset includes 15 instructions (`lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui`).
Omitted instructions:
- Shifts: `sll, srl, sra, slli, srli, srai`
- Unsigned arithmetic/compare: `sltu, sltiu`
- XOR operations: `xor, xori`
- Remaining branches: `blt, bge, bltu, bgeu`
- Sub-word memory accesses: `lb, lh, lbu, lhu, sb, sh`
- Indirect jump: `jalr`
- Upper immediate addition: `auipc`
- System/environment: `ecall, ebreak, fence, csrrw, csrrs, csrrc`.

---

### Q23: How would you add `jalr` to the pipelined core?
**Answer:**
`jalr rd, offset(rs1)` computes its target as `(rs1 + imm) & ~1`.
1. Decode in controller (`op = 7'b1100111`, I-type).
2. In EX stage, ALU computes `a + immediate`.
3. Clear bit 0 of the result: `pc_target = {alu_result[31:1], 1'b0}`.
4. Set `pc_src = 1` and write `pc + 4` into `rd` via `result_src = 2'b10`.

---

### Q24: How would you add support for exceptions (e.g. illegal instruction, misaligned access)?
**Answer:**
1. Add an exception detection signal in each pipeline stage (e.g. `illegal_inst` in ID, `misaligned_pc` in IF, `misaligned_mem` in MEM).
2. Carry the exception flag and cause code along the pipeline registers to the WB stage.
3. In WB stage, if an exception flag is set, suppress register/memory writes, save the offending PC in `mepc` CSR, save the cause in `mcause`, and redirect the PC to `mtvec` (trap handler address).

---

### Q25: How would you add dynamic branch prediction to reduce the branch penalty?
**Answer:**
1. Place a **Branch Target Buffer (BTB)** and a **2-bit saturating counter Branch History Table (BHT)** in the IF stage.
2. When fetching an instruction whose PC hits the BTB and is predicted taken, redirect the PC to the predicted target in the next cycle (0-cycle penalty if correct).
3. In the EX stage, when the branch condition is resolved:
   - If the prediction was correct, do nothing.
   - If mispredicted, assert `flush_if_id` and `flush_id_ex`, redirect PC to the alternate target, and update the 2-bit counter in the BHT.
