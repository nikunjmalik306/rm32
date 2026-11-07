# sum10.s: Computes sum of integers 1 to 10
# Expected Result:
#   x1 (count)  = 11
#   x2 (sum)    = 55 (0x00000037)
#   dmem[0]     = 55 (0x00000037)
#   x3 (loaded) = 55 (0x00000037)

    addi x1, x0, 1       # i = 1
    addi x2, x0, 0       # sum = 0
    addi x4, x0, 11      # limit = 11

loop:
    add  x2, x2, x1      # sum += i
    addi x1, x1, 1       # i++
    bne  x1, x4, loop    # if i != 11 goto loop

    sw   x2, 0(x0)       # dmem[0] = sum (55)
    lw   x3, 0(x0)       # x3 = dmem[0]
