# Changelog — RM32 Processor Core Upgrade

All notable changes made to turn the RM32 repository into a portfolio-grade RISC-V implementation are documented in this file.

---

## [upgrade/rv32i-complete] - 2026-11-07

### RTL Core Architecture & Bug Fixes
- **Renamed Controller:** Corrected spelling of `rtl/contoller.sv` to `rtl/controller.sv` and renamed module definition from `contoller` to `controller`.
- **Reset Polarity Normalization:** Fixed active-low signal name `reset_n` across `datapath.sv`, `reg_file.sv`, `dmem.sv`, and testbenches to active-high `reset`, matching the internal implementation.
- **Removed Unused Skeleton:** Deleted empty, unused `rtl/imem.sv` and replaced it with a clean, parameterized instruction memory module matching its filename.
- **Declaration Order Fix:** Resolved undeclared signal compilation error in `rtl/datapath.sv` where `dmem_data` was referenced before declaration, achieving full IEEE 1800 SystemVerilog compliance.
- **ALU Expansion:** Expanded `rtl/alu.sv` from addition-only to support `ADD`, `SUB`, `AND`, `OR`, and signed comparison `SLT` with zero-flag generation.
- **Sign Extender Overhaul:** Redesigned `rtl/signextn.sv` with 3-bit `imm_source` selector supporting I, S, B, J, and U instruction immediate formats.
- **Controller Decoder Implementation:** Added complete Main Decoder and ALU Decoder truth tables in `rtl/controller.sv` supporting all 15 RV32I subset instructions (`lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui`).
- **Datapath Interconnect:** Integrated `ALUSrc` mux, `ResultSrc` 4:1 writeback mux, branch/jump adder, and `pc_src` mux into `rtl/datapath.sv`.
- **SystemVerilog Assertions (SVA):** Embedded active assertion checks in `rtl/datapath.sv` for register `x0` zero invariant, simultaneous read/write exclusivity, and PC word-alignment.

### 5-Stage Pipelined Core (`pipelined/`)
- **Pipeline Architecture:** Created clean 5-stage pipeline core in `pipelined/` comprising IF, ID, EX, MEM, and WB stages with dedicated pipeline registers (`pipe_if_id.sv`, `pipe_id_ex.sv`, `pipe_ex_mem.sv`, `pipe_mem_wb.sv`).
- **Hazard Unit:** Implemented comprehensive hazard detection in `pipelined/hazard_unit.sv`:
  - EX/MEM and MEM/WB data forwarding to EX stage with strict EX/MEM priority.
  - Architectural `x0` forwarding suppression (`rd != 5'd0`).
  - 1-cycle load-use hazard detection and hardware stall.
  - Branch and jump resolution in EX with 2-cycle flush of younger instructions.
- **Performance Counters:** Added hardware cycle and retired instruction counters for precise CPI measurement.

### Verification Infrastructure
- **Self-Checking Unit Testbenches:** Added standalone, self-checking unit testbenches in `tests/unit/`:
  - `tb_alu.sv` (10 tests covering all arithmetic, logic, signed comparisons, and zero flag).
  - `tb_reg_file.sv` (5 tests covering dual read, synchronous write, x0 suppression, and reset).
  - `tb_signextn.sv` (8 tests covering positive/negative immediate decoding for I, S, B, J, U).
  - `tb_controller.sv` (17 tests covering all 15 instructions and branch condition flags).
  - `tb_dmem.sv` (6 tests covering synchronous write, combinational read, unaligned access rejection, and bounds protection).
- **Integration Testbenches:** Added system-level testbenches in `tests/integration/` and `tests/pipelined/`:
  - `tb_instruction_classes.sv` (directed tests for signed SLT/SLTI, negative immediates, LUI, JAL, BEQ, BNE).
  - `tb_programs.sv` (runs `sum10.hex` and `mem_loop.hex` with trace dumping).
  - `tb_pipeline_hazards.sv` (tests RAW forwarding, x0 suppression, load-use stall, branch flush).
  - `tb_pipeline_programs.sv` (runs full programs on 5-stage pipeline with CPI measurement).
- **Assembler:** Developed Python RV32I subset assembler (`tools/assembler.py`) supporting pseudo-instructions (`li, nop, j`), label resolution, and standard `.hex` generation.
- **Golden Model (ISS):** Built standalone Python instruction set simulator (`tools/rv32i_iss.py`) modeling architectural register and memory state.
- **Trace-Diff Verification:** Created automated trace comparison tool (`tools/run_trace_diff.py`) comparing RTL execution traces against the Python ISS golden model.

### Tooling, Synthesis & CI
- **Makefile Automation:** Created top-level `Makefile` supporting `make test`, `make test-unit`, `make test-integration`, `make test-pipeline`, `make test-iss`, `make lint`, `make synth`, `make wave`, and `make clean`.
- **Verilator Lint:** Validated both single-cycle and pipelined cores with `verilator --lint-only -Wall` with zero warnings.
- **Generic Synthesis:** Executed generic logic synthesis using Yosys 0.70+post, extracting real cell counts and topological critical path estimates.
- **CI Workflow:** Created `.github/workflows/ci.yml` running lint, full verification test suite, and synthesis check on every push and pull request.

### Documentation
- **README Rewrite:** Completely updated `README.md` with accurate supported instruction tables, Mermaid block diagrams, real simulation results, and honest limitation disclosures.
- **Design Decisions Document:** Created `docs/DESIGN_DECISIONS.md` explaining the engineering WHY behind each choice.
- **Interview Notes:** Created `docs/INTERVIEW_NOTES.md` with 25 technical interview questions and grounded answers.
