# Extracted unchanged from ../exponential/exponential.s
exp_milli:
    li t0, 9000
    blt t0, a0, exp_range_error
    li t0, -9000
    blt a0, t0, exp_range_error
    addi sp, sp, -64
    sw ra, 60(sp)
    sw s6, 56(sp)
    sw s7, 52(sp)
    sw s8, 48(sp)
    sw s9, 44(sp)
    sw s10, 40(sp)
    sw s11, 36(sp)
    sw a0, 4(sp)
    bgez a0, exp_abs
    neg a0, a0
exp_abs:
    mv a1, a0              # numerator = abs(x_milli) * 2^32
    li a0, 0
    li a2, 1000
    jal ra, udiv64_32
    li s7, 0
    li t0, 0xb17217f8      # round(ln(2) * 2^32)
exp_reduce:
    bnez a1, exp_sub_ln2
    bltu a0, t0, exp_reduced
exp_sub_ln2:
    sltu t1, a0, t0
    sub a0, a0, t0
    sub a1, a1, t1
    addi s7, s7, 1
    j exp_reduce
exp_reduced:
    lw t1, 4(sp)
    bgez t1, exp_positive_r
    neg s7, s7
    beqz a0, exp_positive_r
    sub a0, t0, a0
    addi s7, s7, -1
exp_positive_r:
    mv s6, a0              # r, unsigned Q32
    li s8, 0               # term low
    li s9, 65536           # term high: 1.0 in Q48
    li s10, 0              # sum low
    li s11, 65536          # sum high
    li t0, 1
    sw t0, 0(sp)
exp_series:
    mv a0, s8
    mv a1, s9
    mv a2, s6
    jal ra, mul_q32
    lw a2, 0(sp)
    jal ra, udiv64_32
    mv s8, a0
    mv s9, a1
    add t0, s10, s8
    sltu t1, t0, s10
    mv s10, t0
    add s11, s11, s9
    add s11, s11, t1
    or t0, s8, s9
    beqz t0, exp_scale
    lw t0, 0(sp)
    addi t0, t0, 1
    sw t0, 0(sp)
    li t1, 18
    bgeu t1, t0, exp_series
exp_scale:
    mv a0, s10
    mv a1, s11
    li a2, 1000
    jal ra, mul64_u32
    # Shift right by 48-n (36..61). Add rounding bit at 47-n first.
    # Both rounding bit and final result are in the product's high word.
    li t0, 15
    sub t0, t0, s7
    li t1, 1
    sll t1, t1, t0
    add a1, a1, t1
    addi t0, t0, 1
    srl a0, a1, t0
    li a1, 0
    lw ra, 60(sp)
    lw s6, 56(sp)
    lw s7, 52(sp)
    lw s8, 48(sp)
    lw s9, 44(sp)
    lw s10, 40(sp)
    lw s11, 36(sp)
    addi sp, sp, 64
    ret
exp_range_error:
    li a0, 0
    li a1, 4
    ret

# Unsigned 32x32 -> 64-bit product a1:a0. Clobbers t0..t6.
mul_u32:
    mv t2, a0
    li t3, 0
    li t0, 0
    li t1, 0
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
    mv a0, t0
    mv a1, t1
    ret

# floor((a1:a0)*a2 / 2^32) -> a1:a0. Intermediate is 96 bits.
mul_q32:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw a1, 24(sp)
    sw a2, 20(sp)
    mv a1, a2
    jal ra, mul_u32
    sw a1, 16(sp)
    lw a0, 24(sp)
    lw a1, 20(sp)
    jal ra, mul_u32
    lw t0, 16(sp)
    add t1, a0, t0
    sltu t2, t1, a0
    mv a0, t1
    add a1, a1, t2
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

# Low 64 bits of (a1:a0)*a2 -> a1:a0. No overflow for this application.
mul64_u32:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw a1, 24(sp)
    sw a2, 20(sp)
    mv a1, a2
    jal ra, mul_u32
    sw a0, 16(sp)
    sw a1, 12(sp)
    lw a0, 24(sp)
    lw a1, 20(sp)
    jal ra, mul_u32
    lw t0, 12(sp)
    add a1, a0, t0
    lw a0, 16(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

# (a1:a0)/a2 -> quotient a1:a0, remainder a2.
# Divisor must be nonzero. Full unsigned 64/32 division with carry-aware remainder.
udiv64_32:
    mv t0, a0
    mv t1, a1
    mv t2, a2
    li t3, 0               # remainder
    li t4, 64
    li a0, 0
    li a1, 0
divide_loop:
    srli t5, t1, 31
    srli t6, t0, 31
    slli t0, t0, 1
    slli t1, t1, 1
    or t1, t1, t6
    srli t6, t3, 31        # carry from remainder shift
    slli t3, t3, 1
    or t3, t3, t5
    srli t5, a0, 31
    slli a0, a0, 1
    slli a1, a1, 1
    or a1, a1, t5
    bnez t6, divide_subtract
    bltu t3, t2, divide_next
divide_subtract:
    sub t3, t3, t2
    ori a0, a0, 1
divide_next:
    addi t4, t4, -1
    bnez t4, divide_loop
    mv a2, t3
    ret
