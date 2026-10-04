# Memory-mapped I/O addresses for DE2-70
# FIXME: COMPILER DOEST UNDERSTAND
.eqv SW_ADDR         0x7800  # Base address for switches
.eqv BTN_ADDR        0x7810  # Base address for buttons
.eqv LCD_ADDR        0x7030  # Base address for LCD control registers
.eqv LCD_DATA        0x7031  # LCD data register
.eqv LCD_CMD         0x7030  # LCD command register

# Button definitions (offset from BTN_ADDR)
.eqv SAVE_BTN        0x01    # Button 0 for saving coordinates
.eqv DISPLAY_BTN     0x02    # Button 1 for displaying result
.eqv RESET_BTN       0x04    # Button 2 for system reset

# FIXME: IS THERE ANY OTHER WAY TO SPECIFY THESE ?
.data
    menu_header:    .string "2D Distance Calc"
    point_a_msg:    .string "Point A:"
    point_b_msg:    .string "Point B:"
    point_c_msg:    .string "Point C:"
    result_msg_a:   .string "A is closer to C"
    result_msg_b:   .string "B is closer to C"
    ax: .word 0
    ay: .word 0
    bx: .word 0
    by: .word 0
    cx: .word 0
    cy: .word 0
    dist_a: .word 0
    dist_b: .word 0

.text
.globl main

# LCD Initialization sequence
lcd_init:
    # Save return address
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # FIXME: TURN ON POWER FOR LCD
    # FIXME: MAYBE NOT ENOUGH FOR INIT

    # Function set (8-bit mode, 2 lines)
    li a0, 0x38
    call lcd_command
    
    # Display ON/OFF control (Display ON, Cursor OFF, Blink OFF)
    li a0, 0x0C
    call lcd_command
    
    # Clear display
    li a0, 0x01
    call lcd_command
    
    # Entry mode set (Increment cursor, no shift)
    li a0, 0x06
    call lcd_command
    
    # Return home
    li a0, 0x02
    call lcd_command
    
    # Restore return address
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# Send command to LCD
lcd_command:
    li t0, LCD_CMD
    sb a0, 0(t0)
    # Delay for command to process
    li t1, 1000
delay_loop:
    addi t1, t1, -1
    bnez t1, delay_loop
    ret

# Send data to LCD
lcd_data:
    li t0, LCD_DATA
    sb a0, 0(t0)
    ret

# Display string on LCD
lcd_display_str:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp)
    mv s0, a0
str_loop:
    lb a0, 0(s0)
    beqz a0, str_end
    call lcd_data
    addi s0, s0, 1
    j str_loop
str_end:
    lw ra, 0(sp)
    lw s0, 4(sp)
    addi sp, sp, 8
    ret

# Read switches and wait for save button
input_coordinate:
    li t0, BTN_ADDR
    li t1, SW_ADDR
wait_save:
    lw t2, 0(t0)
    andi t2, t2, SAVE_BTN
    beqz t2, wait_save
    # Read switch values
    lw a0, 0(t1)
    # Wait for button release
button_release:
    lw t2, 0(t0)
    andi t2, t2, SAVE_BTN
    bnez t2, button_release
    ret

# Reset system
reset_system:
    li t0, BTN_ADDR
check_reset:
    lw t1, 0(t0)
    andi t1, t1, RESET_BTN
    beqz t1, reset_end
    # Clear all coordinates
    sw zero, ax
    sw zero, ay
    sw zero, bx
    sw zero, by
    sw zero, cx
    sw zero, cy
    sw zero, dist_a
    sw zero, dist_b
    # Clear LCD
    li a0, 0x01
    call lcd_command
reset_end:
    ret

main:
    # Initialize LCD
    call lcd_init
    
    # Display header
    la a0, menu_header
    call lcd_display_str
    
input_loop:
    # Input Point A coordinates
    li a0, 0x80        # Set cursor to first line
    call lcd_command
    la a0, point_a_msg
    call lcd_display_str
    call input_coordinate
    sw a0, ax
    call input_coordinate
    sw a0, ay
    
    # Input Point B coordinates
    li a0, 0xC0        # Set cursor to second line
    call lcd_command
    la a0, point_b_msg
    call lcd_display_str
    call input_coordinate
    sw a0, bx
    call input_coordinate
    sw a0, by
    
    # Input Point C coordinates
    li a0, 0x94        # Set cursor to third line
    call lcd_command
    la a0, point_c_msg
    call lcd_display_str
    call input_coordinate
    sw a0, cx
    call input_coordinate
    sw a0, cy

    # Calculate distances
    # Distance A to C
    lw t1, ax
    lw t2, ay
    lw t3, cx
    lw t4, cy
    sub t5, t1, t3
    mul t5, t5, t5
    sub t6, t2, t4
    mul t6, t6, t6
    add t0, t5, t6
    sw t0, dist_a
    
    # Distance B to C
    lw t1, bx
    lw t2, by
    sub t5, t1, t3
    mul t5, t5, t5
    sub t6, t2, t4
    mul t6, t6, t6
    add t0, t5, t6
    sw t0, dist_b

    # Wait for display button
    li t0, BTN_ADDR
wait_display:
    lw t1, 0(t0)
    andi t1, t1, DISPLAY_BTN
    beqz t1, wait_display

    # Clear display before showing result
    li a0, 0x01
    call lcd_command
    
    # Compare distances and display result
    lw t1, dist_a
    lw t2, dist_b
    ble t1, t2, show_a_closer
    
show_b_closer:
    la a0, result_msg_b
    call lcd_display_str
    j check_reset_loop
    
show_a_closer:
    la a0, result_msg_a
    call lcd_display_str

check_reset_loop:
    call reset_system
    j input_loop

.end