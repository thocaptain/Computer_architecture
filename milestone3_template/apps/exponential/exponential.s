# e^x on the Milestone 3 DE2 MCU. RV32I only, no M/F/D extensions.
# x is a signed integer in thousandths: 1500 means +1.500.
# Range [-9000,9000]. Result is round(1000*exp(x/1000)).
.option norvc
.option norelax
.option nopic
.section .text
.globl _start, exp_milli
.equ SAMPLE_CYCLES, 500000 # 20 ms at 25 MHz
# RAM: magnitude=0 digits=4 state=8 signed_x=12 result=16 error=20
# candidate=24 stable=28 tick=32. Segment lookup bytes start at 160.
_start:
    lui sp, 0x84000
    addi sp, sp, 1024
    lui s0, 0x84000
    lui s1, 0x40002
    lui s2, 0x40003
    lui s3, 0x40001
    lui s4, 0x40000
    lui s5, 0x40004
    li t0, 0x4f5b063f
    sw t0, 160(s0)
    li t0, 0x077d6d66
    sw t0, 164(s0)
    li t0, 0x00006f7f
    sw t0, 168(s0)
    li t0, 3
    sw t0, 0(s5)
    sw zero, 24(s0)
    sw zero, 28(s0)
    sw zero, 32(s0)
    li s6, 0
    jal ra, fresh
poll:
    lw t0, 4(s5)
    lw t1, 32(s0)
    sub t2, t0, t1
    li t3, SAMPLE_CYCLES
    bltu t2, t3, poll
    sw t0, 32(s0)
    lw s6, 0(s1)
    sw s6, 0(s4)
    lw t0, 0(s2)           # MMIO keys are already active-high
    andi t0, t0, 14
    srli t1, s6, 13
    andi t1, t1, 16        # RUN -> bit 4 of debouncer
    or t0, t0, t1
    lw t1, 24(s0)
    sw t0, 24(s0)
    li s7, 0
    bne t0, t1, sampled
    lw t1, 28(s0)
    xori t2, t1, -1
    and s7, t0, t2
    sw t0, 28(s0)
sampled:
    lw t0, 8(s0)
    li t1, 2
    bne t0, t1, not_result
    lw t0, 28(s0)
    andi t0, t0, 16
    bnez t0, redraw
    jal ra, fresh
    j redraw
not_result:
    bnez t0, ready
    andi t0, s7, 8
    bnez t0, erase
    andi t0, s7, 2
    bnez t0, append
    andi t0, s7, 4
    bnez t0, confirm
    j redraw
append:
    andi t0, s6, 15
    li t1, 9
    bltu t1, t0, bad_digit
    lw t1, 0(s0)
    slli t2, t1, 3
    slli t1, t1, 1
    add t1, t1, t2
    add t1, t1, t0
    li t2, 9000
    bltu t2, t1, bad_range
    lw t2, 4(s0)
    li t3, 4
    bgeu t2, t3, bad_range
    sw t1, 0(s0)
    addi t2, t2, 1
    sw t2, 4(s0)
    sw zero, 20(s0)
    j redraw
bad_digit:
    li t0, 3
    sw t0, 20(s0)
    j redraw
bad_range:
    li t0, 4
    sw t0, 20(s0)
    j redraw
erase:
    lw a0, 0(s0)
    li a1, 0
    li a2, 10
    jal ra, udiv64_32
    sw a0, 0(s0)
    lw t0, 4(s0)
    beqz t0, erase_done
    addi t0, t0, -1
    sw t0, 4(s0)
erase_done:
    sw zero, 20(s0)
    j redraw
confirm:
    lw t0, 0(s0)
    andi t1, s6, 16
    beqz t1, confirm_save
    neg t0, t0
confirm_save:
    sw t0, 12(s0)
    sw zero, 20(s0)
    li t0, 1
    sw t0, 8(s0)
    j redraw
ready:
    andi t0, s7, 16        # fresh stable OFF -> ON only
    beqz t0, redraw
    li t0, 40              # busy + fixed-point indicator
    sw t0, 4(s4)
    lw a0, 12(s0)
    jal ra, exp_milli
    sw a0, 16(s0)
    sw a1, 20(s0)
    li t0, 2
    sw t0, 8(s0)
redraw:
    jal ra, render
    j poll
fresh:
    sw zero, 0(s0)
    sw zero, 4(s0)
    sw zero, 8(s0)
    sw zero, 12(s0)
    sw zero, 16(s0)
    sw zero, 20(s0)
    ret

# exp_milli(a0=signed thousandths) -> a0=result thousandths, a1=error.
# Range reduction in Q32: x = n*ln(2) + r, 0 <= r < ln(2).
# e^r uses 18 Taylor terms in unsigned Q48, with software 64-bit arithmetic.
# Final round-to-nearest happens once, after scaling by 1000 and 2^n.
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

# Display signed input / unsigned result as I-FFF, '-' is decimal separator.
# Input sign lives at HEX7; input integer is <=9, so no collision.
render:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s6, 24(sp)
    sw s7, 20(sp)
    sw s8, 16(sp)
    sw s9, 12(sp)
    sw s10, 8(sp)
    sw s11, 4(sp)
    li t0, 0
render_clear:
    add t1, s3, t0
    sw zero, 0(t1)
    addi t0, t0, 4
    li t1, 32
    bltu t0, t1, render_clear
    lw t0, 8(s0)
    li s11, 1
    sll s11, s11, t0
    ori s11, s11, 32
    lw t1, 20(s0)
    bnez t1, render_error
    li t1, 2
    beq t0, t1, render_result
    bnez t0, render_saved
    lw s6, 0(s0)
    lw t0, 24(sp)
    andi t0, t0, 16
    beqz t0, render_split
    j render_negative
render_saved:
    lw s6, 12(s0)
    bgez s6, render_split
    neg s6, s6
render_negative:
    li t0, 0x40
    sw t0, 28(s3)
    ori s11, s11, 64
    j render_split
render_result:
    lw s6, 16(s0)
render_split:
    mv a0, s6
    li a1, 0
    li a2, 1000
    jal ra, udiv64_32
    mv s6, a0              # integer part
    mv s7, a2              # fractional part
    li s8, 0
    addi s9, s0, 160
render_fraction:
    mv a0, s7
    li a1, 0
    li a2, 10
    jal ra, udiv64_32
    mv s7, a0
    add t0, s9, a2
    lbu t1, 0(t0)
    slli t0, s8, 2
    add t0, s3, t0
    sw t1, 0(t0)
    addi s8, s8, 1
    li t0, 3
    bltu s8, t0, render_fraction
    li t0, 0x40
    sw t0, 12(s3)          # HEX3 separates integer and fraction
    li s8, 4
render_integer:
    mv a0, s6
    li a1, 0
    li a2, 10
    jal ra, udiv64_32
    mv s6, a0
    add t0, s9, a2
    lbu t1, 0(t0)
    slli t0, s8, 2
    add t0, s3, t0
    sw t1, 0(t0)
    addi s8, s8, 1
    bnez s6, render_integer
    j render_done
render_error:
    ori s11, s11, 128
    addi t2, s0, 160
    add t2, t2, t1
    lbu t2, 0(t2)
    sw t2, 0(s3)
    li t2, 0x50
    sw t2, 8(s3)
    sw t2, 12(s3)
    li t2, 0x79
    sw t2, 16(s3)
render_done:
    sw s11, 4(s4)
    lw ra, 28(sp)
    lw s6, 24(sp)
    lw s7, 20(sp)
    lw s8, 16(sp)
    lw s9, 12(sp)
    lw s10, 8(sp)
    lw s11, 4(sp)
    addi sp, sp, 32
    ret
