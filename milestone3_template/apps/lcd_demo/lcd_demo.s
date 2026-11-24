# DE2 LCD 16x2 demo, 25 MHz MCU. MMIO -> lcd_ctrl -> LCD.
.option norvc
.option norelax
.option nopic
.section .text
.globl _start, lcd_init, lcd_command, lcd_putchar
.equ LCD_BASE, 0x40006000
.equ TIMER_BASE, 0x40004000
_start:
    lui sp, 0x84000
    addi sp, sp, 1024
    li s0, LCD_BASE
    li s1, TIMER_BASE
    lui s2, 0x40000
    li t0, 3
    sw t0, 0(s1)             # timer enable + clear
    sw zero, 4(s2)
    jal ra, lcd_init
    li a0, 0x80              # DDRAM line 1, column 0
    jal ra, lcd_command
    li a0, 'M'
    jal ra, lcd_putchar
    li a0, 'C'
    jal ra, lcd_putchar
    li a0, 'U'
    jal ra, lcd_putchar
    li a0, ' '
    jal ra, lcd_putchar
    li a0, 'L'
    jal ra, lcd_putchar
    li a0, 'C'
    jal ra, lcd_putchar
    li a0, 'D'
    jal ra, lcd_putchar
    li a0, ' '
    jal ra, lcd_putchar
    li a0, 'R'
    jal ra, lcd_putchar
    li a0, 'E'
    jal ra, lcd_putchar
    li a0, 'A'
    jal ra, lcd_putchar
    li a0, 'D'
    jal ra, lcd_putchar
    li a0, 'Y'
    jal ra, lcd_putchar
    li a0, 0xc0              # DDRAM line 2, column 0
    jal ra, lcd_command
    li a0, 'R'
    jal ra, lcd_putchar
    li a0, 'V'
    jal ra, lcd_putchar
    li a0, '3'
    jal ra, lcd_putchar
    li a0, '2'
    jal ra, lcd_putchar
    li a0, 'I'
    jal ra, lcd_putchar
    li a0, ' '
    jal ra, lcd_putchar
    li a0, '@'
    jal ra, lcd_putchar
    li a0, ' '
    jal ra, lcd_putchar
    li a0, '2'
    jal ra, lcd_putchar
    li a0, '5'
    jal ra, lcd_putchar
    li a0, ' '
    jal ra, lcd_putchar
    li a0, 'M'
    jal ra, lcd_putchar
    li a0, 'H'
    jal ra, lcd_putchar
    li a0, 'z'
    jal ra, lcd_putchar
    li t0, 1
    sw t0, 4(s2)             # LEDG0: initialization and text writes completed
    lui t1, 0x40002
idle:
    lw t0, 0(t1)
    sw t0, 0(s2)             # mirror switches on red LEDs
    j idle

# Prerequisites for routines: s0=LCD_BASE, s1=TIMER_BASE, timer enabled.
lcd_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    li t0, 12                # ON=1 BLON=1 RS=0 SEND=0
    sw t0, 4(s0)
    sw zero, 0(s0)
    li a0, 1250000           # 50 ms after powering LCD
    jal ra, lcd_delay_cycles
    li a0, 0x30
    jal ra, lcd_command
    li a0, 125000            # >4.1 ms: use 5 ms
    jal ra, lcd_delay_cycles
    li a0, 0x30
    jal ra, lcd_command
    li a0, 25000             # >100 us: use 1 ms
    jal ra, lcd_delay_cycles
    li a0, 0x30
    jal ra, lcd_command
    li a0, 25000
    jal ra, lcd_delay_cycles
    li a0, 0x38              # 8-bit interface, 2 lines, 5x8 font
    jal ra, lcd_command
    li a0, 0x08              # display off
    jal ra, lcd_command
    li a0, 0x01              # clear display
    jal ra, lcd_command
    li a0, 50000             # 2 ms for clear/home operations
    jal ra, lcd_delay_cycles
    li a0, 0x06              # increment cursor, no display shift
    jal ra, lcd_command
    li a0, 0x0c              # display on, cursor/blink off
    jal ra, lcd_command
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# a0=command. Clear (0x01) and home (0x02) need an extra 2 ms afterwards.
lcd_command:
    li a1, 0
    j lcd_write
# a0=ASCII character, uses current DDRAM cursor.
lcd_putchar:
    li a1, 1
lcd_write:
    addi sp, sp, -16
    sw ra, 12(sp)
    andi a1, a1, 1
    ori a1, a1, 12
    sw a1, 8(sp)
    jal ra, lcd_wait_ready
    sw a0, 0(s0)
    lw t0, 8(sp)
    ori t0, t0, 2
    sw t0, 4(s0)             # SEND pulse; lcd_ctrl generates EN
    jal ra, lcd_wait_ready
    li a0, 1250              # >=50 us for ordinary instruction/data
    jal ra, lcd_delay_cycles
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# Controller READY does not represent the LCD busy flag.
lcd_wait_ready:
    lw t0, 8(s0)
    andi t0, t0, 1
    beqz t0, lcd_wait_ready
    ret

# a0=cycles at the actual MCU frequency, modulo-safe elapsed-cycle comparison.
lcd_delay_cycles:
    lw t0, 4(s1)
delay_loop:
    lw t1, 4(s1)
    sub t2, t1, t0
    bltu t2, a0, delay_loop
    ret
