.option norvc
.option norelax
.section .text
.globl _start
_start:
    lui s0, 0x40006
poll:
    lw t0, 4(s0)
    andi t0, t0, 1
    beq t0, zero, poll
    lw a0, 8(s0)
    addi a0, a0, 1
    sw a0, 12(s0)
    addi t0, zero, 1
    sw t0, 16(s0)
    j poll
