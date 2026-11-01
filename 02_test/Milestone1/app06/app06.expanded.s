# RV32I only, no runtime, no interrupts, no instruction-ROM data loads.
# Expanded LCD strings become li/jal instruction sequences in prepare_app06.py.
.option norvc
.option norelax
.ifndef APP_CPU_HZ
.equ APP_CPU_HZ, 5000000
.endif
.equ TICK, APP_CPU_HZ / 4
.section .text
.global _start
_start:
    li sp, 0x4000
    li s0, 0x7000
    li t0, 0x3f10
    sw zero, 0(t0)             # accumulated test pass mask
    li s1, -1                 # selected mode
    li s8, 0                  # heartbeat
    jal ra, lcd_init
main:
    li t0, 0x7800
    lw t0, 0(t0)
    srli t1, t0, 15
    andi t1, t1, 7
    bne t1, s1, enter
    li t0, 0x7810
    lw t0, 0(t0)
    xori t1, s2, -1
    and s2, t0, t1             # rising edges of debounced active-high keys
    mv t1, t0
    mv a5, s2
    mv s2, t1
    li t0, 2
    beq s1, t0, key_test
    andi t0, a5, 1
    bnez t0, restart
    andi t0, a5, 4
    beqz t0, dispatch
    beqz s1, manual_pass
    li t0, 3
    beq s1, t0, manual_pass
    li t0, 4
    beq s1, t0, manual_pass
    li t0, 6
    bne s1, t0, dispatch
manual_pass:
    li s3, 1
    jal ra, record_pass
dispatch:
    li t0, 1
    beq s1, t0, switch_test
    jal ra, tick
    beqz a0, show
    addi s5, s5, 1
    beqz s1, led_test
    li t0, 3
    beq s1, t0, hex_test
    li t0, 4
    beq s1, t0, timer_test
    li t0, 6
    beq s1, t0, lcd_test
    j show
restart:
    mv t1, s1
    li t0, 0x3f10
    lw t2, 0(t0)
    li t3, 1
    sll t3, t3, s1
    xori t3, t3, -1
    and t2, t2, t3
    sw t2, 0(t0)
enter:
    mv s1, t1
    li s2, 7                  # ignore keys held during mode entry
    li s3, 0                  # 0 pending, 1 manual pass, 2 automatic pass, 3 fail
    li s5, 0
    li s6, 0
    li s7, 0
    li s9, 0                  # button counters, 3 bytes
    li s10, 0                 # displayed value
    sw zero, 0(s0)
    sw zero, 0x10(s0)
    jal ra, lcd_page
    li t0, 0x4000
    lw s4, 0(t0)
    mv s11, s4
    li t0, 5
    beq s1, t0, ram_test
    beqz s1, led_test
    j show
switch_test:
    li t0, 0x7800
    lw t0, 0(t0)
    sw t0, 0(s0)
    andi s10, t0, -1
    or s6, s6, t0
    xori t0, t0, -1
    or s7, s7, t0
    and t0, s6, s7
    li t1, 0x7fff            # SW17..15 select the menu, test SW14..0 here
    and t0, t0, t1
    bne t0, t1, switch_tick
    li s3, 2
    jal ra, record_pass
switch_tick:
    jal ra, tick
    j show
key_test:
    andi t0, a5, 1
    beqz t0, key1
    andi t0, s9, 255
    addi t0, t0, 1
    andi t0, t0, 255
    li t1, 0xffffff00
    and s9, s9, t1
    or s9, s9, t0
key1:
    andi t0, a5, 2
    beqz t0, key2
    srli t0, s9, 8
    addi t0, t0, 1
    andi t0, t0, 255
    slli t0, t0, 8
    li t1, 0xffff00ff
    and s9, s9, t1
    or s9, s9, t0
key2:
    andi t0, a5, 4
    beqz t0, key_done
    srli t0, s9, 16
    addi t0, t0, 1
    andi t0, t0, 255
    slli t0, t0, 16
    li t1, 0xff00ffff
    and s9, s9, t1
    or s9, s9, t0
key_done:
    mv s10, s9
    andi t0, s9, 255
    beqz t0, key_tick
    srli t0, s9, 8
    andi t0, t0, 255
    beqz t0, key_tick
    srli t0, s9, 16
    beqz t0, key_tick
    li s3, 2
    jal ra, record_pass
key_tick:
    jal ra, tick
    j show
led_test:
    li t0, 29
    bltu s5, t0, led_phase
    li s5, 0
led_phase:
    mv s10, s5
    li t0, 0
    li t1, 0
    beqz s5, led_write
    li t2, 1
    beq s5, t2, led_all
    addi t2, s5, -2
    li t3, 18
    bgeu t2, t3, led_green
    li t0, 1
    sll t0, t0, t2
    j led_write
led_green:
    addi t2, t2, -18
    li t1, 1
    sll t1, t1, t2
    j led_write
led_all:
    li t0, 0x3ffff
    li t1, 0x1ff
led_write:
    sw t0, 0(s0)
    sw t1, 0x10(s0)
    j show
hex_test:
    andi t0, s5, 15
    li t1, 0x11111111
    li a0, 0
    li t2, 8
hex_repeat:
    slli a0, a0, 4
    or a0, a0, t0
    addi t2, t2, -1
    bnez t2, hex_repeat
    mv s10, a0
    j show
timer_test:
    li t0, 0x4000
    lw t1, 0(t0)
    sub t2, t1, s11
    li t3, APP_CPU_HZ
    bltu t2, t3, show
timer_catchup:
    addi s10, s10, 1
    add s11, s11, t3
    sub t2, t1, s11
    bgeu t2, t3, timer_catchup
    j show
lcd_test:
    mv s10, s5
    li a0, 0x800000c6
    jal ra, lcd_write
    mv a1, s5
    jal ra, lcd_hex4
    j show
show:
    li t0, 7
    bne s1, t0, show_status
    li t0, 0x3f10
    lw s10, 0(t0)
show_status:
    beqz s1, show_hex
    ori t0, s8, 0x20         # ready bit
    or t0, t0, s1
    li t1, 3
    beq s3, t1, status_fail
    beqz s3, status_write
    ori t0, t0, 0x40
    j status_write
status_fail:
    ori t0, t0, 0x80
status_write:
    sw t0, 0x10(s0)
show_hex:
    mv a0, s10
    li t0, 3
    beq s1, t0, show_hex_write
    li t0, 0xffffff
    and a0, a0, t0
    slli t0, s1, 28
    or a0, a0, t0
    slli t0, s3, 24
    or a0, a0, t0
show_hex_write:
    jal ra, hex_write
    j main

# Leaf routines may clobber a0/a1 and t0..t3. Other temporaries documented below.
tick:
    li t0, 0x4000
    lw t1, 0(t0)
    sub t2, t1, s4           # subtraction handles timer wrap
    li t3, TICK
    li a0, 0
    bltu t2, t3, tick_done
    mv s4, t1
    xori s8, s8, 0x100      # toggle each 250ms: heartbeat is 2Hz
    li a0, 1
tick_done:
    ret
record_pass:
    li t0, 0x3f10
    lw t1, 0(t0)
    li t2, 1
    sll t2, t2, s1
    or t1, t1, t2
    sw t1, 0(t0)
    ret
hex_write:
    li t0, 0x7020
    li t1, 8
hex_loop:
    andi t2, a0, 15
    sb t2, 0(t0)
    srli a0, a0, 4
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, hex_loop
    ret
lcd_write:
    sw a0, 0x30(s0)
    li t0, 0x4000
    lw t1, 0(t0)
    li t3, APP_CPU_HZ / 200 + 1  # >=5ms, also meets first function-set recovery
lcd_wait:
    lw t2, 0(t0)
    sub t2, t2, t1
    bltu t2, t3, lcd_wait
    ret
lcd_hex4:
    addi sp, sp, -16
    sw ra, 0(sp)
    li t4, 12
lcd_hex_loop:
    srl t5, a1, t4
    andi t5, t5, 15
    li t6, 10
    bltu t5, t6, lcd_decimal
    addi t5, t5, 7
lcd_decimal:
    addi t5, t5, 48
    li a0, 0x80000200
    or a0, a0, t5
    jal ra, lcd_write
    addi t4, t4, -4
    bgez t4, lcd_hex_loop
    lw ra, 0(sp)
    addi sp, sp, 16
    ret
lcd_init:
    addi sp, sp, -16
    sw ra, 0(sp)
    li t0, 0x4000
    lw t1, 0(t0)
    li t3, APP_CPU_HZ / 20 + 1  # >=50ms power-on delay
lcd_power_wait:
    lw t2, 0(t0)
    sub t2, t2, t1
    bltu t2, t3, lcd_power_wait
    li a0, 0x80000030
    jal ra, lcd_write
    li a0, 0x80000030
    jal ra, lcd_write
    li a0, 0x80000030
    jal ra, lcd_write
    li a0, 0x80000038
    jal ra, lcd_write
    li a0, 0x80000008
    jal ra, lcd_write
    li a0, 0x80000001
    jal ra, lcd_write
    li a0, 0x80000006
    jal ra, lcd_write
    li a0, 0x8000000c
    jal ra, lcd_write
    lw ra, 0(sp)
    addi sp, sp, 16
    ret
lcd_page:
    addi sp, sp, -16
    sw ra, 0(sp)
    li a0, 0x80000080
    jal ra, lcd_write
    beqz s1, page0
    li t0, 1
    beq s1, t0, page1
    li t0, 2
    beq s1, t0, page2
    li t0, 3
    beq s1, t0, page3
    li t0, 4
    beq s1, t0, page4
    li t0, 5
    beq s1, t0, page5
    li t0, 6
    beq s1, t0, page6
li a0, 0x80000237
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000250
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024d
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000248
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000258
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024d
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
    j page_done
page0:
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000246
jal ra, lcd_write
li a0, 0x80000246
jal ra, lcd_write
li a0, 0x8000022f
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x8000022f
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000255
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x8000023f
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
    j page_done
page1:
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000257
jal ra, lcd_write
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000234
jal ra, lcd_write
li a0, 0x8000022e
jal ra, lcd_write
li a0, 0x8000022e
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000022d
jal ra, lcd_write
li a0, 0x8000023e
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000257
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000248
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000255
jal ra, lcd_write
li a0, 0x80000250
jal ra, lcd_write
    j page_done
page2:
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x80000248
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000258
jal ra, lcd_write
li a0, 0x8000023a
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
    j page_done
page3:
li a0, 0x80000233
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000248
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000258
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x8000022e
jal ra, lcd_write
li a0, 0x8000022e
jal ra, lcd_write
li a0, 0x80000246
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000250
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x8000023f
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
    j page_done
page4:
li a0, 0x80000234
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000249
jal ra, lcd_write
li a0, 0x8000024d
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000243
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x80000243
jal ra, lcd_write
li a0, 0x80000248
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000243
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000273
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000259
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
    j page_done
page5:
li a0, 0x80000235
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000249
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x8000024d
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x80000255
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x8000022f
jal ra, lcd_write
li a0, 0x80000252
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000253
jal ra, lcd_write
li a0, 0x80000255
jal ra, lcd_write
li a0, 0x8000024c
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
    j page_done
page6:
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000231
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x80000233
jal ra, lcd_write
li a0, 0x80000234
jal ra, lcd_write
li a0, 0x80000235
jal ra, lcd_write
li a0, 0x80000236
jal ra, lcd_write
li a0, 0x80000237
jal ra, lcd_write
li a0, 0x80000238
jal ra, lcd_write
li a0, 0x80000239
jal ra, lcd_write
li a0, 0x80000241
jal ra, lcd_write
li a0, 0x80000242
jal ra, lcd_write
li a0, 0x80000243
jal ra, lcd_write
li a0, 0x80000244
jal ra, lcd_write
li a0, 0x80000245
jal ra, lcd_write
li a0, 0x80000246
jal ra, lcd_write
li a0, 0x800000c0
jal ra, lcd_write
li a0, 0x80000243
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x80000255
jal ra, lcd_write
li a0, 0x8000024e
jal ra, lcd_write
li a0, 0x80000254
jal ra, lcd_write
li a0, 0x8000023a
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000230
jal ra, lcd_write
li a0, 0x80000220
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
li a0, 0x80000232
jal ra, lcd_write
li a0, 0x8000023d
jal ra, lcd_write
li a0, 0x8000024f
jal ra, lcd_write
li a0, 0x8000024b
jal ra, lcd_write
page_done:
    lw ra, 0(sp)
    addi sp, sp, 16
    ret

# Destructive test: 0x2000..0x3eff. 0x3f00..0x3fff reserved for state/stack.
ram_test:
    li a4, 0
ram_pattern:
    li a2, 0
    beqz a4, ram_fill_setup
    li t0, 1
    li a2, -1
    beq a4, t0, ram_fill_setup
    li t0, 2
    li a2, 0xaaaaaaaa
    beq a4, t0, ram_fill_setup
    li a2, 0x55555555
ram_fill_setup:
    li a3, 0x2000
    li a6, 0x3f00
ram_fill:
    li t0, 4
    bltu a4, t0, ram_store
    mv a2, a3
    beq a4, t0, ram_store
    xori a2, a2, -1
ram_store:
    sw a2, 0(a3)
    addi a3, a3, 4
    bltu a3, a6, ram_fill
    li a3, 0x2000
ram_verify:
    li t0, 4
    bltu a4, t0, ram_load
    mv a2, a3
    beq a4, t0, ram_load
    xori a2, a2, -1
ram_load:
    lw a7, 0(a3)
    bne a7, a2, ram_fail
    addi a3, a3, 4
    bltu a3, a6, ram_verify
    addi a4, a4, 1
    li t0, 6
    bltu a4, t0, ram_pattern
    li a3, 0x2000
    sw zero, 0(a3)
    li t0, 0x80
    sb t0, 0(a3)
    li t0, 0x12
    sb t0, 1(a3)
    li t0, 0xfedc
    sh t0, 2(a3)
    li a2, 0xfedc1280
    lw a7, 0(a3)
    bne a7, a2, ram_fail
    li a2, -128
    lb a7, 0(a3)
    bne a7, a2, ram_fail
    li a2, 128
    lbu a7, 0(a3)
    bne a7, a2, ram_fail
    li a2, -292
    lh a7, 2(a3)
    bne a7, a2, ram_fail
    li a2, 0xfedc
    lhu a7, 2(a3)
    bne a7, a2, ram_fail
    li s3, 2
    li s10, 0x1f00
    jal ra, record_pass
    j show
ram_fail:
    li s3, 3
    mv s10, a3
    li t0, 0x3f00
    sw a3, 0(t0)
    sw a2, 4(t0)
    sw a7, 8(t0)
    j show
