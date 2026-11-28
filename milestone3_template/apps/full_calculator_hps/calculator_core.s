# Extracted unchanged from ../full_calculator/full_calculator.s
calculate:
    beqz a2, calc_add
    li t0, 1
    beq a2, t0, calc_sub
    li t0, 2
    beq a2, t0, calc_mul
    beqz a1, divide_zero
    li t0, 0x80000000
    bne a0, t0, divide_valid
    li t0, -1
    beq a1, t0, calc_overflow
divide_valid:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    xor t0, a0, a1
    sw t0, 4(sp)
    bgez a0, div_abs_b
    neg a0, a0
div_abs_b:
    bgez a1, div_unsigned
    neg a1, a1
div_unsigned:
    jal ra, udiv32
    lw t0, 4(sp)
    bgez t0, div_rem_sign
    neg a0, a0
div_rem_sign:
    lw t0, 8(sp)
    bgez t0, div_return
    neg a1, a1
div_return:
    li a2, 0
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
calc_add:
    add t0, a0, a1
    xor t1, a0, a1
    bltz t1, calc_good
    xor t1, a0, t0
    bltz t1, calc_overflow
    j calc_good
calc_sub:
    sub t0, a0, a1
    xor t1, a0, a1
    bgez t1, calc_good
    xor t1, a0, t0
    bltz t1, calc_overflow
calc_good:
    mv a0, t0
    li a1, 0
    li a2, 0
    ret
calc_mul:
    xor a5, a0, a1          # desired sign
    bgez a0, mul_abs_b
    neg a0, a0
mul_abs_b:
    bgez a1, mul_begin
    neg a1, a1
mul_begin:
    li t0, 0               # 64-bit product t1:t0
    li t1, 0
    mv t2, a0              # 64-bit multiplicand t3:t2
    li t3, 0
    li t4, 32
mul_loop:
    andi t5, a1, 1
    beqz t5, mul_shift
    add t6, t0, t2
    sltu t5, t6, t0
    mv t0, t6
    add t1, t1, t3
    add t1, t1, t5
mul_shift:
    srli t5, t2, 31
    slli t2, t2, 1
    slli t3, t3, 1
    or t3, t3, t5
    srli a1, a1, 1
    addi t4, t4, -1
    bnez t4, mul_loop
    bnez t1, calc_overflow
    li t2, 0x7fffffff
    bgez a5, mul_limit
    li t2, 0x80000000
mul_limit:
    bltu t2, t0, calc_overflow
    bgez a5, calc_good
    neg t0, t0
    j calc_good
divide_zero:
    li a2, 1
    j calc_error
calc_overflow:
    li a2, 2
calc_error:
    li a0, 0
    li a1, 0
    ret

# Unsigned binary long division. Precondition a1 != 0.
# a0=quotient, a1=remainder; clobbers t0..t5 only, no M extension.
udiv32:
    mv t0, a0
    mv t1, a1
    li t2, 0
    li t3, 0
    li t4, 32
udiv_loop:
    srli t5, t0, 31
    slli t0, t0, 1
    slli t3, t3, 1
    or t3, t3, t5
    slli t2, t2, 1
    bltu t3, t1, udiv_next
    sub t3, t3, t1
    ori t2, t2, 1
udiv_next:
    addi t4, t4, -1
    bnez t4, udiv_loop
    mv a0, t2
    mv a1, t3
    ret
