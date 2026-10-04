main:
    jal x29, LCD_INIT

    li x1, 0x12345678
    li x2, 0x2000
    sw x1, 0(x2)
    
    lw x24, 0(x2)
    jal x20, LCD_NUM_WORD_DISPLAY
    
    MAIN_LOOP:
    j MAIN_LOOP


LCD_NUM_WORD_DISPLAY: # argument x24, return x20
    li x23, 28
    LCD_NUM_LOOP:
        srl x26, x24, x23
        li x21, 0x0000000F
        and x26, x26, x21
        li x21, 0xA
        blt x26, x21, ADD_x30
            addi x26, x26, 0x37
            j DONE_ASCII_ADD
        ADD_x30:
            addi x26, x26, 0x30
        DONE_ASCII_ADD:
        li x21, 0x80000200
        or x26, x26, x21
        jal x28, LCD_WRITE

        beqz x23, LCD_NUM_END
        addi x23, x23 -4
        j LCD_NUM_LOOP
    LCD_NUM_END:
    jalr x0, x20, 0

        

LCD_INIT: # return x29
    li x26, 0x80000000 # power on code
    jal x28, LCD_WRITE

    li x26, 0x80000030 # function set code
    jal x28, LCD_WRITE

    li x26, 0x80000030 # function set code
    jal x28, LCD_WRITE

    li x26, 0x80000030 # function set code
    jal x28, LCD_WRITE

    li x26, 0x80000038 # function set code
    jal x28, LCD_WRITE

    li x26, 0x8000000C # display on
    jal x28, LCD_WRITE

    li x26, 0x80000001 # display clear
    jal x28, LCD_WRITE

    li x26, 0x80000006 # entry mode set
    jal x28, LCD_WRITE

    jalr x0, x29, 0


LCD_WRITE: # argument: x26, return x28
    li x25, 0x07030 # address of LCD
    li x27, 400000 # 20ms
    # li x27, 3 # 20ms, TODO:REMOVE
    CONT_WAIT_LCD:
    addi x27, x27, -1
    bne x27, x0, CONT_WAIT_LCD

    sw x26, 0(x25) # LCD write
    jalr x0, x28, 0