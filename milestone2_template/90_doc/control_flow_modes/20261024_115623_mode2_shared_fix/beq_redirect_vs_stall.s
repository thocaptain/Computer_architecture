.option norvc
.option norelax
.option nopic
.section .text
.globl _start
_start:
lui x24, 0x8400f
lui x25, 0x84000
li x30, 1
sw x30, 0(x25)
li x26, 1
li x28, 0
li x6, 0
li x7, 0
nop
nop
nop
addi x5, x0, 1
beq x6, x7, target
addi x28, x5, 0
sw x26, 0(x24)
li x30, 0x0bad
sw x30, 16(x24)
wrong_fallthrough:
j wrong_fallthrough
target:
beq x28, x0, wrong_path_ok
sw x26, 0(x24)
li x30, 0x0bad
sw x30, 16(x24)
wrong_path_fail:
j wrong_path_fail
wrong_path_ok:
li x26, 1
sw x26, 0(x24)
li x30, 0x600d
sw x30, 16(x24)
halt:
j halt
