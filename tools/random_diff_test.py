#!/usr/bin/env python3
"""
Random differential test: Python ISS (golden model) vs single-cycle RTL vs 5-stage pipelined RTL.

Generates constrained-random RV32I-subset programs (forward-only branches/jumps, so every
program terminates), runs each on the ISS and on both cores, and compares the FINAL
register file (x0..x31) and data memory (128 words). Exits non-zero on any mismatch.

Run from the repo root:   python3 tools/random_diff_test.py [num_programs] [--keep]
"""
import os, random, re, subprocess, sys, tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from rv32i_iss import RV32I_ISS

def enc_r(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def enc_i(imm, rs1, f3, rd, op):     return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def enc_s(imm, rs2, rs1, f3, op):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def enc_b(imm, rs2, rs1, f3):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | 0x63
def enc_j(imm, rd):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
           (((imm >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F
def enc_u(imm, rd): return ((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37

NOP = 0x13

def gen_program(rng, length=90):
    pool = [1, 2, 3, 4, 5, 6, 7]                 # small pool => lots of RAW hazards
    prog = [enc_i(rng.randint(-2048, 2047), 0, 0, r, 0x13) for r in pool]
    prog.append(enc_u(rng.randint(0, 0xFFFFF), rng.choice(pool)))
    while len(prog) < length:
        i = len(prog)
        rd, a, b = rng.choice(pool + [0]), rng.choice(pool + [0]), rng.choice(pool + [0])
        k = rng.random()
        if k < 0.30:
            f3, f7 = rng.choice([(0, 0), (0, 0x20), (7, 0), (6, 0), (2, 0)])
            prog.append(enc_r(f7, b, a, f3, rd, 0x33))
        elif k < 0.50:
            prog.append(enc_i(rng.randint(-2048, 2047), a, rng.choice([0, 7, 6, 2]), rd, 0x13))
        elif k < 0.58:
            prog.append(enc_u(rng.randint(0, 0xFFFFF), rd))
        elif k < 0.70:
            prog.append(enc_i(rng.randrange(0, 512, 4), 0, 2, rd, 0x03) if rng.random() < 0.7
                        else enc_i(rng.randint(-8, 8) * 4, a, 2, rd, 0x03))
        elif k < 0.82:
            prog.append(enc_s(rng.randrange(0, 512, 4), b, 0, 2, 0x23) if rng.random() < 0.7
                        else enc_s(rng.randint(-8, 8) * 4, b, a, 2, 0x23))
        elif k < 0.94:
            skip = rng.randint(1, 3)
            prog.append(enc_b((skip + 1) * 4, b, a, rng.choice([0, 1])) if i + skip + 1 <= length else NOP)
        else:
            skip = rng.randint(1, 3)
            prog.append(enc_j((skip + 1) * 4, rd) if i + skip + 1 <= length else NOP)
    return prog

def run_iss(prog):
    iss = RV32I_ISS()
    iss.imem[:len(prog)] = prog
    steps = 0
    while iss.pc < len(prog) * 4 and steps < 5000 and iss.step():
        steps += 1
    return iss.regs, iss.dmem

def run_rtl(vvp, hex_path):
    out = subprocess.run(['vvp', vvp, f'+hex={hex_path}'], capture_output=True, text=True).stdout
    regs, mem = [0] * 32, [0] * 128
    for line in out.splitlines():
        m = re.match(r'([RM]) (\d+) ([0-9a-f]{8})', line)
        if m:
            (regs if m.group(1) == 'R' else mem)[int(m.group(2))] = int(m.group(3), 16)
    return regs, mem

def build(tmp):
    src = ['rtl/alu.sv', 'rtl/controller.sv', 'rtl/dmem.sv', 'rtl/imem.sv', 'rtl/reg_file.sv', 'rtl/signextn.sv']
    pipe = sorted(f'pipelined/{f}' for f in os.listdir('pipelined') if f.endswith('.sv'))
    single = ['rtl/datapath.sv']
    subprocess.run(['iverilog', '-g2012', '-Irtl', '-Ipipelined', '-o', f'{tmp}/pipe.vvp'] + src + pipe +
                   ['tests/random/tb_random_pipe.sv'], check=True)
    subprocess.run(['iverilog', '-g2012', '-Irtl', '-o', f'{tmp}/single.vvp'] + src + single +
                   ['tests/random/tb_random_single.sv'], check=True)

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 300
    with tempfile.TemporaryDirectory() as tmp:
        build(tmp)
        fails = {'single-cycle': 0, 'pipelined': 0}
        for seed in range(n):
            prog = gen_program(random.Random(seed))
            hex_path = f'{tmp}/p.hex'
            with open(hex_path, 'w') as f:
                f.write(''.join(f'{w:08x}\n' for w in prog) + ''.join('00000013\n' for _ in range(128 - len(prog))))
            exp = run_iss(prog)
            for name, vvp in (('single-cycle', 'single.vvp'), ('pipelined', 'pipe.vvp')):
                if run_rtl(f'{tmp}/{vvp}', hex_path) != exp:
                    fails[name] += 1
                    print(f'MISMATCH: {name} core, seed {seed}')
        print(f'Random differential test: {n} programs | mismatches: {fails}')
        sys.exit(1 if any(fails.values()) else 0)

if __name__ == '__main__':
    main()
