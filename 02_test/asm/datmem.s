LOOP:
li x10, 0x7800
lb x1, 0(x10)
lb x2, 1(x10)
lb x3, 2(x10)
lb x4, 3(x10)

li x10, 0x2004
sb x1, 0(x10)
sb x2, 1(x10)
sb x3, 2(x10)
sb x4, 3(x10)

li x10, 0x2004
lh x21, 0(x10)
lh x22, 2(x10)

li x10, 0x7000
sh x21, 0(x10)
sh x22, 2(x10)
j LOOP
