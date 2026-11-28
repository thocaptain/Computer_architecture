# sincos_milli: a0=angle in milli-degrees -> a0=sin*1000, a1=cos*1000.
# CORDIC uses signed Q30 x/y and binary-turn Q32 angles, 30 iterations.
# atan table is initialized in DMEM at 0x84000080; data cannot be read from IMEM.
sincos_milli:
    addi sp, sp, -64
    sw ra, 60(sp)
    sw s2, 56(sp)
    sw s6, 52(sp)
    sw s7, 48(sp)
    sw s8, 44(sp)
    sw s9, 40(sp)
    sw s10, 36(sp)
    sw s11, 32(sp)
    sw a0, 8(sp)
    bgez a0, trig_abs
    neg a0, a0
trig_abs:
    li a1, 0
    li a2, 360000
    jal ra, udiv64_32
    mv t0, a2
    lw t1, 8(sp)
    bgez t1, trig_signed
    neg t0, t0
trig_signed:
    li t1, 180000
    bge t1, t0, trig_negative_wrap
    li t1, 360000
    sub t0, t0, t1
trig_negative_wrap:
    li t1, -180000
    bge t0, t1, trig_fold
    li t1, 360000
    add t0, t0, t1
trig_fold:
    li s6, 1             # cosine sign after folding into [-90,90] degrees.
    li t1, 90000
    bge t1, t0, trig_fold_negative
    li t1, 180000
    sub t0, t1, t0
    li s6, -1
trig_fold_negative:
    li t1, -90000
    bge t0, t1, trig_angle
    li t1, -180000
    sub t0, t1, t0
    li s6, -1
trig_angle:
    sw t0, 12(sp)
    bgez t0, trig_angle_abs
    neg t0, t0
trig_angle_abs:
    # abs(angle)*2^30/90000 == abs(angle)*2^32/360000.
    slli a0, t0, 30
    srli a1, t0, 2
    li a2, 90000
    jal ra, udiv64_32
    lw t0, 12(sp)
    bgez t0, trig_angle_ready
    neg a0, a0
trig_angle_ready:
    mv s10, a0
    li s8, 652032874     # round(CORDIC gain compensation * 2^30).
    li s9, 0
    li s11, 0
    lui s2, 0x84000
    addi s2, s2, 128
cordic_loop:
    sra t0, s8, s11
    sra t1, s9, s11
    slli t2, s11, 2
    add t2, s2, t2
    lw t3, 0(t2)
    bltz s10, cordic_negative
    sub s8, s8, t1
    add s9, s9, t0
    sub s10, s10, t3
    j cordic_next
cordic_negative:
    add s8, s8, t1
    sub s9, s9, t0
    add s10, s10, t3
cordic_next:
    addi s11, s11, 1
    li t0, 30
    bltu s11, t0, cordic_loop
    bgez s6, trig_convert
    neg s8, s8
trig_convert:
    mv a0, s9
    jal ra, q30_to_milli
    sw a0, 0(sp)
    mv a0, s8
    jal ra, q30_to_milli
    mv a1, a0
    lw a0, 0(sp)
    lw ra, 60(sp)
    lw s2, 56(sp)
    lw s6, 52(sp)
    lw s7, 48(sp)
    lw s8, 44(sp)
    lw s9, 40(sp)
    lw s10, 36(sp)
    lw s11, 32(sp)
    addi sp, sp, 64
    ret

# Signed Q30 -> signed thousandths, round nearest (ties away from zero).
q30_to_milli:
    addi sp, sp, -16
    sw ra, 12(sp)
    slt t0, a0, zero
    sw t0, 8(sp)
    bgez a0, q30_abs
    neg a0, a0
q30_abs:
    li a1, 1000
    jal ra, mul_u32
    li t0, 0x20000000
    add t1, a0, t0
    sltu t2, t1, a0
    add a1, a1, t2
    srli t1, t1, 30
    slli a1, a1, 2
    or a0, t1, a1
    lw t0, 8(sp)
    beqz t0, q30_done
    neg a0, a0
q30_done:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret
