main:
    jal x29, LCD_INIT
    jal x19, INPUT_COORDINATE

    li x1, 0x2000
    lw x2, 0(x1) # Ax
    lw x3, 4(x1) # Ay

    lw x4, 8(x1) # Bx
    lw x5, 12(x1) # By

    lw x6, 16(x1) # Cx
    lw x7, 20(x1) # Cy

    sub x17, x6, x2
    jal x15, SQUARE
    mv x2, x18 # (Cx-Ax)^2

    sub x17, x7, x3
    jal x15, SQUARE
    add x3, x2, x18 # (Cx-Ax)^2 + (Cy-Ay)^2

    sub x17, x6, x4
    jal x15, SQUARE
    mv x4, x18 # (Cx-Bx)^2

    sub x17, x7, x5
    jal x15, SQUARE
    add x5, x4, x18 # (Cx-Bx)^2 + (Cy-By)^2

    AC2_LOOP:
    li x1, 0x7810
    lw x1, 0(x1)
    li x2, 0x0000000E
    beq x1, x2, DISPLAY_AC2
    j AC2_LOOP
    
    DISPLAY_AC2:
    li x26, 0x80000001
    jal x28, LCD_WRITE
    li x26, 0x80000241
    jal x28, LCD_WRITE
    li x26, 0x80000243
    jal x28, LCD_WRITE
    li x26, 0x80000232
    jal x28, LCD_WRITE
    li x26, 0x800000C0
    jal x28, LCD_WRITE
    mv x24, x3
    jal x20, LCD_NUM_WORD_DISPLAY
    
    BC2_LOOP:
    li x1, 0x7810
    lw x1, 0(x1)
    li x2, 0x0000000D
    beq x1, x2, DISPLAY_BC2
    j BC2_LOOP
    
    DISPLAY_BC2:
    li x26, 0x80000001
    jal x28, LCD_WRITE
    li x26, 0x80000242
    jal x28, LCD_WRITE
    li x26, 0x80000243
    jal x28, LCD_WRITE
    li x26, 0x80000232
    jal x28, LCD_WRITE
    li x26, 0x800000C0
    jal x28, LCD_WRITE
    mv x24, x5
    jal x20, LCD_NUM_WORD_DISPLAY

    RES_LOOP:
    li x1, 0x7810
    lw x1, 0(x1)
    li x2, 0x0000000B
    beq x1, x2, DISPLAY_RES
    j RES_LOOP
    
    DISPLAY_RES:
    li x26, 0x80000001
    jal x28, LCD_WRITE
    
    bltu x3, x5, DISPLAY_LT
    li x26, 0x80000229
    jal x28, LCD_WRITE
    j MAIN_LOOP
    
    DISPLAY_LT:
    li x26, 0x80000228
    jal x28, LCD_WRITE

    MAIN_LOOP:
    j MAIN_LOOP

SQUARE: # argument x17, result x18, return x15 TODO: implement negative input    
    bgt x17, x0, SQUARE_POS_INPUT
    li x18, 0xFFFFFFFF
    xor x17, x17, x18
    addi x17, x17, 1

    SQUARE_POS_INPUT:
    li x18, 0
    mv x16, x17
    SQUARE_LOOP:
    add x18, x18, x17
    addi x16, x16, -1
    bnez x16, SQUARE_LOOP
    jalr x0, x15, 0
    

INPUT_COORDINATE: # return x19
    li x1, 0xF    # previous button state
    li x4, 6      # number of input
    li x6, 0x2000 # starting point of inputs in datmem

    INPUT_LOOP:
    li x2, 0x7810 # BUTTON_ADDRESS  # Load the button address
    lw x2, 0(x2)                    # Dereference to get actual button states
    xor x3, x2, x1 # changed buttons
    and x3, x3, x2 # changed buttons when releasing
    mv x1, x2 # update previous state

    bnez x3, INPUT_CAPTURE # there is a press
    j INPUT_LOOP

    INPUT_CAPTURE:
    li x5, 0x7800 # load from switch
    lw x5, 0(x5)
    sw x5, 0(x6)
    addi x6, x6, 4

    # display captured value
    li x26, 0x80000080
    jal x28, LCD_WRITE

    mv x24, x5
    jal x20, LCD_NUM_WORD_DISPLAY

    # decrease loop variable
    addi x4, x4, -1
    bnez x4, INPUT_LOOP
    jalr x0, x19, 0

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