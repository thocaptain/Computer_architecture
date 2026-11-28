#!/usr/bin/env python3
"""Assemble/link the exponential app and write a 4 KiB readmemh image.

This is artifact generation only: no simulation, tests or Quartus invocation.
Requires GNU RISC-V binutils on Linux/WSL.
"""
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parent
NAME = 'exponential'

def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True)

def main():
    run('riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-mno-relax',
        '-o', NAME+'.o', NAME+'.s')
    run('riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
        '-Ttext=0x80000000', '-e', '_start', '-o', NAME+'.elf', NAME+'.o')
    run('riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text',
        NAME+'.elf', NAME+'.bin')
    data = (ROOT/(NAME+'.bin')).read_bytes()
    if len(data) % 4 or len(data) > 4096:
        raise RuntimeError('Image must fit in the wrapper 4 KiB IMEM')
    words = struct.unpack(f'<{len(data)//4}I', data)
    image = ''.join(f'{word:08x}\n' for word in words)
    image += '00000013\n' * (1024-len(words))
    (ROOT/(NAME+'.mem')).write_text(image)
    (ROOT/(NAME+'.dis')).write_text(run(
        'riscv64-unknown-elf-objdump','-d','-M','no-aliases',NAME+'.elf'))
    print(f'Generated {NAME}.mem: {len(data)} program bytes, padded to 4096 bytes')

if __name__ == '__main__':
    main()
