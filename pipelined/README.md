# RM32 5-Stage Pipelined RV32I Processor Core

This directory contains the complete **5-stage pipelined RV32I processor core** (`IF → ID → EX → MEM → WB`) implemented in synthesizable SystemVerilog (`IEEE 1800-2012/2017`). It executes the same 15-instruction RV32I subset as the single-cycle core in [`../rtl/`](../rtl/), reuses its verified submodules (`imem`, `dmem`, `controller`, `reg_file`, `signextn`, `alu`), and adds full hardware hazard detection, forwarding, stalling, branch flushing, and cycle/retired-instruction performance counters.

> Back to the [root project README](../README.md).

---

## Source Files

| File | Module | Role |
|:---|:---|:---|
| [`pipe_datapath.sv`](pipe_datapath.sv) | `pipe_datapath` | Top-level 5-stage pipeline (`IF`, `ID`, `EX`, `MEM`, `WB`), WB-to-ID bypass, EX/MEM forwarding value mux (`fwd_value_mem`), and performance counters (`cycles_count`, `retired_inst_count`). |
| [`hazard_unit.sv`](hazard_unit.sv) | `hazard_unit` | Combinational forwarding (`EX/MEM` and `MEM/WB` → `EX`), `x0` suppression, 1-cycle load-use stall, and EX-stage branch/jump flush control. |
| [`pipe_if_id.sv`](pipe_if_id.sv) | `pipe_if_id` | `IF/ID` pipeline register with `stall` hold and synchronous `flush` (injects `0x00000013` NOP). |
| [`pipe_id_ex.sv`](pipe_id_ex.sv) | `pipe_id_ex` | `ID/EX` pipeline register with synchronous `flush` to bubble out control/data signals. |
| [`pipe_ex_mem.sv`](pipe_ex_mem.sv) | `pipe_ex_mem` | `EX/MEM` pipeline register carrying ALU result, store data, `rd`, `pc_plus_4`, and `immediate`. |
| [`pipe_mem_wb.sv`](pipe_mem_wb.sv) | `pipe_mem_wb` | `MEM/WB` pipeline register feeding the 4:1 writeback mux (`alu_result`, `read_data`, `pc_plus_4`, `immediate`). |

---

## Microarchitecture & Hazard Handling

1. **5-Stage Datapath Partitioning (`pipe_datapath`):**
   - **IF:** Fetches from `imem` (`IMEM_WORDS = 128` default), selects `pc_next_if` among `pc_target_ex` (on `pc_src_ex`), `pc_if` hold (on `stall_pc`), or `pc_if + 4`.
   - **ID:** Decodes instruction via `controller`, extends immediates via `signextn`, and reads `reg_file`. Includes an internal **WB-to-ID combinational bypass** so an instruction in ID reading a register written in WB in the same cycle sees the updated value immediately.
   - **EX:** Computes arithmetic/logic operations and branch comparisons (`alu`), resolves `pc_target_ex = pc_ex + immediate_ex` and `pc_src_ex = jump_ex | (branch_ex & branch_condition_ex)`.
   - **MEM:** Accesses word-aligned `dmem` (`DMEM_WORDS = 128` default).
   - **WB:** Selects writeback data via 4:1 `result_src_wb` mux (`00`: ALU result, `01`: DMEM read data, `10`: `pc_plus_4` for `jal`, `11`: `immediate` for `lui`).

2. **Data Forwarding (`hazard_unit` + `pipe_datapath`):**
   - `EX/MEM → EX` (`2'b10`) takes strict priority over `MEM/WB → EX` (`2'b01`).
   - Writes targeting architectural register `x0` (`rd == 5'd0`) never trigger forwarding.
   - **`LUI` / `JAL` EX/MEM Forwarding Mux (`fwd_value_mem`):** Because `lui` writes `immediate` (not `alu_result`) and `jal` writes `pc_plus_4`, `pipe_datapath` multiplexes `fwd_value_mem` from `immediate_mem_fwd` (`2'b11`), `pc_plus_4_mem_fwd` (`2'b10`), or `alu_result_mem` before feeding the EX forwarding muxes.

3. **Load-Use Stall & Control Hazards:**
   - **Load-Use Hazard:** When an instruction in EX is a load (`result_src_ex == 2'b01`, `rd_ex != 5'd0`) and `rd_ex` matches `rs1_id` or `rs2_id`, `hazard_unit` asserts `stall_pc`, `stall_if_id`, and `flush_id_ex` for 1 cycle to hold the dependent instruction and insert a bubble into EX.
   - **Control Hazard:** Taken branches and `jal` resolve in EX (`pc_src_ex == 1`), asserting `flush_if_id` and `flush_id_ex` to squash the two younger instructions in IF and ID (2-cycle branch/jump penalty).

---

## Verification & Measured Results

| Suite | Target / Script | Coverage & Checks | Measured Result |
|:---|:---|:---|:---|
| **Pipeline Hazard Tests** | [`tb_pipeline_hazards.sv`](../tests/pipelined/tb_pipeline_hazards.sv) ([`hazard_tests.s`](../tests/asm/hazard_tests.s)) | 10 checks: EX/MEM & MEM/WB forwarding, `x0` suppression, 1-cycle load-use stall, taken branch 2-cycle flush, back-to-back `lui` EX/MEM forwarding regression | **10/10 PASS** (35 cycles, 28 retired) |
| **Program Benchmark (`sum10`)** | [`tb_pipeline_programs.sv`](../tests/pipelined/tb_pipeline_programs.sv) ([`sum10.s`](../tests/asm/sum10.s)) | Loop sum $\sum_{i=1}^{10} i = 55$, store & reload check | **3/3 PASS** — 56 cycles, 35 dynamic insts (**CPI 1.60**) |
| **Program Benchmark (`mem_loop`)** | [`tb_pipeline_programs.sv`](../tests/pipelined/tb_pipeline_programs.sv) ([`mem_loop.s`](../tests/asm/mem_loop.s)) | Array store/load sum $= 100$ | **3/3 PASS** — 42 cycles, 29 dynamic insts (**CPI 1.45**) |
| **Random Differential Fuzzing** | [`random_diff_test.py`](../tools/random_diff_test.py) + [`tb_random_pipe.sv`](../tests/random/tb_random_pipe.sv) | 600 constrained-random programs compared against [`rv32i_iss.py`](../tools/rv32i_iss.py) golden model | **600/600 MATCH** (**0 mismatches**) |
| **Lint & Generic Synthesis** | [`Makefile`](../Makefile) (`make lint`, `make synth`) | Verilator `--lint-only -Wall --top-module pipe_datapath`; Yosys `synth -top pipe_datapath -flatten` | **0 lint warnings**, clean generic synthesis |

### Running Only Pipelined Tests
```bash
make lint           # Verilator -Wall lint on single-cycle & pipe_datapath
make test-pipeline  # Hazard tests + sum10 + mem_loop on 5-stage pipeline
make test-random    # 600-program differential verification against Python ISS
make synth          # Generic Yosys synthesis for datapath and pipe_datapath
```
