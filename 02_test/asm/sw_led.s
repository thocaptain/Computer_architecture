li x1, 0x00007000 
li x2, 0x00007800 
#li x3, 0x017D7840

B0:

lw x3, 0(x2)
sw x3, 0(x1)

j B0