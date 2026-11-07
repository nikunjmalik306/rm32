#!/usr/bin/env python3
"""
RV32I Subset Instruction Set Simulator (Golden Reference Model)
Supports:
  lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui
Simulates single-cycle instruction execution, models architectural register file
and memory state, and outputs instruction-by-instruction execution traces for
trace-diff verification against the SystemVerilog RTL.
"""

import sys

def to_signed(val, bits=32):
    val = val & ((1 << bits) - 1)
    if val & (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def to_unsigned(val, bits=32):
    return val & ((1 << bits) - 1)

class RV32I_ISS:
    def __init__(self, imem_words=128, dmem_words=128):
        self.regs = [0] * 32
        self.pc = 0
        self.imem = [0x00000013] * imem_words # NOP default
        self.dmem = [0] * dmem_words
        self.imem_words = imem_words
        self.dmem_words = dmem_words
        self.instruction_count = 0
        self.trace = []

    def load_imem_hex(self, hex_path):
        with open(hex_path, 'r') as f:
            lines = f.readlines()
        idx = 0
        for line in lines:
            clean = line.split('//')[0].split('#')[0].strip()
            if clean and idx < self.imem_words:
                self.imem[idx] = int(clean, 16)
                idx += 1

    def load_dmem_hex(self, hex_path):
        with open(hex_path, 'r') as f:
            lines = f.readlines()
        idx = 0
        for line in lines:
            clean = line.split('//')[0].split('#')[0].strip()
            if clean and idx < self.dmem_words:
                self.dmem[idx] = int(clean, 16)
                idx += 1

    def step(self):
        word_addr = self.pc >> 2
        if word_addr >= self.imem_words or (self.pc & 0x3) != 0:
            return False # Terminate on out-of-bounds PC

        instr = self.imem[word_addr]
        opcode = instr & 0x7F
        rd     = (instr >> 7) & 0x1F
        funct3 = (instr >> 12) & 0x07
        rs1    = (instr >> 15) & 0x1F
        rs2    = (instr >> 20) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        next_pc = self.pc + 4
        prev_pc = self.pc

        # R-type (0x33)
        if opcode == 0x33:
            v1 = self.regs[rs1]
            v2 = self.regs[rs2]
            if funct3 == 0x0:
                if funct7 == 0x20: # SUB
                    res = to_unsigned(v1 - v2)
                else:              # ADD
                    res = to_unsigned(v1 + v2)
            elif funct3 == 0x7:    # AND
                res = to_unsigned(v1 & v2)
            elif funct3 == 0x6:    # OR
                res = to_unsigned(v1 | v2)
            elif funct3 == 0x2:    # SLT (signed)
                s1 = to_signed(v1)
                s2 = to_signed(v2)
                res = 1 if s1 < s2 else 0
            else:
                raise ValueError(f"Unknown R-type funct3: {funct3}")
            if rd != 0:
                self.regs[rd] = res

        # I-type ALU (0x13)
        elif opcode == 0x13:
            imm = to_signed(instr >> 20, 12)
            v1 = self.regs[rs1]
            if funct3 == 0x0:      # ADDI
                res = to_unsigned(v1 + imm)
            elif funct3 == 0x7:    # ANDI
                res = to_unsigned(v1 & to_unsigned(imm))
            elif funct3 == 0x6:    # ORI
                res = to_unsigned(v1 | to_unsigned(imm))
            elif funct3 == 0x2:    # SLTI (signed)
                s1 = to_signed(v1)
                res = 1 if s1 < imm else 0
            else:
                raise ValueError(f"Unknown I-type ALU funct3: {funct3}")
            if rd != 0:
                self.regs[rd] = res

        # I-type Load (0x03)
        elif opcode == 0x03:
            imm = to_signed(instr >> 20, 12)
            addr = to_unsigned(self.regs[rs1] + imm)
            if (addr & 0x3) == 0 and (addr >> 2) < self.dmem_words:
                val = self.dmem[addr >> 2]
            else:
                val = 0
            if rd != 0:
                self.regs[rd] = val

        # S-type Store (0x23)
        elif opcode == 0x23:
            imm = to_signed(((instr >> 25) << 5) | ((instr >> 7) & 0x1F), 12)
            addr = to_unsigned(self.regs[rs1] + imm)
            val = self.regs[rs2]
            if (addr & 0x3) == 0 and (addr >> 2) < self.dmem_words:
                self.dmem[addr >> 2] = val

        # B-type Branch (0x63)
        elif opcode == 0x63:
            imm12   = (instr >> 31) & 0x1
            imm10_5 = (instr >> 25) & 0x3F
            imm4_1  = (instr >> 8) & 0xF
            imm11   = (instr >> 7) & 0x1
            imm_b = to_signed((imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1), 13)
            v1 = self.regs[rs1]
            v2 = self.regs[rs2]
            taken = False
            if funct3 == 0x0:   # BEQ
                taken = (v1 == v2)
            elif funct3 == 0x1: # BNE
                taken = (v1 != v2)
            if taken:
                next_pc = to_unsigned(self.pc + imm_b)

        # J-type JAL (0x6F)
        elif opcode == 0x6F:
            imm20   = (instr >> 31) & 0x1
            imm10_1 = (instr >> 21) & 0x3FF
            imm11   = (instr >> 20) & 0x1
            imm19_12 = (instr >> 12) & 0xFF
            imm_j = to_signed((imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1), 21)
            if rd != 0:
                self.regs[rd] = to_unsigned(self.pc + 4)
            next_pc = to_unsigned(self.pc + imm_j)

        # U-type LUI (0x37)
        elif opcode == 0x37:
            imm_u = instr & 0xFFFFF000
            if rd != 0:
                self.regs[rd] = to_unsigned(imm_u)

        else:
            return False

        self.regs[0] = 0 # Invariant: x0 is always 0
        self.instruction_count += 1
        
        # Record trace entry
        # Format: PC=<hex> INSTR=<hex> R1=<hex> ...
        entry = {
            'pc': prev_pc,
            'instr': instr,
            'next_pc': next_pc,
            'regs': list(self.regs),
            'dmem': list(self.dmem)
        }
        self.trace.append(entry)
        self.pc = next_pc
        return True

    def run(self, max_cycles=1000):
        for _ in range(max_cycles):
            if not self.step():
                break

    def dump_trace(self, filepath):
        with open(filepath, 'w') as f:
            for t in self.trace:
                reg_str = " ".join([f"x{i}={v:08x}" for i, v in enumerate(t['regs']) if v != 0])
                f.write(f"PC:{t['pc']:08x} INSTR:{t['instr']:08x} {reg_str}\n")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: rv32i_iss.py <imem.hex> [dmem.hex] [max_cycles]")
        sys.exit(1)
    imem_f = sys.argv[1]
    dmem_f = sys.argv[2] if len(sys.argv) > 2 else ""
    max_c  = int(sys.argv[3]) if len(sys.argv) > 3 else 100
    iss = RV32I_ISS()
    iss.load_imem_hex(imem_f)
    if dmem_f:
        iss.load_dmem_hex(dmem_f)
    iss.run(max_c)
    print(f"Executed {iss.instruction_count} instructions.")
    print("Non-zero registers:")
    for i, r in enumerate(iss.regs):
        if r != 0:
            print(f"  x{i:02d} = 0x{r:08x} ({to_signed(r)})")
