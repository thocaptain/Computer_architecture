# li x1, 0x017D7840
li x1, 0x00000005

B0:
li x2, 0x00000000
B1:
beq x2, x1, B_1S
addi x2, x2, 1
j B1

B_1S:
beq x3, x0, B_OFF

li x4, 0x00000000
sw x4, 8(x0)
sw x4, 12(x0)
sw x4, 16(x0)
sw x4, 20(x0)
sw x4, 24(x0)
sw x4, 28(x0)
sw x4, 32(x0)
sw x4, 36(x0)
li x3, 0x00000000
j B0
B_OFF:
li x4, 0xFFFFFFFF
sw x4, 8(x0)
sw x4, 12(x0)
sw x4, 16(x0)
sw x4, 20(x0)
sw x4, 24(x0)
sw x4, 28(x0)
sw x4, 32(x0)
sw x4, 36(x0)
li x3, 0xFFFFFFFF
j B0