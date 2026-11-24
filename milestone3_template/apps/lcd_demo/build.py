#!/usr/bin/env python3
"""Generate LCD demo artifacts only; no tests, simulation or Quartus build."""
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parent
def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True)

def main():
    run('riscv64-unknown-elf-as','-march=rv32i','-mabi=ilp32','-mno-relax',
        '-o','lcd_demo.o','lcd_demo.s')
    run('riscv64-unknown-elf-ld','-m','elf32lriscv','--no-relax',
        '-Ttext=0x80000000','-e','_start','-o','lcd_demo.elf','lcd_demo.o')
    run('riscv64-unknown-elf-objcopy','-O','binary','-j','.text',
        'lcd_demo.elf','lcd_demo.bin')
    data=(ROOT/'lcd_demo.bin').read_bytes()
    if len(data)%4 or len(data)>4096:
        raise RuntimeError('Image does not fit 4 KiB IMEM')
    words=struct.unpack(f'<{len(data)//4}I',data)
    image=''.join(f'{word:08x}\n' for word in words)
    image+='00000013\n'*(1024-len(words))
    (ROOT/'lcd_demo.mem').write_text(image)
    (ROOT/'lcd_demo.dis').write_text(run(
        'riscv64-unknown-elf-objdump','-d','-M','no-aliases','lcd_demo.elf'))
    print(f'Generated lcd_demo.mem: {len(data)} program bytes, padded to 4096 bytes')

if __name__=='__main__':
    main()
