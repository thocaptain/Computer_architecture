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
lui x5, %hi(target)
addi x5, x5, %lo(target)
jalr x1, 0(x5)
addi x28, x1, 0
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
