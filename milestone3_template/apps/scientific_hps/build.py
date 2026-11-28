#!/usr/bin/env python3
"""Build independent exp/sin/cos RV32I firmware without changing the active project."""
from pathlib import Path
import math
import re
import struct
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parent

def main():
    original=(ROOT.parent/'exponential/exponential.s').read_text()
    core='exp_milli:\n'+original.split('\nexp_milli:\n',1)[1].split('\n# Display signed input',1)[0]
    (ROOT/'exponential_core.s').write_text('# Extracted unchanged from ../exponential/exponential.s\n'+core)
    table=['# atan(2^-i) scaled to a full turn of 2^32. Stored in DMEM.','init_trig_table:']
    for i in range(30):
        angle=round(math.atan(2.0**-i)/(2*math.pi)*2**32)
        table.extend([f'    li t0, {angle}',f'    sw t0, {128+4*i}(s1)'])
    table.append('    ret')
    (ROOT/'trig_table.s').write_text('\n'.join(table)+'\n')
    arithmetic='calculate:\n'+(ROOT.parent/'full_calculator/full_calculator.s').read_text().split('\ncalculate:\n',1)[1].split('\n# Render active-high',1)[0]
    labels=re.findall(r'^([A-Za-z_]\w*):',arithmetic,re.M)
    arithmetic=re.sub(r'\b('+'|'.join(labels)+r')\b',lambda m:'arith_'+m[0],arithmetic)
    (ROOT/'arithmetic_core.s').write_text('# Reused calculator routines; labels namespaced.\n'+arithmetic)
    combined='\n'.join([(ROOT/'scientific_hps.s').read_text(),core,
                        (ROOT/'trigonometry.s').read_text(),arithmetic,'\n'.join(table)])
    with tempfile.TemporaryDirectory(prefix='scientific-build-') as tmp:
        work=Path(tmp); (work/'combined.s').write_text(combined+'\n')
        subprocess.run(['riscv64-unknown-elf-as','-march=rv32i','-mabi=ilp32','-mno-relax',
                        '-o',str(work/'app.o'),str(work/'combined.s')],check=True)
        subprocess.run(['riscv64-unknown-elf-ld','-m','elf32lriscv','--no-relax',
                        '-Ttext=0x80000000','-e','_start','-o',str(work/'app.elf'),str(work/'app.o')],check=True)
        subprocess.run(['riscv64-unknown-elf-objcopy','-O','binary','-j','.text',
                        str(work/'app.elf'),str(work/'app.bin')],check=True)
        data=(work/'app.bin').read_bytes()
        dis=subprocess.check_output(['riscv64-unknown-elf-objdump','-d','-M','no-aliases',str(work/'app.elf')],text=True)
    if len(data)%4 or len(data)>4096: raise ValueError('Firmware exceeds 4 KiB IMEM')
    words=struct.unpack('<'+'I'*(len(data)//4),data)
    (ROOT/'scientific_hps.mem').write_text(''.join(f'{x:08x}\n' for x in words)+'00000013\n'*(1024-len(words)))
    (ROOT/'scientific_hps.dis').write_text(dis)
    print(f'Scientific firmware: {len(data)} bytes / 4096; RV32I only')

if __name__=='__main__': main()
