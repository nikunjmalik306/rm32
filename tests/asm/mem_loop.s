# mem_loop.s: Memory store and load round-trip in a loop
# Stores values [10, 20, 30, 40] into memory addresses [0, 4, 8, 12]
# Then iterates over memory to load and accumulate their sum: 100 (0x64)
# Expected Result:
#   x5 (sum) = 100 (0x00000064)
#   x7 (verified readback) = 100 (0x00000064)

    addi x1, x0, 10      # val0 = 10
    addi x2, x0, 20      # val1 = 20
    addi x3, x0, 30      # val2 = 30
    addi x4, x0, 40      # val3 = 40

    sw   x1, 0(x0)       # dmem[0] = 10
    sw   x2, 4(x0)       # dmem[1] = 20
    sw   x3, 8(x0)       # dmem[2] = 30
    sw   x4, 12(x0)      # dmem[3] = 40

    addi x5, x0, 0       # accum = 0
    addi x6, x0, 0       # offset = 0
    addi x8, x0, 16      # end offset = 16

read_loop:
    lw   x9, 0(x6)       # x9 = mem[offset]
    add  x5, x5, x9      # accum += x9
    addi x6, x6, 4       # offset += 4
    bne  x6, x8, read_loop

    sw   x5, 16(x0)      # store total sum (100) at dmem[4]
    lw   x7, 16(x0)      # reload to x7
