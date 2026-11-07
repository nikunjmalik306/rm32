#!/usr/bin/env python3
"""
RV32I Subset Assembler
Supported instructions:
  lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, bne, jal, lui, nop, li, j
Generates standard 32-bit hex words compatible with Verilog $readmemh.
"""

import sys
import re

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
    'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REG_MAP[f'x{i}'] = i

def parse_reg(reg_str):
    reg_str = reg_str.strip().lower()
    if reg_str in REG_MAP:
        return REG_MAP[reg_str]
    raise ValueError(f"Unknown register: {reg_str}")

def parse_int(val_str):
    val_str = val_str.strip()
    if val_str.startswith(('0x', '0X')):
        return int(val_str, 16)
    if val_str.startswith(('0b', '0B')):
        return int(val_str, 2)
    return int(val_str, 10)

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | (imm4_0 << 7) | (opcode & 0x7F)

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm12   = (imm >> 12) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1  = (imm >> 1) & 0xF
    imm11   = (imm >> 11) & 0x1
    return (imm12 << 31) | (imm10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x07) << 12) | (imm4_1 << 8) | (imm11 << 7) | (opcode & 0x7F)

def encode_u(imm, rd, opcode):
    imm31_12 = (imm >> 12) & 0xFFFFF
    return (imm31_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_j(imm, rd, opcode):
    imm20   = (imm >> 20) & 0x1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11   = (imm >> 11) & 0x1
    imm19_12 = (imm >> 12) & 0xFF
    return (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def assemble_file(input_path, output_path=None):
    with open(input_path, 'r') as f:
        lines = f.readlines()

    # Pass 1: Parse instructions, clean comments, map labels
    statements = []
    labels = {}
    pc = 0

    for line_idx, line in enumerate(lines):
        clean = line.split('#')[0].split('//')[0].strip()
        if not clean:
            continue
        
        # Check for label(s)
        while ':' in clean:
            label_part, rest = clean.split(':', 1)
            label_name = label_part.strip()
            if label_name:
                labels[label_name] = pc
            clean = rest.strip()
        
        if not clean:
            continue

        # Check for pseudoinstruction expansion
        tokens = re.split(r'[\s,()]+', clean)
        tokens = [t for t in tokens if t]
        instr = tokens[0].lower()

        if instr == 'li':
            # li rd, imm -> lui + addi or single addi
            rd = tokens[1]
            val = parse_int(tokens[2])
            if -2048 <= val <= 2047:
                statements.append((pc, f"addi {rd}, x0, {val}"))
                pc += 4
            else:
                upper = (val + 0x800) >> 12
                lower = val - (upper << 12)
                statements.append((pc, f"lui {rd}, {upper << 12}"))
                pc += 4
                statements.append((pc, f"addi {rd}, {rd}, {lower}"))
                pc += 4
        elif instr == 'j':
            # j label -> jal x0, label
            statements.append((pc, f"jal x0, {tokens[1]}"))
            pc += 4
        elif instr == 'nop':
            statements.append((pc, "addi x0, x0, 0"))
            pc += 4
        else:
            statements.append((pc, clean))
            pc += 4

    # Pass 2: Assemble machine code
    machine_code = []
    for cur_pc, text in statements:
        tokens = re.split(r'[\s,()]+', text)
        tokens = [t for t in tokens if t]
        op = tokens[0].lower()

        # R-type
        if op in ('add', 'sub', 'and', 'or', 'slt'):
            rd  = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            rs2 = parse_reg(tokens[3])
            funct7 = 0x20 if op == 'sub' else 0x00
            f3_map = {'add': 0, 'sub': 0, 'slt': 2, 'or': 6, 'and': 7}
            code = encode_r(funct7, rs2, rs1, f3_map[op], rd, 0x33)

        # I-type ALU
        elif op in ('addi', 'andi', 'ori', 'slti'):
            rd  = parse_reg(tokens[1])
            rs1 = parse_reg(tokens[2])
            imm = parse_int(tokens[3])
            f3_map = {'addi': 0, 'slti': 2, 'ori': 6, 'andi': 7}
            code = encode_i(imm, rs1, f3_map[op], rd, 0x13)

        # I-type Load: lw rd, imm(rs1)
        elif op == 'lw':
            rd  = parse_reg(tokens[1])
            imm = parse_int(tokens[2])
            rs1 = parse_reg(tokens[3])
            code = encode_i(imm, rs1, 0x2, rd, 0x03)

        # S-type Store: sw rs2, imm(rs1)
        elif op == 'sw':
            rs2 = parse_reg(tokens[1])
            imm = parse_int(tokens[2])
            rs1 = parse_reg(tokens[3])
            code = encode_s(imm, rs2, rs1, 0x2, 0x23)

        # B-type Branch: beq/bne rs1, rs2, label/offset
        elif op in ('beq', 'bne'):
            rs1 = parse_reg(tokens[1])
            rs2 = parse_reg(tokens[2])
            target = tokens[3]
            if target in labels:
                offset = labels[target] - cur_pc
            else:
                offset = parse_int(target)
            f3 = 0 if op == 'beq' else 1
            code = encode_b(offset, rs2, rs1, f3, 0x63)

        # J-type JAL: jal rd, target OR jal target
        elif op == 'jal':
            if len(tokens) == 2:
                rd = 1 # ra
                target = tokens[1]
            else:
                rd = parse_reg(tokens[1])
                target = tokens[2]
            if target in labels:
                offset = labels[target] - cur_pc
            else:
                offset = parse_int(target)
            code = encode_j(offset, rd, 0x6F)

        # U-type LUI: lui rd, imm
        elif op == 'lui':
            rd = parse_reg(tokens[1])
            imm = parse_int(tokens[2])
            # If immediate passed is full 32-bit (e.g. 0x12345000), keep as is; if 20-bit, shift
            if (imm & 0xFFF) == 0 and imm > 0xFFFFF:
                imm_val = imm
            else:
                imm_val = imm << 12
            code = encode_u(imm_val, rd, 0x37)

        else:
            raise ValueError(f"Unsupported instruction: {op} in line: {text}")

        machine_code.append((code, f"{code:08x}  // [0x{cur_pc:04x}] {text}"))

    if output_path:
        with open(output_path, 'w') as f:
            for code, comment in machine_code:
                f.write(f"{code:08x}\n")
    return machine_code

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: assembler.py <source.s> [output.hex]")
        sys.exit(1)
    inp = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None
    codes = assemble_file(inp, out)
    if not out:
        for c, comm in codes:
            print(comm)
