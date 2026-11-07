# hazard_tests.s: Directed Hazard Unit Verification
# Tests:
#   1. RAW back-to-back forwarding (EX/MEM -> EX and MEM/WB -> EX)
#   2. x0 forwarding suppression (rd=x0 must not forward)
#   3. Load-use stall (1-cycle hardware stall then forward)
#   4. Branch taken after dependent instruction with 2-cycle flush

    # 1. RAW back-to-back forwarding
    addi x1, x0, 10      # x1 = 10
    add  x2, x1, x1      # x2 = 20 (EX/MEM forward)
    add  x3, x2, x1      # x3 = 30 (x2 from EX/MEM, x1 from MEM/WB)

    # 2. x0 forwarding corner case
    add  x0, x1, x2      # rd=x0, result 30 must not forward
    addi x4, x0, 5       # x4 must read 0 from x0, result = 5 (not 35)

    # 3. Load-use hazard with 1-cycle stall
    sw   x3, 0(x0)       # dmem[0] = 30
    lw   x5, 0(x0)       # load 30 into x5
    addi x6, x5, 12      # back-to-back use: requires stall + forward -> x6 = 42 (0x2A)

    # 4. Branch taken after dependent instruction
    addi x7, x0, 15      # x7 = 15
    addi x8, x7, -15     # x8 = 0 (computed right before branch)
    beq  x8, x0, branch_dep_hit
    addi x9, x0, 99      # Must be flushed

branch_dep_hit:
    addi x9, x0, 77      # x9 = 77 (0x4D)
