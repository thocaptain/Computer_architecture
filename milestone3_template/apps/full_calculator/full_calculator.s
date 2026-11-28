# DE2 signed 32-bit calculator, pure RV32I. See README.md for controls.
.option norvc
.option norelax
.option nopic
.section .text
.globl _start, calculate, udiv32
.equ SAMPLE_CYCLES, 500000 # 20 ms at wrapper default 25 MHz
# DMEM words: A=0 B=4 state=8 magnitude=12 digits=16 op=24
# result=28 remainder=32 error=36 page=40 remainder_view=44
# candidate_keys=52 stable_keys=56 previous_tick=60. Decimal buffer=128.
_start:
    lui sp, 0x84000
    addi sp, sp, 1024
    lui s0, 0x84000
    lui s1, 0x40002
    lui s2, 0x40003
    lui s3, 0x40001
    lui s4, 0x40000
    lui s5, 0x40004
    # The data bus cannot read IMEM: put the segment lookup table in DMEM.
    li t0, 0x4f5b063f
    sw t0, 160(s0)
    li t0, 0x077d6d66
    sw t0, 164(s0)
    li t0, 0x00006f7f
    sw t0, 168(s0)
    li t0, 3
    sw t0, 0(s5)             # enable + clear cycle counter
    sw zero, 52(s0)
    sw zero, 56(s0)
    sw zero, 60(s0)
    li s6, 0
    jal ra, fresh

poll:
    lw t0, 4(s5)
    lw t1, 60(s0)
    sub t2, t0, t1
    li t3, SAMPLE_CYCLES
    bltu t2, t3, poll
    sw t0, 60(s0)
    lw s6, 0(s1)
    sw s6, 0(s4)             # mirror physical switches on red LEDs
    lw t0, 0(s2)
    andi t0, t0, 14          # KEY MMIO already inverts physical active-low pins
    srli t1, s6, 13
    andi t1, t1, 16          # RUN becomes bit 4
    or t0, t0, t1
    lw t1, 52(s0)
    sw t0, 52(s0)
    li s7, 0
    bne t0, t1, sampled
    lw t1, 56(s0)
    xori t2, t1, -1
    and s7, t0, t2           # new stable presses / rising RUN
    sw t0, 56(s0)
sampled:
    lw t0, 56(s0)
    andi s8, t0, 16
    lw t0, 8(s0)
    li t1, 3
    bne t0, t1, not_result
    beqz s8, start_again
    andi t0, s7, 8
    beqz t0, redraw
    jal ra, next_view
    j redraw
start_again:
    jal ra, fresh
    j redraw
not_result:
    li t1, 2
    beq t0, t1, operation
    andi t0, s7, 8
    bnez t0, erase_digit
    andi t0, s7, 2
    bnez t0, append_digit
    andi t0, s7, 4
    bnez t0, confirm_number
    j redraw

append_digit:
    andi t0, s6, 15
    li t1, 9
    bltu t1, t0, bad_digit
    lw t1, 12(s0)
    li t2, 214748364
    bltu t2, t1, input_overflow
    bne t1, t2, append_ok
    li t2, 8
    bltu t2, t0, input_overflow
append_ok:
    lw t2, 16(s0)
    li t3, 10
    bgeu t2, t3, input_overflow
    slli t3, t1, 3
    slli t1, t1, 1
    add t1, t1, t3
    add t1, t1, t0
    sw t1, 12(s0)
    addi t2, t2, 1
    sw t2, 16(s0)
    sw zero, 36(s0)
    sw zero, 40(s0)
    j redraw
bad_digit:
    li t0, 3
    sw t0, 36(s0)
    j redraw
input_overflow:
    li t0, 4
    sw t0, 36(s0)
    j redraw
erase_digit:
    lw a0, 12(s0)
    li a1, 10
    jal ra, udiv32
    sw a0, 12(s0)
    lw t0, 16(s0)
    beqz t0, erase_done
    addi t0, t0, -1
    sw t0, 16(s0)
erase_done:
    sw zero, 36(s0)
    sw zero, 40(s0)
    j redraw
confirm_number:
    lw t0, 12(s0)
    andi t1, s6, 16
    bnez t1, confirm_negative
    bltz t0, input_overflow
    j confirm_save
confirm_negative:
    neg t0, t0
confirm_save:
    lw t1, 8(s0)
    slli t2, t1, 2
    add t2, s0, t2
    sw t0, 0(t2)             # state 0 -> A, state 1 -> B
    addi t1, t1, 1
    sw t1, 8(s0)
    sw zero, 12(s0)
    sw zero, 16(s0)
    sw zero, 36(s0)
    sw zero, 40(s0)
    j redraw

operation:
    srli t0, s6, 5
    andi t0, t0, 3
    sw t0, 24(s0)
    andi t0, s7, 16          # require a fresh stable OFF -> ON
    beqz t0, redraw
    lw a0, 0(s0)
    lw a1, 4(s0)
    lw a2, 24(s0)
    jal ra, calculate
    sw a0, 28(s0)
    sw a1, 32(s0)
    sw a2, 36(s0)
    sw zero, 40(s0)
    sw zero, 44(s0)
    li t0, 3
    sw t0, 8(s0)
redraw:
    lw t0, 8(s0)
    li t1, 2
    bgeu t0, t1, redraw_ready
    srli t0, s6, 16         # SW16 selects input high decimal page
    andi t0, t0, 1
    sw t0, 40(s0)
redraw_ready:
    jal ra, render
    j poll

fresh:
    li t0, 0
fresh_loop:
    add t1, s0, t0
    sw zero, 0(t1)
    addi t0, t0, 4
    li t1, 48
    bltu t0, t1, fresh_loop
    ret

# KEY3: next decimal page, then switch quotient/remainder for division.
next_view:
    lw t0, 36(s0)
    bnez t0, view_done
    lw t0, 40(s0)
    bnez t0, view_wrap
    lw t0, 44(s0)
    lw t1, 28(s0)
    beqz t0, view_value
    lw t1, 32(s0)
view_value:
    bgez t1, view_abs
    neg t1, t1
view_abs:
    li t2, 10000000
    bltu t1, t2, view_wrap
    li t0, 1
    sw t0, 40(s0)
    ret
view_wrap:
    sw zero, 40(s0)
    lw t0, 24(s0)
    li t1, 3
    bne t0, t1, view_done
    lw t0, 44(s0)
    xori t0, t0, 1
    sw t0, 44(s0)
view_done:
    ret

# calculate(a0=A, a1=B, a2=op): a0=result a1=remainder a2=error.
# Error 1 = divide by zero, 2 = signed overflow. All other regs caller-saved.
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

# Render active-high segment masks; hex_device inverts them for DE2 pins.
# HEX7 is reserved for sign, HEX6..HEX0 contain seven decimal digits.
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
    lw t1, 40(s0)
    slli t1, t1, 4
    or s11, s11, t1
    lw t1, 44(s0)
    slli t1, t1, 5
    or s11, s11, t1
    lw t1, 36(s0)
    bnez t1, render_error
    li t1, 2
    beq t0, t1, render_op
    li t1, 3
    beq t0, t1, render_result
    lw s6, 12(s0)
    lw t1, 24(sp)           # original switch sample
    srli s8, t1, 4
    andi s8, s8, 1
    j render_number
render_result:
    lw s6, 28(s0)
    lw t1, 44(s0)
    beqz t1, render_signed
    lw s6, 32(s0)
render_signed:
    slt s8, s6, zero
    beqz s8, render_number
    neg s6, s6
render_number:
    beqz s8, render_convert
    li t0, 0x40
    sw t0, 28(s3)
    ori s11, s11, 64
render_convert:
    li s7, 0               # digit count
    addi s9, s0, 128
convert_loop:
    mv a0, s6
    li a1, 10
    jal ra, udiv32
    add t0, s9, s7
    sb a1, 0(t0)
    addi s7, s7, 1
    mv s6, a0
    bnez s6, convert_loop
    lw t0, 40(s0)
    li s8, 0               # first digit index
    beqz t0, render_page
    li s8, 7
render_page:
    li s10, 0
    addi s6, s0, 160
    bltu s8, s7, render_digits
    li t0, 0x3f            # unused upper page displays 0
    sw t0, 0(s3)
    j render_leds
render_digits:
    bgeu s8, s7, render_leds
    add t0, s9, s8
    lbu t1, 0(t0)
    add t1, s6, t1
    lbu t1, 0(t1)
    slli t0, s10, 2
    add t0, s3, t0
    sw t1, 0(t0)
    addi s8, s8, 1
    addi s10, s10, 1
    li t0, 7
    bltu s10, t0, render_digits
    j render_leds
render_op:
    lw t0, 24(s0)          # display operation code 0..3
    addi t1, s0, 160
    add t1, t1, t0
    lbu t1, 0(t1)
    sw t1, 0(s3)
    j render_leds
render_error:
    ori s11, s11, 128
    addi t2, s0, 160
    add t2, t2, t1
    lbu t2, 0(t2)
    sw t2, 0(s3)          # Err1 / Err2 / Err3 / Err4
    li t2, 0x50
    sw t2, 8(s3)
    sw t2, 12(s3)
    li t2, 0x79
    sw t2, 16(s3)
render_leds:
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
