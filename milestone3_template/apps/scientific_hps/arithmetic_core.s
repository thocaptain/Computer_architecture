# Reused calculator routines; labels namespaced.
arith_calculate:
    beqz a2, arith_calc_add
    li t0, 1
    beq a2, t0, arith_calc_sub
    li t0, 2
    beq a2, t0, arith_calc_mul
    beqz a1, arith_divide_zero
    li t0, 0x80000000
    bne a0, t0, arith_divide_valid
    li t0, -1
    beq a1, t0, arith_calc_overflow
arith_divide_valid:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    xor t0, a0, a1
    sw t0, 4(sp)
    bgez a0, arith_div_abs_b
    neg a0, a0
arith_div_abs_b:
    bgez a1, arith_div_unsigned
    neg a1, a1
arith_div_unsigned:
    jal ra, arith_udiv32
    lw t0, 4(sp)
    bgez t0, arith_div_rem_sign
    neg a0, a0
arith_div_rem_sign:
    lw t0, 8(sp)
    bgez t0, arith_div_return
    neg a1, a1
arith_div_return:
    li a2, 0
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
arith_calc_add:
    add t0, a0, a1
    xor t1, a0, a1
    bltz t1, arith_calc_good
    xor t1, a0, t0
    bltz t1, arith_calc_overflow
    j arith_calc_good
arith_calc_sub:
    sub t0, a0, a1
    xor t1, a0, a1
    bgez t1, arith_calc_good
    xor t1, a0, t0
    bltz t1, arith_calc_overflow
arith_calc_good:
    mv a0, t0
    li a1, 0
    li a2, 0
    ret
arith_calc_mul:
    xor a5, a0, a1          # desired sign
    bgez a0, arith_mul_abs_b
    neg a0, a0
arith_mul_abs_b:
    bgez a1, arith_mul_begin
    neg a1, a1
arith_mul_begin:
    li t0, 0               # 64-bit product t1:t0
    li t1, 0
    mv t2, a0              # 64-bit multiplicand t3:t2
    li t3, 0
    li t4, 32
arith_mul_loop:
    andi t5, a1, 1
    beqz t5, arith_mul_shift
    add t6, t0, t2
    sltu t5, t6, t0
    mv t0, t6
    add t1, t1, t3
    add t1, t1, t5
arith_mul_shift:
    srli t5, t2, 31
    slli t2, t2, 1
    slli t3, t3, 1
    or t3, t3, t5
    srli a1, a1, 1
    addi t4, t4, -1
    bnez t4, arith_mul_loop
    bnez t1, arith_calc_overflow
    li t2, 0x7fffffff
    bgez a5, arith_mul_limit
    li t2, 0x80000000
arith_mul_limit:
    bltu t2, t0, arith_calc_overflow
    bgez a5, arith_calc_good
    neg t0, t0
    j arith_calc_good
arith_divide_zero:
    li a2, 1
    j arith_calc_error
arith_calc_overflow:
    li a2, 2
arith_calc_error:
    li a0, 0
    li a1, 0
    ret

# Unsigned binary long division. Precondition a1 != 0.
# a0=quotient, a1=remainder; clobbers t0..t5 only, no M extension.
arith_udiv32:
    mv t0, a0
    mv t1, a1
    li t2, 0
    li t3, 0
    li t4, 32
arith_udiv_loop:
    srli t5, t0, 31
    slli t0, t0, 1
    slli t3, t3, 1
    or t3, t3, t5
    slli t2, t2, 1
    bltu t3, t1, arith_udiv_next
    sub t3, t3, t1
    ori t2, t2, 1
arith_udiv_next:
    addi t4, t4, -1
    bnez t4, arith_udiv_loop
    mv a0, t2
    mv a1, t3
    ret
