# Mailbox frontend. Inputs/results use signed thousandths; trig angles are degrees.
.option norvc
.option norelax
.option nopic
.section .text
.globl _start
_start:
    lui sp, 0x84000
    addi sp, sp, 1024
    lui s1, 0x84000
    jal ra, clear_state
    jal ra, init_trig_table
poll:
    lui s0, 0x40006
    lui s1, 0x84000
    lw t0, 4(s0)
    andi t0, t0, 1
    beqz t0, poll
    lw t0, 8(s0)
    srli t1, t0, 16
    slli t3, t0, 16
    srli t3, t3, 16
    li t2, 0x5343
    beq t1, t2, hello
    li t2, 0x5341
    beq t1, t2, input_low
    li t2, 0x5342
    beq t1, t2, input_high
    li t2, 0x5344
    beq t1, t2, input_b_low
    li t2, 0x5345
    beq t1, t2, input_b_high
    li t2, 0x5352
    beq t1, t2, get_remainder
    li t2, 0x5350
    beq t1, t2, execute
    li t2, 0x5351
    beq t1, t2, get_result
bad_command:
    li a0, 0x80000001
    j reply
hello:
    bnez t3, bad_command
    jal ra, clear_state
    li a0, 0x53434932        # SCI2
    j reply
clear_state:
    # RAM: input=0, half-mask=4, result=8, ready=12, operation=16.
    sw zero, 0(s1)
    sw zero, 4(s1)
    sw zero, 8(s1)
    sw zero, 12(s1)
    sw zero, 16(s1)
    sw zero, 20(s1)
    sw zero, 24(s1)
    ret
input_low:
    lw t4, 0(s1)
    srli t4, t4, 16
    slli t4, t4, 16
    or t4, t4, t3
    sw t4, 0(s1)
    li t5, 1
    j received_half
input_high:
    lw t4, 0(s1)
    slli t4, t4, 16
    srli t4, t4, 16
    slli t3, t3, 16
    or t4, t4, t3
    sw t4, 0(s1)
    li t5, 2
    j received_half
input_b_low:
    lw t4, 20(s1)
    srli t4, t4, 16
    slli t4, t4, 16
    or t4, t4, t3
    sw t4, 20(s1)
    li t5, 4
    j received_half
input_b_high:
    lw t4, 20(s1)
    slli t4, t4, 16
    srli t4, t4, 16
    slli t3, t3, 16
    or t4, t4, t3
    sw t4, 20(s1)
    li t5, 8
received_half:
    lw t4, 4(s1)
    or t4, t4, t5
    sw t4, 4(s1)
    sw zero, 12(s1)
    li a0, 0
    j reply
execute:
    li t4, 6
    bltu t4, t3, bad_command
    sw zero, 12(s1)
    sw zero, 24(s1)
    li t5, 3
    bltu t3, t5, check_inputs
    li t5, 15
check_inputs:
    lw t4, 4(s1)
    and t4, t4, t5
    bne t4, t5, missing_input
    sw t3, 16(s1)
    lw a0, 0(s1)
    li t4, 3
    bgeu t3, t4, do_arithmetic
    beqz t3, do_exp
    li t4, 360000000
    blt t4, a0, range_error
    neg t4, t4
    blt a0, t4, range_error
    jal ra, sincos_milli
    lui s0, 0x40006
    lui s1, 0x84000
    lw t0, 16(s1)
    li t1, 1
    beq t0, t1, trig_done
    mv a0, a1
trig_done:
    li a1, 0
    j computed
do_exp:
    jal ra, exp_milli
    lui s0, 0x40006
    lui s1, 0x84000
    j computed
do_arithmetic:
    lw a1, 20(s1)
    addi a2, t3, -3
    jal ra, arith_calculate
    lui s0, 0x40006
    lui s1, 0x84000
    sw a1, 24(s1)
    mv a1, a2
    j computed
range_error:
    li a0, 0
    li a1, 4
computed:
    sw a0, 8(s1)
    li t0, 1
    sw t0, 12(s1)
    mv a0, a1             # 0=success; 4=argument outside supported range.
    j reply
missing_input:
    li a0, 0x80000002
    j reply
get_result:
    bnez t3, bad_command
    lw t4, 12(s1)
    beqz t4, not_ready
    lw a0, 8(s1)
    j reply
get_remainder:
    bnez t3, bad_command
    lw t4, 12(s1)
    beqz t4, not_ready
    lw a0, 24(s1)
    j reply
not_ready:
    li a0, 0x80000003
reply:
    sw a0, 12(s0)
    li t0, 1
    sw t0, 16(s0)
    j poll
