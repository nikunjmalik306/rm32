# edge_cases.s: Comprehensive instruction-class and corner-case verification
# Tests:
#   1. x0 write protection (remains 0)
#   2. SLT / SLTI signed comparisons (negative vs positive)
#   3. Negative immediate sign extension
#   4. Logical AND, OR, ANDI, ORI
#   5. Subtraction producing zero
#   6. Branch taken (BEQ) and not taken (BNE)
#   7. LUI 20-bit upper immediate loading
#   8. JAL link register write and forward jump

    # 1. x0 write test
    addi x0, x0, 100     # attempt x0 write
    lui  x0, 0xABCDE     # attempt x0 write

    # 2. Signed comparison (SLT / SLTI)
    addi x10, x0, -5     # x10 = -5 (0xFFFFFFFB)
    addi x11, x0, 5      # x11 = +5 (0x00000005)
    slt  x12, x10, x11   # -5 < 5 -> x12 = 1
    slt  x13, x11, x10   # 5 < -5 -> x13 = 0
    slti x14, x10, 0     # -5 < 0 -> x14 = 1
    slti x15, x11, 0     # 5 < 0  -> x15 = 0

    # 3. Negative immediate addition
    addi x16, x11, -10   # 5 + (-10) = -5 (0xFFFFFFFB)

    # 4. Bitwise logic
    addi x17, x0, 15     # 0x0F
    addi x18, x0, 5      # 0x05
    and  x19, x17, x18   # 0x0F & 0x05 = 0x05
    or   x20, x17, x18   # 0x0F | 0x05 = 0x0F
    andi x21, x17, 3     # 0x0F & 0x03 = 0x03
    ori  x22, x18, 2     # 0x05 | 0x02 = 0x07

    # 5. Subtraction
    sub  x23, x11, x18   # 5 - 5 = 0

    # 6. Branch taken (BEQ)
    beq  x11, x18, beq_hit
    addi x24, x0, 99     # Should be skipped

beq_hit:
    addi x24, x0, 1      # x24 = 1

    # Branch not taken (BNE: 5 != 5 is false)
    bne  x11, x18, bne_bad
    addi x25, x0, 1      # x25 = 1 (reached because BNE was not taken)
    beq  x0, x0, bne_ok
bne_bad:
    addi x25, x0, 99     # Skipped
bne_ok:

    # 7. LUI upper bits
    lui  x26, 0x12345    # x26 = 0x12345000

    # 8. JAL link and jump
    jal  x1, jal_target  # x1 gets link address, jumps to target
    addi x27, x0, 99     # Skipped by JAL

jal_target:
    addi x27, x0, 42     # x27 = 42 (0x2A)
