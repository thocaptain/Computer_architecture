main:
li x1, 0x2000
li x2, 0
li x3, 200
LOOP_0:
sw x2, 0(x1)
addi x2, x2, 1
addi x1, x1, 4
bne x2, x3, LOOP_0

li x1, 0x2000
li x2, 0
li x3, 200
LOOP_1:
lw x4, 0(x1)
addi x4, x4, 69
sw x4, 0(x1)
addi x2, x2, 1
addi x1, x1, 4
bne x2, x3, LOOP_1

j main
