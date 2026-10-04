li x22, 0x12345678
li x23, 0x87654321

main:
li x1, 0x00000001

# rotate x22,x23 to the right

and x2, x1, x22
and x3, x1, x23

slli x25, x2, 31
slli x26, x3, 31

srli x22, x22, 1
srli x23, x23, 1

or x22, x22, x25
or x23, x23, x26

li x1, 1
# TEST1: dynamic independent series

beq x2, x1, IND_0
    li x5, 0
j IND_END_0
IND_0:
    li x5, 1
IND_END_0:

beq x3, x1, IND_1
    li x6, 0
j IND_END_1
IND_1:
    li x6, 1
IND_END_1:

# TEST 2: dynamic correlation series

beq x5, x6, CORR_0
    li x8, 0
j CORR_END_0
CORR_0:
    li x8, 1
CORR_END_0:

beq x8, x1, CORR_2
    li x10, 0
j CORR_END_2
CORR_2:
    li x10, 1
CORR_END_2:

beq x10, x1, CORR_3
    li x11, 1
j CORR_END_3
CORR_3:
    li x11, 0
CORR_END_3:

beq x11, x1, CORR_4
    li x12, 1
j CORR_END_4
CORR_4:
    li x12, 0
CORR_END_4:

beq x12, x1, CORR_5
    li x13, 0
j CORR_END_5
CORR_5:
    li x13, 1
CORR_END_5:

beq x13, x8, CORR_6
    li x14, 1
j CORR_END_6
CORR_6:
    li x14, 0
CORR_END_6:

    
# TEST 3: static loop

BR_END:
    li x2, 10
    li x1, 0
    LOOP_0:
    addi x1, x1, 1
    bne x1, x2, LOOP_0

# TEST 4: static independent series

li x2, 2
li x3, 3
li x4, 4
li x5, 5
li x6, 6
li x7, 7
li x8, 8

li x1, 2
beq x1, x2, BR_SERIES_0
BR_SERIES_0:
li x1, 2
beq x1, x3, BR_SERIES_1
BR_SERIES_1:
li x1, 4
beq x1, x4, BR_SERIES_2
BR_SERIES_2:
li x1, 5
beq x1, x5, BR_SERIES_3
BR_SERIES_3:
li x1, 5
beq x1, x6, BR_SERIES_4
BR_SERIES_4:
beq x1, x7, BR_SERIES_5
BR_SERIES_5:
li x1, 8
beq x1, x8, BR_SERIES_6
BR_SERIES_6:

j main