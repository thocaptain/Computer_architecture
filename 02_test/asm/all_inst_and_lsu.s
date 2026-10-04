main:
# immediate instruction
addi x1, x0, 0x789
xori x1, x1, 0x123
ori  x1, x1, 0x321
andi x1, x1, 0x778
slli x1, x1, 0x015
addi x1, x1, 0x7FA
srai x1, x1, 0x003
srli x1, x1, 0x002

slli  x1, x1, 0x002
slti  x2, x1, 0x0000
sltiu x3, x1, 0x0000

# REG instruction
add x1, x1, x2
add x1, x1, x3
li x2, 0xA2B397CE
sub x1, x1, x2
xor x1, x1, x2
or  x1, x1, x2
and x1, x1, x2
li x2, 0x2
li x3, 0x6
sll x1, x1, x3
sra x1, x1, x2
srl x1, x1, x2
sll x1, x1, x2

slt x2, x1, x0
sltu x3, x1, x0
add x1, x1, x2
add x1, x1, x3
# BRANCH instruction
li x2, 0x0
li x3, 0xA
LOOP_PLUS_3:
addi x1, x1, 0x3
addi x2, x2, 1
bne x2, x3, LOOP_PLUS_3

li x2, 0x8
LOOP_PLUS_2:
beq x2, x0, END_LOOP_PLUS_2
addi x1, x1, 0x2
addi x2, x2, -1
j LOOP_PLUS_2
END_LOOP_PLUS_2:
jal x2, FUNC

# done -> check x1 = 0xEB397D54


# MEM instruction
li x3, 0xAA
li x4, 0xBB
li x5, 0xCC
li x6, 0xDD
li x7, 0xAABB
li x8, 0xCCDD
li x9, 0xAABBCCDD

li x2, 0x2004
sb x3, 0(x2)
sb x4, 1(x2)
sb x5, 2(x2)
sb x6, 3(x2)

li x2, 0x7000
sb x3, 0(x2)
sb x4, 1(x2)
sb x5, 2(x2)
sb x6, 3(x2)

li x2, 0x7010
sh x7, 0(x2)
sh x8, 2(x2)

li x2, 0x7020
sw x9, 0(x2)

li x2, 0x7030
sb x3, 0(x2)
sb x4, 1(x2)
sh x8, 2(x2)


li x2, 0x7000
lw x10, 0(x2)

li x2, 0x7010
lb x11, 0(x2)
lbu x12, 1(x2)

li x2, 0x7020
lh x13, 0(x2)
lhu x14, 2(x2)

li x2, 0x7030
lw x15, 0(x2)

li x2, 0x2004
lw x16, 0(x2)
# done check x10       , x11       , x12       , x13       , x14       , x15       , x16
#            0xDDCCBBAA, 0xFFFFFFBB, 0x000000AA, 0xFFFFCCDD, 0x0000AABB, 0xCCDDBBAA, 0xDDCCBBAA
j main
FUNC:
    addi x1, x1, 69
    jalr x0, x2, 0