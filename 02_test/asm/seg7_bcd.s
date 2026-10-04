li x1, 0x00007020  
#li x2, 0x017D7840
li x2, 4
li x5, 10

B0:
li x3, 0x00000000
B1:
beq x3, x2, B_1S
addi x3, x3, 1
j B1

B_1S:

addi x4, x4, 1
bne x4, x5, B_CONT
addi x4, x0, 0
B_CONT:

sb x4, 0(x1)
sb x4, 1(x1)
sb x4, 2(x1)
sb x4, 3(x1)
sb x4, 4(x1)
sb x4, 5(x1)
sb x4, 6(x1)
sb x4, 7(x1)

j B0