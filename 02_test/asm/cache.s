main:
    # IDX = 2, OFFSET = 3
    li x10, 0x2000
    li x11, 0x2080
    li x12, 0x2100
    
    li x4, 0xAABBCCDD
    sb x4, 0(x10)
    sh x4, 4(x10)
    sw x4, 8(x10)
    
    li x4, 0x11223344
    sb x4, 0(x11)
    sh x4, 4(x11)
    sw x4, 8(x11)
    
    li x4, 0x55667788
    sb x4, 0(x12)
    sh x4, 4(x12)
    sw x4, 8(x12)
    
    lb x4, 0(x10)
    add x1, x1, x4
    lh x4, 4(x10)
    add x1, x1, x4
    lw x4, 8(x10)
    add x1, x1, x4
    
    lb x4, 0(x11)
    add x1, x1, x4
    lh x4, 4(x11)
    add x1, x1, x4
    lw x4, 8(x11)
    add x1, x1, x4
    
    lb x4, 0(x12)
    add x1, x1, x4
    lh x4, 4(x12)
    add x1, x1, x4
    lw x4, 8(x12)
    add x1, x1, x4
    
    LOOP:
    j LOOP