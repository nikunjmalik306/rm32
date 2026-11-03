# RM32 — Single-Cycle 32-bit RISC-V (RV32I) Processor Core

[![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-orange.svg)](https://riscv.org/)
[![Toolchain](https://img.shields.io/badge/Tools-Vivado%20Design%20Suite-red.svg)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Verification](https://img.shields.io/badge/Verification-Self--Checking%20Testbench%20PASS-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

---

## 1. Project Overview

**RM32** is a single-cycle 32-bit processor core implementing the **RV32I** base integer instruction set of the open-standard [RISC-V ISA](https://riscv.org/). Written entirely in modular **SystemVerilog**, the core executes an instruction every clock cycle using a combinational datapath orchestrated by a centralized control unit.

Rather than synthesizing an abstract specification all at once, RM32 was engineered through **first-principles incremental microarchitecture evolution**: starting from an atomic baseline capable only of memory load operations (`lw`), and progressively introducing the multiplexers, control signals, immediate decoders, arithmetic units, and branch structures required to execute Store (`sw`), R-type arithmetic/logic (`add`, `sub`, `and`, `or`, `slt`), and conditional branches (`beq`).

---

## 2. Microarchitecture Specifications

| Parameter | Specification | Details |
|:---|:---|:---|
| **Architecture** | RISC-V RV32I | 32-bit unprivileged base integer instruction set |
| **Microarchitecture** | Single-Cycle | 1 CPI (Cycles Per Instruction) for all supported operations |
| **Datapath Width** | 32 bits | 32-bit internal data buses and ALU operands |
| **Address Space** | 32 bits | Word-aligned memory addressing (`address[31:2]`) |
| **Register File** | 32 × 32-bit | Dual asynchronous read ports, single synchronous write port, hardwired zero register (`x0 = 0`) |
| **Memory Model** | Harvard (Split I/D) | Dedicated Instruction Memory and Data Memory with `$readmemh` initialization |
| **Control Unit** | Hierarchical 2-Level | Opcode-driven Main Decoder + Funct-driven ALU Decoder |
| **ALU Operations** | 32-bit Operations | Add, Subtract, Bitwise AND, Bitwise OR, Set-Less-Than (SLT), Zero flag detection |
| **Implementation** | SystemVerilog (IEEE 1800-2017) | Fully synthesizable RTL designed for FPGA targets |

---

## 3. Microarchitectural Evolution (Design Progression)

The processor was developed systematically by extending the datapath one instruction family at a time. The progression below documents how each hardware block and control wire was introduced into the system.

```
                    ┌────────────────────────────────────────────────────────┐
                    │               Microarchitecture Evolution              │
                    └────────────────────────────────────────────────────────┘
                                                │
                 ┌──────────────────────────────┴──────────────────────────────┐
                 ▼                                                             ▼
       [Stage 1: Base Datapath]                                      [Stage 2: Store Word]
           Load Word (`lw`)                                              Store Word (`sw`)
        • PC + 4 incrementer                                          • Connect RegFile RD2
        • 12-bit I-type Sign Extension                                • Add ALUSrc Mux (RD2 vs Imm)
        • ALU addition (Base + Offset)                                • Add S-type Immediate extraction
        • Data Memory read -> RegFile WD3                             • MemWrite signal for synchronous store
                 │                                                             │
                 └──────────────────────────────┬──────────────────────────────┘
                                                │
                 ┌──────────────────────────────┴──────────────────────────────┐
                 ▼                                                             ▼
       [Stage 3: R-Type Operations]                                  [Stage 4: Conditional Branches]
         `add`, `sub`, `and`, `or`, `slt`                                  `beq`
        • Add ResultSrc Mux (ALU vs DMem)                             • Add Branch Target Adder (PC + Imm)
        • ALU direct feed to Register File                            • ALU Subtraction with Zero Flag
        • 3-bit ALUControl decoding                                   • PCSrc Logic: Branch & Zero
        • Multi-op ALU Arithmetic/Logic core                          • Add Next-PC Selection Mux
```

---

### Stage 1: Base Datapath — Load Word (`lw`)

The foundation of RM32 begins with the **Load Word** instruction (`lw rd, offset(rs1)`), an I-type instruction.

```
Instruction Format (I-Type):
 31                        20 19         15 14    12 11        7 6            0
┌────────────────────────────┬─────────────┬────────┬───────────┬──────────────┐
│         imm[11:0]          │     rs1     │ funct3 │    rd     │    opcode    │
│            -4              │     x9      │  010   │    x6     │   0000011    │
│        111111111100        │    01001    │  010   │   00110   │   0000011    │
└────────────────────────────┴─────────────┴────────┴───────────┴──────────────┘
```

#### Datapath Flow for `lw`:
1. **Instruction Fetch:** The Program Counter (`PC`) outputs the current instruction address to the Instruction Memory (`imem`). In parallel, an adder computes `PC + 4` for sequential execution.
2. **Register Read:** Bits `instruction[19:15]` (`rs1`) address read port `A1` of the Register File, yielding base register data `RD1`.
3. **Immediate Sign-Extension:** Bits `instruction[31:20]` (`imm[11:0]`) represent a 12-bit signed immediate (e.g., `-4` = `0xFFC`). The Sign Extension unit sign-extends this value to a full 32-bit word (`0xFFFFFFFC`) to match the ALU operand width.
4. **Address Computation:** The ALU computes the effective memory address:
   $$\text{Address} = \text{RD1} + \text{SignExt}(\text{imm})$$
5. **Memory Access & Writeback:** The computed address indexes the Data Memory (`dmem`). The read data (`dmem_data`) is driven directly into register write port `WD3`, addressed by `instruction[11:7]` (`rd`), where it is latched on the rising clock edge when `RegWrite = 1`.

```mermaid
flowchart LR
    PC["PC (Program Counter)"] -->|"PC"| IMEM["Instruction Memory"]
    IMEM -->|"instr[19:15] (rs1)"| RF_A1["RegFile (A1)"]
    IMEM -->|"instr[31:20] (imm)"| SEXT["Sign Extender (12->32)"]
    IMEM -->|"instr[11:7] (rd)"| RF_A3["RegFile (A3)"]
    
    RF_A1 -->|"RD1"| ALU_A["ALU Input A"]
    SEXT -->|"ExtImm"| ALU_B["ALU Input B"]
    
    ALU_A & ALU_B --> ALU["ALU (+)"]
    ALU -->|"Address"| DMEM["Data Memory"]
    DMEM -->|"Read Data"| RF_WD3["RegFile (WD3)"]
    
    PC -->|"PC"| PC_ADD["Adder (+4)"]
    PC_ADD -->|"PC + 4"| PC_NEXT["Next PC"]
    PC_NEXT --> PC
```

---

### Stage 2: Adding Store Word (`sw`)

To store data back into memory, the core supports the **Store Word** instruction (`sw rs2, offset(rs1)`), an S-type instruction.

```
Instruction Format (S-Type):
 31                 25 24         20 19         15 14    12 11         7 6            0
┌─────────────────────┬─────────────┬─────────────┬────────┬────────────┬──────────────┐
│      imm[11:5]      │     rs2     │     rs1     │ funct3 │  imm[4:0]  │    opcode    │
│       0000000       │    00110    │    01001    │  010   │   01000    │   0100011    │
└─────────────────────┬─────────────┬─────────────┬────────┬────────────┴──────────────┘
```

#### Datapath Additions for `sw`:
- **Second Register Read Port (`RD2`):** Bits `instruction[24:20]` (`rs2`) are routed to Register File port `A2` to read the data to be written (`RD2`). This signal directly connects to `write_data` of Data Memory.
- **ALUSrc Multiplexer:** A 2-to-1 multiplexer is inserted before ALU input `B`:
  - When `ALUSrc = 1` (Load/Store), the ALU receives the sign-extended immediate to compute the memory address.
  - When `ALUSrc = 0` (R-type), the ALU receives `RD2`.
- **Split Immediate Support (`ImmSrc`):** S-type instructions split the 12-bit immediate across `instruction[31:25]` and `instruction[11:7]`. The Sign Extension unit is enhanced with an `ImmSrc[1:0]` control signal:
  - `ImmSrc = 2'b00` (I-type): Imm = `{{20{instr[31]}}, instr[31:20]}`
  - `ImmSrc = 2'b01` (S-type): Imm = `{{20{instr[31]}}, instr[31:25], instr[11:7]}`
- **Memory Write Enable (`MemWrite`):** Asserted high exclusively for store instructions to latch `RD2` into Data Memory at the target address on the rising clock edge.

---

### Stage 3: Extending to R-Type Arithmetic and Logic (`add`, `sub`, `and`, `or`, `slt`)

R-type instructions operate strictly between registers without memory access.

```
Instruction Format (R-Type):
 31                 25 24         20 19         15 14    12 11        7 6            0
┌─────────────────────┬─────────────┬─────────────┬────────┬───────────┬──────────────┐
│       funct7        │     rs2     │     rs1     │ funct3 │    rd     │    opcode    │
│      0000000        │    00110    │    00101    │  110   │   00100   │   0110011    │
└─────────────────────┴─────────────┴─────────────┴────────┴───────────┴──────────────┘
 Example: or x4, x5, x6
```

#### Datapath Additions for R-Type:
- **`ResultSrc` Multiplexer:** A 2-to-1 multiplexer at the writeback stage allows the register file write data port (`WD3`) to select between:
  - `ResultSrc = 0`: `ALUResult` (for R-type instructions and I-type ALU operations)
  - `ResultSrc = 1`: `ReadData` from Data Memory (for `lw`)
- **ALU Operand Routing:** `ALUSrc = 0` routes `RD2` directly to ALU Input `B`.

---

### Stage 4: Adding Conditional Branching (`beq`)

Branch instructions alter the sequential flow of program execution based on a comparison.

```
Instruction Format (B-Type):
 31   30           25 24         20 19         15 14    12 11        8  7   6            0
┌────┬───────────────┬─────────────┬─────────────┬────────┬───────────┬───┬──────────────┐
│12  │   imm[10:5]   │     rs2     │     rs1     │ funct3 │ imm[4:1]  │11 │    opcode    │
│ 1  │    111111     │    00100    │    00100    │  000   │   1010    │ 1 │   1100011    │
└────┴───────────────┴─────────────┴─────────────┴────────┴───────────┴───┴──────────────┘
 Example: beq x4, x4, L7
```

#### Datapath Additions for `beq`:
- **Branch Target Adder:** A dedicated 32-bit adder computes the branch target in parallel with ALU execution:
  $$\text{PCTarget} = \text{PC} + \text{SignExt}(\text{imm}_{\text{B}})$$
- **Zero Detection:** The ALU performs a subtraction (`RD1 - RD2`). If the values are equal, the ALU's `Zero` flag evaluates to `1`.
- **Branch Gate & Next-PC Mux:**
  $$\text{PCSrc} = \text{Branch} \ \& \ \text{Zero}$$
  A 2-to-1 multiplexer before the Program Counter updates `PC` with `PCTarget` if `PCSrc = 1`, or `PC + 4` if `PCSrc = 0`.

---

## 4. Comprehensive Processor Datapath Architecture

The unified single-cycle datapath incorporating all four stages is structured as follows:

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 RM32 Unified Datapath                  │
                  └────────────────────────────────────────────────────────┘

              ┌──────────────────────────────────────────────┐
              │                                              │
              ▼                                              │
         ┌─────────┐                                         │
         │  MUX    │◄─── PCSrc (Branch & Zero)               │
         └──┬───┬──┘                                         │
     PC+4   │   │ PCTarget                                   │
      ┌─────┘   └──────┐                                     │
      ▼                ▼                                     │
   ┌──────┐         ┌──────┐                                 │
   │  PC  │────────►│ ADD  │ (PC + SignExt(Imm))             │
   └──┬───┘         └──┬───┘                                 │
      │                └─────────────────────────────────────┘
      ├───────────►┌─────────┐
      │            │ ADD (+4)│──────────────┐
      │            └─────────┘              │
      ▼                                     ▼
 ┌──────────┐                          ┌─────────┐
 │ Inst Mem │                          │ MUX     │◄── ResultSrc
 └────┬─────┘                          └──┬───┬──┘
      │                                   │   │
      │   instr[19:15] (rs1)              │   │ ReadData
      ├───► [A1]   Register File          │   └──────────────┐
      │   instr[24:20] (rs2)              │ ALUResult        │
      ├───► [A2]      [RD1] ──────► [A]   │                  │
      │   instr[11:7] (rd)                ▼                  │
      ├───► [A3]      [RD2] ──┬───► [0]  ALU ───► Result ────┤
      │                       │     [MUX]                    │
      │                       └───► [1]   │                  │
      │                             ▲     └──► Zero ─┐       │
      │   instr[31:7]               │                │       │
      └───► [Sign Ext] ─────────────┘ (ALUSrc)       │       │
                  │                                  ▼       │
                  └───────────────────────────► [PCSrc Logic]│
                                                     ▲       │
                                                     │       │
                              Data Memory            │       │
                           ┌──────────────┐          │       │
      ALU Result ─────────►│ Address      │          │       │
      RD2 (WriteData) ────►│ Write Data   │          │       │
      MemWrite ───────────►│ Write Enable │          │       │
                           │ Read Data    ├──────────┴───────┘
                           └──────────────┘
```

---

## 5. Control Unit Architecture & Truth Tables

The RM32 Control Unit is organized hierarchically into a **Main Decoder** and an **ALU Decoder**, ensuring clean separation between top-level instruction sequencing and arithmetic function generation.

```mermaid
flowchart TD
    subgraph Control_Unit["Hierarchical Control Unit"]
        direction TB
        OP["op[6:0]"] --> MainDec["Main Decoder"]
        
        MainDec -->|"RegWrite"| RW["RegWrite"]
        MainDec -->|"MemWrite"| MW["MemWrite"]
        MainDec -->|"ResultSrc"| RS["ResultSrc"]
        MainDec -->|"ALUSrc"| AS["ALUSrc"]
        MainDec -->|"ImmSrc[1:0]"| IS["ImmSrc[1:0]"]
        MainDec -->|"Branch"| AND1["AND Gate"]
        MainDec -->|"ALUOp[1:0]"| ALUDec["ALU Decoder"]
        
        F3["funct3[2:0]"] --> ALUDec
        F7["funct7[5]"] --> ALUDec
        ALUDec -->|"alu_ctrl[2:0]"| AC["ALUControl[2:0]"]
        
        ZERO["ALU Zero"] --> AND1
        AND1 -->|"PCSrc"| PCSRC["PCSrc"]
    end
```

### Main Decoder Truth Table

| Instruction | opcode (`op[6:0]`) | RegWrite | ImmSrc | ALUSrc | MemWrite | ResultSrc | Branch | ALUOp | ALU Operation |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **`lw`** | `7'b0000011` (3) | `1` | `00` (I) | `1` | `0` | `1` (DMem) | `0` | `2'b00` | Addition (Base + Offset) |
| **`sw`** | `7'b0100011` (35) | `0` | `01` (S) | `1` | `1` | `X` | `0` | `2'b00` | Addition (Base + Offset) |
| **R-Type** | `7'b0110011` (51) | `1` | `XX` | `0` | `0` | `0` (ALU) | `0` | `2'b10` | Determined by `funct3` / `funct7` |
| **`beq`** | `7'b1100011` (99) | `0` | `10` (B) | `0` | `0` | `X` | `1` | `2'b01` | Subtraction (Compare `rs1 == rs2`) |

### ALU Decoder Truth Table

| `ALUOp[1:0]` | `funct3[2:0]` | `funct7[5]` | `alu_ctrl[2:0]` | Description / Operation |
|:---:|:---:|:---:|:---:|:---|
| `2'b00` | `XXX` | `X` | `3'b000` / `3'b010`* | **Add** (address calculation for `lw`/`sw`) |
| `2'b01` | `XXX` | `X` | `3'b001` | **Subtract** (equality check for `beq`) |
| `2'b10` | `3'b000` | `1'b0` | `3'b000` | **Add** (`add`) |
| `2'b10` | `3'b000` | `1'b1` | `3'b001` | **Subtract** (`sub`) |
| `2'b10` | `3'b010` | `1'b0` | `3'b101` | **Set Less Than** (`slt`) |
| `2'b10` | `3'b110` | `1'b0` | `3'b011` | **Bitwise OR** (`or`) |
| `2'b10` | `3'b111` | `1'b0` | `3'b010` | **Bitwise AND** (`and`) |

*\*Note: In the baseline memory execution RTL, `alu_ctrl = 3'b010` was configured as the active adder code.*

---

## 6. Deep Inside the ALU

The Arithmetic Logic Unit (ALU) performs computation on two 32-bit operands `A` and `B`, driven by `alu_ctrl[2:0]`.

```
                    ┌──────────────────────────────────────────────┐
                    │            Deep Inside the ALU               │
                    └──────────────────────────────────────────────┘

                                   A [31:0]           B [31:0]
                                      │                  │
                         ┌────────────┼───────────┬──────┼────────┐
                         │            │           │      ▼        │
                         │            │           │   ┌──────┐    │
                         │            │           │   │ NOT  │    │
                         │            │           │   └──┬───┘    │
                         │            │           │      │        │
                         │            │           │  [0] │ [1]    │
                         │            │           ├──►\  /        │
                         │            │           │    \/ MUX     │
                         │            │           │    │◄── alu_ctrl[0] (Invert B)
                         │            │           │    │
                         ▼            ▼           │    │
                      ┌─────┐      ┌─────┐        │    │
                      │ AND │      │ OR  │        │    │
                      └──┬──┘      └──┬──┘        ▼    ▼
                         │            │        ┌──────────┐
                         │            │        │  ADDER   │◄── Cin = alu_ctrl[0]
                         │            │        └──┬────┬──┘
                         │            │           │    │ Cout/Sign
                         │            │           │    ▼
                         │            │           │ ┌───────────────┐
                         │            │           │ │ Zero-Extend   │ (Set Less Than)
                         │            │           │ └───────┬───────┘
                         │            │           │         │
                         ▼            ▼           ▼         ▼
                      ┌─────────────────────────────────────────┐
                      │              OUTPUT MUX                 │◄── alu_ctrl[2:0]
                      └────────────────────┬────────────────────┘
                                           │
                                           ├───────────────► Result [31:0]
                                           ▼
                                    ┌──────────────┐
                                    │ NOR REDUCTION│───────► Zero Flag
                                    └──────────────┘
```

### Key Hardware Implementation Details:
1. **Unified Adder / Subtractor:** Subtraction ($A - B$) is performed using two's complement arithmetic:
   $$A - B = A + \sim B + 1$$
   The least significant control bit `alu_ctrl[0]` selects inverted operand $\sim B$ via a multiplexer and simultaneously feeds the carry-in ($C_{\text{in}} = 1$) of the 32-bit adder.
2. **Set Less Than (`slt`):** Uses the adder subtraction result. If $A < B$, the sign bit evaluates to 1; the logic zero-extends this single bit to form a 32-bit result (`32'h00000001`), otherwise `32'h00000000`.
3. **Zero Flag Generation:** Evaluated combinationally via wide NOR reduction over all 32 bits of the output:
   ```systemverilog
   assign zero = (result == 32'b0);
   ```

---

## 7. RTL Implementation Directory & Module Guide

The repository is structured into clean, modular SystemVerilog source files:

```
rm32/
├── README.md                      # Comprehensive microarchitecture documentation
├── .gitignore                     # Git tracking exclusions
├── images/                        # Simulation waveforms and verification artifacts
│   ├── alu_add_verification.png   # ALU unit simulation waveform
│   ├── Dmem_verification.png      # Data memory unit simulation waveform
│   ├── load_better.png            # Vivado load word verification waveform
│   ├── lw_sw_sim.png              # Load & Store program execution waveform
│   └── tcl_console_lw_sw.png      # Vivado TCL console automated test output
├── rtl/                           # Synthesizable SystemVerilog source files
│   ├── alu.sv                     # 32-bit Arithmetic Logic Unit
│   ├── contoller.sv               # Hierarchical instruction decoder and controller
│   ├── datapath.sv                # Top-level single-cycle processor datapath
│   ├── dmem.sv                    # Parameterized dual RAM model ($readmemh)
│   ├── imem.sv                    # Instruction memory interface wrapper
│   ├── reg_file.sv                # 32 x 32-bit dual-read register file (x0 = 0)
│   ├── signextn.sv                # Immediate sign extension (I-type & S-type)
│   ├── dmem.hex                   # Initial data memory contents
│   └── imemory.hex                # Assembled machine code test program
└── TestBench/
    └── single_cycle_TB.sv         # Self-checking simulation testbench
```

### RTL Module Summaries

- **[`datapath.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/datapath.sv):** Instantiates and interconnects the Program Counter register, Instruction Memory, Controller, Register File, Sign Extender, ALU, and Data Memory.
- **[`contoller.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/contoller.sv):** Decodes instruction opcode (`instruction[6:0]`), `func3`, and `func7`, asserting `reg_write`, `mem_write`, `imm_src`, and `alu_ctrl`.
- **[`alu.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/alu.sv):** Performs arithmetic addition and flag computation with zero-condition reduction.
- **[`reg_file.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/reg_file.sv):** Implements thirty-two 32-bit registers. Features asynchronous dual read (`data1`, `data2`), synchronous write on `clk` posedge with write-enable gate, and guarantees `register[0]` remains hardwired to zero.
- **[`signextn.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/signextn.sv):** Assembles and sign-extends 12-bit immediate offsets based on `imm_source`:
  - `2'b00` (I-type): `{instr[24:13]}` $\rightarrow$ sign-extended to 32 bits.
  - `2'b01` (S-type): `{instr[24:18], instr[4:0]}` $\rightarrow$ sign-extended to 32 bits.
- **[`dmem.sv`](file:///Users/nikunj/Downloads/rm32-main/rtl/dmem.sv):** 64-word memory block initialized from a `.hex` file. Writes occur synchronously on `clk` posedge when word-aligned (`address[1:0] == 2'b00`), while reads occur combinationally.

---

## 8. Verification & Simulation Results

The core has been validated using **AMD Xilinx Vivado (XSim)** with self-checking testbenches and automated assertions.

### 1. Test Program Assembly

The instruction memory is pre-loaded via [`imemory.hex`](file:///Users/nikunj/Downloads/rm32-main/rtl/imemory.hex) with a verification program:

```assembly
# Address   Machine Code   Instruction          Description
0x00000000  00000013       nop                  addi x0, x0, 0
0x00000004  00402983       lw x19, 4(x0)        Load word from dmem[1] (0x00000123) into x19
0x00000008  00802983       lw x19, 8(x0)        Load word from dmem[2] (0xDEADBEEF) into x19
0x0000000C  01302623       sw x19, 12(x0)       Store word (0xDEADBEEF) into dmem[3]
0x00000010  00002b83       lw x23, 0(x0)        Load word from dmem[0] (0xAEAEAEAE) into x23
```

Initial Data Memory ([`dmem.hex`](file:///Users/nikunj/Downloads/rm32-main/rtl/dmem.hex)):
```hex
AEAEAEAE  // @ 0x00000000
00000123  // @ 0x00000004
DEADBEEF  // @ 0x00000008
00000000  // @ 0x0000000C (target for store word)
```

---

### 2. Load Word (`lw`) Execution Verification

The waveform below demonstrates the execution of the memory load instructions:
- Cycle 1: `lw x19, 4(x0)` loads `0x00000123` into register `x19`.
- Cycle 2: `lw x19, 8(x0)` updates register `x19` with `0xDEADBEEF`.

![Load Word Verification](images/load_better.png)

---

### 3. Combined Load & Store (`lw` + `sw`) Execution Verification

The waveform confirms proper dataflow between the Register File and Data Memory:
- `x19` holds `0xDEADBEEF`.
- On instruction `0x01302623` (`sw x19, 12(x0)`), `write_data` is presented as `0xDEADBEEF` at address `0x0000000C` (`mem[3]`).
- On the next cycle, the memory contents at offset 12 reflect `0xDEADBEEF`.

![Load and Store Simulation Waveform](images/lw_sw_sim.png)

---

### 4. Automated Self-Checking Testbench Output

The Vivado TCL simulation console verifies the hardware assertions written in [`single_cycle_TB.sv`](file:///Users/nikunj/Downloads/rm32-main/TestBench/single_cycle_TB.sv):

```text
Compiling module xil_defaultlib.memory(mem_init="dmem.hex")
Compiling module xil_defaultlib.datapath
Compiling module xil_defaultlib.single_cycle_TB
Compiling module xil_defaultlib.glbl
Built simulation snapshot single_cycle_TB_behav
INFO: [USF-XSim-69] 'elaborate' step finished in '2' seconds
Time resolution is 1 ps
PASS: x19 = deadbeef as expected
PASS: datamem 12 = deadbeef as expected
$finish called at time : 75 ns
```

![TCL Console Output](images/tcl_console_lw_sw.png)

---

### 5. Unit Verification: ALU & Data Memory

Individual unit-level simulations confirm standalone functional correctness before full system integration:

| ALU Adder & Zero Verification | Data Memory Synchronous Write / Asynchronous Read |
|:---:|:---:|
| ![ALU Unit Verification](images/alu_add_verification.png) | ![DMem Unit Verification](images/Dmem_verification.png) |

---

## 9. How to Simulate

### Prerequisites
- **AMD Xilinx Vivado** (v2020.1 or newer recommended) or any IEEE 1800-2017 compliant SystemVerilog simulator (e.g., ModelSim, Questa, Verilator, Icarus Verilog).

### Running in Vivado GUI
1. Clone the repository:
   ```bash
   git clone https://github.com/nikunjmalik306/rm32.git
   cd rm32
   ```
2. Create a new Vivado RTL project targeting any Xilinx FPGA device (e.g., Artix-7 `xc7a35tcsg324-1`).
3. Add design sources from `rtl/`:
   - `datapath.sv`, `contoller.sv`, `alu.sv`, `reg_file.sv`, `signextn.sv`, `dmem.sv`, `imem.sv`
   - Memory hex files: `imemory.hex`, `dmem.hex`
4. Add simulation source from `TestBench/`:
   - `single_cycle_TB.sv`
5. Run Behavioral Simulation (**Run Simulation $\rightarrow$ Run Behavioral Simulation**).
6. Verify console output reports:
   ```
   PASS: x19 = deadbeef as expected
   PASS: datamem 12 = deadbeef as expected
   ```

---

## 10. References

1. **RISC-V ISA Specification** — *The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA*, Version 20191213. RISC-V International. [https://riscv.org/technical/specifications/](https://riscv.org/technical/specifications/)
2. **Harris & Harris** — *Digital Design and Computer Architecture: RISC-V Edition*. Sarah L. Harris and David Money Harris, Morgan Kaufmann, 2021.
3. **IEEE Standard 1800-2017** — *IEEE Standard for SystemVerilog — Unified Hardware Design, Specification, and Verification Language*.

---

<p align="center">
  <b>RM32 Processor Core</b> • Developed by <a href="https://github.com/nikunjmalik306">Nikunj Malik</a>
</p>
