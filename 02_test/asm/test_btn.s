li x1, 0x7810 # address of button
li x9, 0x7020 # address of HEX
li x8, 9

li x2, 0  # previous state of button

li x10, 0 # HEX 0
li x11, 0 # HEX 1
li x12, 0 # HEX 2
li x13, 0 # HEX 3

LOOP:
lw x3, 0(x1) # read button
xor x4, x2, x3 # see which buttons are pressed

li x5, 0x0001 # mask for button 0
and x6, x4, x5 # see if button 0 is pressed
beq x6, x0, SKIP_0 # if no pressed, skip addition
bne x10, x8, SKIP_RST_0 # if not equal 9, then add 1
add x10, x0, x0 # reset bcd
j SKIP_0 
SKIP_RST_0:
addi x10, x10, 1 # increase bcd

SKIP_0:

li x5, 0x0002 # mask for button 0
and x6, x4, x5 # see if button 0 is pressed
beq x6, x0, SKIP_1 # if no pressed, skip addition
bne x11, x8, SKIP_RST_1 # if not equal 9, then add 1
add x11, x0, x0 # reset bcd
j SKIP_1 
SKIP_RST_1:
addi x11, x11, 1 # increase bcd

SKIP_1:

li x5, 0x0004 # mask for button 0
and x6, x4, x5 # see if button 0 is pressed
beq x6, x0, SKIP_2 # if no pressed, skip addition
bne x12, x8, SKIP_RST_2 # if not equal 9, then add 1
add x12, x0, x0 # reset bcd
j SKIP_2 
SKIP_RST_2:
addi x12, x12, 1 # increase bcd

SKIP_2:

li x5, 0x0008 # mask for button 0
and x6, x4, x5 # see if button 0 is pressed
beq x6, x0, SKIP_3 # if no pressed, skip addition
bne x13, x8, SKIP_RST_3 # if not equal 9, then add 1
add x13, x0, x0 # reset bcd
j SKIP_3 
SKIP_RST_3:
addi x13, x13, 1 # increase bcd

SKIP_3:


sb x10, 0(x9)
sb x11, 1(x9)
sb x12, 2(x9)
sb x13, 3(x9)

mv x2, x3

j LOOP
