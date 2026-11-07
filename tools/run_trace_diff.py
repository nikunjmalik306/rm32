#!/usr/bin/env python3
"""
Trace Diff: Compares RTL simulation execution trace against the
Python RV32I ISS Golden Model instruction-by-instruction.
Exits with 0 on exact match; non-zero on mismatch.
"""

import sys
import os

from rv32i_iss import RV32I_ISS

def run_trace_diff(rtl_trace_file, hex_file, max_instructions=None):
    if not os.path.exists(rtl_trace_file):
        print(f"Error: RTL trace file {rtl_trace_file} not found.")
        return False
    if not os.path.exists(hex_file):
        print(f"Error: Hex file {hex_file} not found.")
        return False

    # Read RTL trace
    rtl_steps = []
    with open(rtl_trace_file, 'r') as f:
        for line in f:
            clean = line.strip()
            if not clean:
                continue
            parts = clean.split()
            pc = None
            instr = None
            regs = {}
            for p in parts:
                if p.startswith('PC:'):
                    pc = int(p.split(':')[1], 16)
                elif p.startswith('INSTR:'):
                    instr = int(p.split(':')[1], 16)
                elif '=' in p:
                    reg, val = p.split('=')
                    regs[reg] = int(val, 16)
            if pc is not None and instr is not None:
                rtl_steps.append({'pc': pc, 'instr': instr, 'regs': regs})

    # Run Python ISS
    iss = RV32I_ISS()
    iss.load_imem_hex(hex_file)
    max_steps = max_instructions if max_instructions else len(rtl_steps)
    iss.run(max_steps)

    # Compare step by step
    mismatches = 0
    compare_len = min(len(iss.trace), len(rtl_steps))

    for i in range(compare_len):
        iss_t = iss.trace[i]
        rtl_t = rtl_steps[i]

        if iss_t['pc'] != rtl_t['pc']:
            print(f"Mismatch at step {i}: PC ISS=0x{iss_t['pc']:08x} != RTL=0x{rtl_t['pc']:08x}")
            mismatches += 1
            break

        if iss_t['instr'] != rtl_t['instr']:
            print(f"Mismatch at step {i}: INSTR ISS=0x{iss_t['instr']:08x} != RTL=0x{rtl_t['instr']:08x}")
            mismatches += 1
            break

        # Check register states after execution (at next instruction or end)
        # Verify any non-zero architectural registers match
        if i + 1 < len(rtl_steps):
            next_rtl_regs = rtl_steps[i + 1]['regs']
            for reg_idx in range(1, 32):
                reg_name = f"x{reg_idx}"
                iss_val = iss_t['regs'][reg_idx]
                rtl_val = next_rtl_regs.get(reg_name, 0)
                if iss_val != rtl_val:
                    print(f"Mismatch at step {i} (PC=0x{iss_t['pc']:08x}): {reg_name} ISS=0x{iss_val:08x} != RTL=0x{rtl_val:08x}")
                    mismatches += 1
                    break
        if mismatches > 0:
            break

    if mismatches == 0 and compare_len > 0:
        print(f"SUCCESS: Golden Model ISS and RTL trace match exactly across {compare_len} instructions!")
        return True
    else:
        print(f"FAILED: Trace difference detected ({mismatches} mismatches).")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: run_trace_diff.py <rtl_trace.txt> <program.hex> [max_instructions]")
        sys.exit(1)
    rtl_f = sys.argv[1]
    hex_f = sys.argv[2]
    max_i = int(sys.argv[3]) if len(sys.argv) > 3 else None
    success = run_trace_diff(rtl_f, hex_f, max_i)
    sys.exit(0 if success else 1)
