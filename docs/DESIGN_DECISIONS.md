# RM32 Design Decisions & Architecture Trade-offs

This document details the architectural and engineering rationale behind every major design decision in the RM32 single-cycle and 5-stage pipelined processor implementations.

---

## 1. Reset Strategy & Polarity
- **Decision:** Active-high synchronous reset (`reset`).
- **Rationale:** 
  - The legacy codebase had an active-low port name (`reset_n`) but implemented active-high logic (`if (reset_n)`). Renaming to `reset` eliminated this naming-polarity discrepancy.
  - Synchronous reset was chosen because modern FPGA architectures (e.g., AMD Xilinx UltraScale / 7-series) map synchronous resets directly to dedicated control sets in slice flip-flops without consuming extra logic routing resources.
  - In simulation and formal verification, synchronous resets prevent glitches on asynchronous reset lines from corrupting state machines.

---

## 2. Hardwired Zero Register (`x0`) Architecture
- **Decision:** Guarded writes (`if (write_en && address3 != 5'd0) rf[address3] <= write_data;`) combined with forced combinational zero on read (`assign data1 = (address1 == 5'd0) ? 32'd0 : ...`).
- **Rationale:**
  - The RISC-V ISA specification mandates that register `x0` is hardwired to 0.
  - Relying solely on write suppression is insufficient during simulation initialization: uninitialized flip-flops could power up as `X` or non-zero. Forcing `data = 0` whenever `address == 0` guarantees `x0` reads zero under all operating conditions and reset states.

---

## 3. Signed vs Unsigned Comparisons in SLT / SLTI
- **Decision:** Two's complement signed cast using `$signed(a) < $signed(b)`.
- **Rationale:**
  - In RV32I, `slt` (Set Less Than) and `slti` perform signed integer comparisons, whereas `sltu` / `sltiu` perform unsigned comparisons.
  - Without the signed cast, negative numbers (MSB=1, e.g., `-5 = 0xFFFFFFFB`) would be evaluated as large positive unsigned numbers (`4,294,967,291`), causing `-5 < 5` to falsely evaluate to `0`. With `$signed()`, two's complement sign extension is respected, correctly evaluating `-5 < 5` as `1`.

---

## 4. Immediate Generation & Bit-Field Slicing
- **Decision:** Passing the full 32-bit `instruction` into `signextn` with a 3-bit `imm_source` selector, rather than slicing `[31:7]` in the parent module.
- **Rationale:**
  - Slicing `[31:7]` before passing to the immediate generator shifts all standard RISC-V bit indexes by 7, making code verification against the RISC-V ISA spec error-prone.
  - RISC-V specifically designs instruction formats so that bit 31 is *always* the sign bit across I, S, B, and J formats. Passing the full 32-bit instruction makes the sign-extension replication `{{20{instr[31]}}, ...}` self-documenting.

---

## 5. Harvard Memory Architecture (Separate I-Mem and D-Mem)
- **Decision:** Dedicated instruction memory (`imem`) and data memory (`dmem`).
- **Rationale:**
  - Single-cycle execution requires fetching an instruction and accessing data memory (for `lw`/`sw`) in the exact same clock cycle. A shared single-port Von Neumann memory would cause a structural hazard, making single-cycle execution physically impossible.
  - In the 5-stage pipeline, split memories permit simultaneous IF stage fetch and MEM stage load/store without pipeline stalling.

---

## 6. Word-Aligned Memory Addressing & Boundary Rules
- **Decision:** Addressing enforces `address[1:0] == 2'b00`. Unaligned writes are ignored; unaligned reads return `32'b0`. Out-of-bounds addresses do not corrupt memory.
- **Rationale:**
  - The RV32I subset implemented here supports only 32-bit word operations (`lw`/`sw`), not halfword or byte operations (`lh`, `lb`, `sh`, `sb`).
  - Gracefully ignoring unaligned and out-of-bounds accesses prevents simulation segmentation faults, prevents testbench lockups, and provides deterministic behavior without complex exception handling hardware.

---

## 7. 5-Stage Pipeline Hazard Resolution & Forwarding Priority
- **Decision:** EX/MEM forwarding takes precedence over MEM/WB forwarding.
- **Rationale:**
  - Consider back-to-back instructions writing to the same register:
    ```assembly
    addi x1, x0, 10   # in MEM stage (rd=x1)
    addi x1, x0, 20   # in EX stage  (rd=x1)
    add  x2, x1, x0   # in ID stage: needs x1
    ```
  - When `add` enters EX, `x1=20` is in EX/MEM, and `x1=10` is in MEM/WB. The most recent architectural value is `20` from EX/MEM. Therefore, EX/MEM forwarding must strictly override MEM/WB forwarding.

---

## 8. Corner Case: Suppressing Forwarding from `x0`
- **Decision:** Explicit condition `(rd_mem != 5'd0)` and `(rd_wb != 5'd0)` in the forwarding unit.
- **Rationale:**
  - Instructions writing to `x0` (e.g. `addi x0, x1, 5`) produce a non-zero intermediate ALU result in EX/MEM.
  - If the forwarding unit only checked `(rd_mem == rs1_ex)`, it would forward this temporary result to any subsequent instruction reading `x0`, violating the architectural invariant that `x0 == 0`.

---

## 9. Branch Resolution in EX Stage (2-Cycle Penalty)
- **Decision:** Branch condition evaluated in the EX stage using the ALU comparator, rather than adding an early branch comparator in ID.
- **Rationale:**
  - Evaluating branches in ID requires an extra dedicated 32-bit adder (for branch target) AND an extra 32-bit equality/comparison unit in the ID stage, plus forwarding paths from EX and MEM directly into ID.
  - Evaluating branches in EX reuses the existing ALU, eliminates extra comparators, and simplifies the forwarding network, at the cost of 2 penalty cycles on taken branches (flushing IF/ID and ID/EX). For an educational and portfolio design, this is the cleanest, most standard Harris & Harris style microarchitecture.

---

## 10. Load-Use Hazard Stall
- **Decision:** 1-cycle hardware stall: PC and IF/ID are frozen; a bubble (NOP) is flushed into ID/EX.
- **Rationale:**
  - Data from a `lw` instruction is only valid at the end of the MEM stage. An instruction immediately following `lw` that depends on that loaded data needs it at the start of the EX stage.
  - Backward data flow in time is physically impossible; therefore, forwarding alone cannot resolve a load-use RAW hazard. A 1-cycle hardware stall is mandatory.

---

## 11. Python Golden Model (ISS) & Trace-Diff Verification
- **Decision:** An independent Python Instruction Set Simulator (ISS) serves as the golden reference model.
- **Rationale:**
  - Self-checking testbenches verify specific assertions, but cannot mathematically prove that intermediate register states during multi-cycle programs are compliant with the RISC-V specification.
  - The Python ISS implements the architectural semantics independently of RTL hardware timing. Comparing the register file state after every instruction (`tools/run_trace_diff.py`) provides 100% confidence in microarchitectural compliance.
