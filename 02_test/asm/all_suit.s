# all_suites.s - all 8 classic-algorithm suites in ONE program
#   1 sum_array   2 factorial   3 fibonacci   4 gcd/divu
#   5 bubble_sort 6 prime_sieve 7 matrix_mul  8 bit_ops
#
# Size      : ~248 words -> fits the 256-word instruction memory (INST_MEM_ADDR_W = 10).
#             Only one or two key checks are kept per suite; the per-suite files have the full sets.
#             Addresses use lui (1 word); no la/call/.data, only PC-relative jumps.
# Report    : PASS -> LEDR = 0x00003FFF, LEDG = 0x600D
#             FAIL -> LEDR = check id 0xSN (S = suite 1..8, N = check), LEDG = 0x0BAD
# Expected  : LEDR[13:0] = 1 for all 14 checks passed
# Registers : s0 = data base 0x2000, s10 = current check id

main:
    lui  sp, 0x4                # sp = 0x4000 (top of data memory)
    lui  s0, 0x2                # s0 = 0x2000 (data base, shared by all suites)

#=== 1. sum_array: store 1..100, load back and sum ===================
    li   s10, 0x11              # 0x11: sum(1..100) = 5050
    li   t0, 1
    li   t1, 101
    mv   t2, s0
S1_FILL:
    sw   t0, 0(t2)
    addi t0, t0, 1
    addi t2, t2, 4
    bne  t0, t1, S1_FILL
    li   a0, 0
    li   t0, 100
    mv   t2, s0
S1_SUM:
    lw   t3, 0(t2)
    add  a0, a0, t3             # load-use hazard
    addi t2, t2, 4
    addi t0, t0, -1
    bnez t0, S1_SUM
    li   t0, 5050
    bne  a0, t0, FAIL

#=== 2. factorial: recursive, software MUL ===========================
    li   s10, 0x21              # 0x21: 12! = 479001600
    li   a0, 12
    jal  ra, FACT
    li   t0, 479001600
    bne  a0, t0, FAIL

#=== 3. fibonacci: double recursion ==================================
    li   s10, 0x31              # 0x31: fib(15) = 610
    li   a0, 15
    jal  ra, FIB
    li   t0, 610
    bne  a0, t0, FAIL
    li   s10, 0x32              # 0x32: stack balanced after FACT + FIB
    lui  t0, 0x4
    bne  sp, t0, FAIL

#=== 4. gcd: software unsigned divide + Euclid =======================
    li   s10, 0x41              # 0x41: 0xFFFFFFFF / 10 = 429496729, rem 5
    li   a0, -1
    li   a1, 10
    jal  ra, DIVU
    li   t0, 429496729
    bne  a0, t0, FAIL
    li   t0, 5
    bne  a1, t0, FAIL
    li   s10, 0x42              # 0x42: gcd(1071, 462) = 21
    li   a0, 1071
    li   a1, 462
S4_GCD:
    beqz a1, S4_END
    mv   t4, a1                 # t4 = b (DIVU keeps t4)
    jal  ra, DIVU               # a1 = a % b
    mv   a0, t4                 # a = b
    j    S4_GCD
S4_END:
    li   t0, 21
    bne  a0, t0, FAIL

#=== 5. bubble_sort: 8 signed words, worst case (descending) =========
    li   t0, 5                  # a[] = 5 3 1 -1 -3 -5 -7 -9
    li   t1, 8
    mv   t2, s0
S5_FILL:
    sw   t0, 0(t2)
    addi t0, t0, -2
    addi t2, t2, 4
    addi t1, t1, -1
    bnez t1, S5_FILL
    li   t0, 7                  # compares in this pass (n-1 .. 1)
S5_OUTER:
    mv   t2, s0
    mv   t1, t0
S5_INNER:
    lw   t4, 0(t2)
    lw   t5, 4(t2)
    ble  t4, t5, S5_NOSWAP      # signed compare
    sw   t5, 0(t2)
    sw   t4, 4(t2)
S5_NOSWAP:
    addi t2, t2, 4
    addi t1, t1, -1
    bnez t1, S5_INNER
    addi t0, t0, -1
    bnez t0, S5_OUTER
    li   s10, 0x51              # 0x51: a[i] <= a[i+1] for all i
    mv   t2, s0
    li   t1, 7
S5_CHK:
    lw   t4, 0(t2)
    lw   t5, 4(t2)
    bgt  t4, t5, FAIL
    addi t2, t2, 4
    addi t1, t1, -1
    bnez t1, S5_CHK
    li   s10, 0x52              # 0x52: a[0] = -9
    lw   t4, 0(s0)
    li   t0, -9
    bne  t4, t0, FAIL

#=== 6. prime_sieve: Eratosthenes 2..100 on a byte array =============
    li   s1, 100                # N
    li   t0, 0
S6_CLR:
    add  t1, s0, t0
    sb   zero, 0(t1)
    addi t0, t0, 1
    ble  t0, s1, S6_CLR
    li   t0, 2                  # i
    li   t4, 1
    li   t6, 10                 # sqrt(N)
S6_I:
    bgt  t0, t6, S6_COUNT
    add  t1, s0, t0
    lbu  t2, 0(t1)
    bnez t2, S6_NEXT            # already composite
    add  t3, t0, t0             # j = 2i
S6_MARK:
    bgt  t3, s1, S6_NEXT
    add  t1, s0, t3
    sb   t4, 0(t1)
    add  t3, t3, t0
    j    S6_MARK
S6_NEXT:
    addi t0, t0, 1
    j    S6_I
S6_COUNT:
    li   a0, 0                  # prime count
    li   a1, 0                  # largest prime
    li   t0, 2
S6_CNT:
    add  t1, s0, t0
    lbu  t2, 0(t1)
    bnez t2, S6_SKIP
    addi a0, a0, 1
    mv   a1, t0
S6_SKIP:
    addi t0, t0, 1
    ble  t0, s1, S6_CNT
    li   s10, 0x61              # 0x61: 25 primes <= 100
    li   t0, 25
    bne  a0, t0, FAIL
    li   s10, 0x62              # 0x62: largest prime = 97
    li   t0, 97
    bne  a1, t0, FAIL
    li   s10, 0x63              # 0x63: word view of flag[4..7] = 01 00 01 00
    lw   t2, 4(s0)
    li   t0, 0x00010001
    bne  t2, t0, FAIL

#=== 7. matrix_mul: 3x3, A = [1..9], B = [9..1] =======================
    addi s1, s0, 36             # B = A + 36
    li   t0, 1                  # A[idx] = idx + 1
    li   t1, 9                  # B[idx] = 9 - idx
    mv   t2, s0
S7_INIT:
    sw   t0, 0(t2)
    sw   t1, 36(t2)
    addi t0, t0, 1
    addi t2, t2, 4
    addi t1, t1, -1
    bnez t1, S7_INIT
    mv   s3, s0                 # &A[i][0]
    li   s5, 0                  # sum of all C[i][j]
S7_I:
    li   s4, 0                  # j * 4
S7_J:
    mv   s6, s3                 # &A[i][k]
    add  s7, s1, s4             # &B[k][j]
    li   t2, 3                  # k (MUL keeps t2/t3)
S7_K:
    lw   a0, 0(s6)
    lw   a1, 0(s7)
    jal  ra, MUL
    add  s5, s5, a0
    addi s6, s6, 4
    addi s7, s7, 12
    addi t2, t2, -1
    bnez t2, S7_K
    addi s4, s4, 4
    li   t3, 12
    blt  s4, t3, S7_J
    addi s3, s3, 12
    blt  s3, s1, S7_I           # A rows end where B starts
    li   s10, 0x71              # 0x71: sum(C) = 621
    li   t0, 621
    bne  s5, t0, FAIL

#=== 8. bit_ops: popcount (Kernighan) + 32-bit reverse ===============
    li   s10, 0x81              # 0x81: popcount(0xDEADBEEF) = 24
    li   a0, 0xDEADBEEF
    li   t0, 0
S8_POP:
    beqz a0, S8_POP_END
    addi t1, a0, -1
    and  a0, a0, t1             # clear lowest set bit
    addi t0, t0, 1
    j    S8_POP
S8_POP_END:
    li   t1, 24
    bne  t0, t1, FAIL
    li   s10, 0x82              # 0x82: bitrev(0x12345678) = 0x1E6A2C48
    li   a0, 0x12345678
    li   t0, 0
    li   t1, 32
S8_REV:
    slli t0, t0, 1
    andi t2, a0, 1
    or   t0, t0, t2
    srli a0, a0, 1
    addi t1, t1, -1
    bnez t1, S8_REV
    li   t1, 0x1E6A2C48
    bne  t0, t1, FAIL

#=== report ==========================================================
PASS:
    li   s10, 0x3FFF            # all 14 checks passed; one LED per check
    li   t1, 0x600D
    j    REPORT
FAIL:
    li   t1, 0x0BAD
REPORT:
    lui  t0, 0x7                # 0x7000
    sw   s10, 0(t0)             # LEDR = 0xFF or failing check id
    sw   t1, 16(t0)             # LEDG (0x7010) = status, written last
DONE:
    j    DONE

#=== subroutines =====================================================
# FIB: a0 = fib(a0), recursive, clobbers t0
FIB:
    li   t0, 2
    blt  a0, t0, FIB_RET        # fib(0) = 0, fib(1) = 1
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   a0, 0(sp)              # save n
    addi a0, a0, -1
    jal  ra, FIB
    lw   t0, 0(sp)              # t0 = n
    sw   a0, 0(sp)              # save fib(n-1)
    addi a0, t0, -2
    jal  ra, FIB
    lw   t0, 0(sp)
    add  a0, a0, t0             # fib(n-2) + fib(n-1)
    lw   ra, 4(sp)
    addi sp, sp, 8
FIB_RET:
    ret

# FACT: a0 = a0!, recursive, tail-calls MUL (falls through), clobbers t0, t1, a1
FACT_BASE:
    li   a0, 1
    ret
FACT:
    li   t0, 2
    blt  a0, t0, FACT_BASE
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   a0, 0(sp)
    addi a0, a0, -1
    jal  ra, FACT               # a0 = (n-1)!
    lw   a1, 0(sp)              # a1 = n
    lw   ra, 4(sp)
    addi sp, sp, 8              # fall through: MUL returns to FACT's caller

# MUL: a0 = a0 * a1 (low 32 bits), shift-add, clobbers t0, t1, a1
MUL:
    li   t0, 0
MUL_LOOP:
    beqz a1, MUL_END
    andi t1, a1, 1
    beqz t1, MUL_SKIP
    add  t0, t0, a0
MUL_SKIP:
    slli a0, a0, 1
    srli a1, a1, 1
    j    MUL_LOOP
MUL_END:
    mv   a0, t0
    ret

# DIVU: a0 = a0 / a1, a1 = a0 % a1 (unsigned restoring), clobbers t1-t3
#       quotient bits are shifted into a0 as the dividend shifts out
DIVU:
    li   t1, 0                  # remainder
    li   t2, 32
DIV_LOOP:
    slli t1, t1, 1
    srli t3, a0, 31
    or   t1, t1, t3             # rem = (rem << 1) | msb(a0)
    slli a0, a0, 1
    bltu t1, a1, DIV_SKIP
    sub  t1, t1, a1
    ori  a0, a0, 1
DIV_SKIP:
    addi t2, t2, -1
    bnez t2, DIV_LOOP
    mv   a1, t1
    ret
