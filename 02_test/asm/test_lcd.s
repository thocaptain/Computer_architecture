main:
jal x29, LCD_INIT

loop:
li x26, 0x80000080 # address 0
jal x28, WRITE_LCD

li x26, 0x80000230 # 0
jal x28, WRITE_LCD

li x26, 0x80000231 # 1
jal x28, WRITE_LCD

li x26, 0x80000232 # 2
jal x28, WRITE_LCD

li x26, 0x80000233 # 3
jal x28, WRITE_LCD

li x15, 0x7800
lw x16, 0(x15)
li x15, 0x7000
sw x16, 0(x15)

li x1, 1000000 # 20ms
CONT_WAIT_LOOP:
beq x1, x0, END_WAIT_LOOP
addi x1, x1, -1
j CONT_WAIT_LOOP
END_WAIT_LOOP:

j loop


LCD_INIT:
li x26, 0x80000000 # power on code
jal x28, WRITE_LCD

li x26, 0x80000030 # function set code
jal x28, WRITE_LCD

li x26, 0x80000030 # function set code
jal x28, WRITE_LCD

li x26, 0x80000030 # function set code
jal x28, WRITE_LCD

li x26, 0x80000038 # function set code
jal x28, WRITE_LCD

li x26, 0x8000000C # display on
jal x28, WRITE_LCD

li x26, 0x80000001 # display clear
jal x28, WRITE_LCD

li x26, 0x80000006 # entry mode set
jal x28, WRITE_LCD

jalr x0, x29, 0


WRITE_LCD:
    li x25, 0x07030 # address of LCD
    li x27, 400000 # 20ms
    #li x27, 55 # 20ms
    CONT_WAIT_LCD:
    beq x27, x0, END_WAIT_LCD
    addi x27, x27, -1
    j CONT_WAIT_LCD
END_WAIT_LCD:
    sw x26, 0(x25) # LCD write
    jalr x0, x28, 0
