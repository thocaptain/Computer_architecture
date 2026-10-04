.data
    BASE_ADDR_BUTTON  :        .word 0x00007810     
    BASE_ADDR_SWITCH  :        .word 0x00007800     
    BASE_ADDR_LCD     :        .word 0x00007030     
    BASE_ADDR_SEG7_0  :        .word 0x00007020     
    BASE_ADDR_SEG7_1  :        .word 0x00007024     
    BASE_ADDR_GLED    :        .word 0x00007010     
    BASE_ADDR_RLED    :        .word 0x00007000     
    BASE_ADDR_DMEM    :        .word 0x00002000     

    TIME_1SEC_2INST: .word 0x017D7840
    TIME_1SEC_1INST: .word 0x02FAF080
    
.text
.globl main

main:

li x1, 0x00007810 # BASE_ADDR_BUTTON
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007800 # BASE_ADDR_SWITCH
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007030 # BASE_ADDR_LCD
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007020 # BASE_ADDR_SEG7_0
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007024 # BASE_ADDR_SEG7_1
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007010 # BASE_ADDR_GLED
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00007000 # BASE_ADDR_RLED
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)

li x1, 0x00002000 # BASE_ADDR_DMEM
li x9, 0x87654321
sw x9, 2(x1)
sh x9, 1(x1)
sh x9, 3(x1)
sb x9, 0(x1)
sb x9, 1(x1)
sb x9, 2(x1)
sb x9, 3(x1)
lw x2, 2(x1)
lh x3, 1(x1)
lh x4, 3(x1)
lb x5, 0(x1)
lb x6, 1(x1)
lb x7, 2(x1)
lb x8, 3(x1)
