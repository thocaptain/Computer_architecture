# HPS mailbox frontend for the original full_calculator arithmetic routines.
# Only RV32I instructions. CPU MMIO mailbox base: 0x40006000.
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

# DMEM: A=0, B=4, received-half mask=8, result=12, remainder=16,
# arithmetic error=20, result-ready=24. The stack grows down from RAM+1024.
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
    li t2, 0xca00
    beq t1, t2, hello
    li t2, 0xca01
    beq t1, t2, set_a_low
    li t2, 0xca02
    beq t1, t2, set_a_high
    li t2, 0xca03
    beq t1, t2, set_b_low
    li t2, 0xca04
    beq t1, t2, set_b_high
    li t2, 0xca10
    beq t1, t2, execute
    li t2, 0xca11
    beq t1, t2, get_result
    li t2, 0xca12
    beq t1, t2, get_remainder
bad_command:
    li a0, 0x80000001
    j reply

hello:
    bnez t3, bad_command
    jal ra, clear_state
    li a0, 0x43414c31       # "CAL1": rejects the old input+1 firmware.
    j reply

clear_state:
    sw zero, 0(s1)
    sw zero, 4(s1)
    sw zero, 8(s1)
    sw zero, 12(s1)
    sw zero, 16(s1)
    sw zero, 20(s1)
    sw zero, 24(s1)
    ret

set_a_low:
    lw t4, 0(s1)
    srli t4, t4, 16
    slli t4, t4, 16
    or t4, t4, t3
    sw t4, 0(s1)
    li t5, 1
    j received_half
set_a_high:
    lw t4, 0(s1)
    slli t4, t4, 16
    srli t4, t4, 16
    slli t3, t3, 16
    or t4, t4, t3
    sw t4, 0(s1)
    li t5, 2
    j received_half
set_b_low:
    lw t4, 4(s1)
    srli t4, t4, 16
    slli t4, t4, 16
    or t4, t4, t3
    sw t4, 4(s1)
    li t5, 4
    j received_half
set_b_high:
    lw t4, 4(s1)
    slli t4, t4, 16
    srli t4, t4, 16
    slli t3, t3, 16
    or t4, t4, t3
    sw t4, 4(s1)
    li t5, 8
received_half:
    lw t4, 8(s1)
    or t4, t4, t5
    sw t4, 8(s1)
    sw zero, 24(s1)
    li a0, 0
    j reply

execute:
    li t4, 3
    bltu t4, t3, bad_command
    lw t4, 8(s1)
    li t5, 15
    bne t4, t5, missing_operand
    lw a0, 0(s1)
    lw a1, 4(s1)
    mv a2, t3
    jal ra, calculate
    lui s0, 0x40006
    lui s1, 0x84000
    sw a0, 12(s1)
    sw a1, 16(s1)
    sw a2, 20(s1)
    li t0, 1
    sw t0, 24(s1)
    mv a0, a2             # 0=OK, 1=divide by zero, 2=signed overflow.
    j reply
missing_operand:
    li a0, 0x80000002
    j reply

get_result:
    bnez t3, bad_command
    lw t4, 24(s1)
    beqz t4, no_result
    lw a0, 12(s1)
    j reply
get_remainder:
    bnez t3, bad_command
    lw t4, 24(s1)
    beqz t4, no_result
    lw a0, 16(s1)
    j reply
no_result:
    li a0, 0x80000003

reply:
    sw a0, 12(s0)
    li t0, 1
    sw t0, 16(s0)         # COMPLETE; host reads and ACKs this response.
    j poll
