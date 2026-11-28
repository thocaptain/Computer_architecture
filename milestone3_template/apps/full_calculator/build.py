#!/usr/bin/env python3
"""Build on Linux/WSL with GNU RISC-V binutils; no Python dependencies."""
from pathlib import Path
import hashlib
import struct
import subprocess

ROOT = Path(__file__).resolve().parent

def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True)

def main():
    run('riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-mno-relax',
        '-o', 'full_calculator.o', 'full_calculator.s')
    run('riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
        '-Ttext=0x80000000', '-e', '_start', '-o', 'full_calculator.elf', 'full_calculator.o')
    run('riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text',
        'full_calculator.elf', 'full_calculator.bin')
    data = (ROOT / 'full_calculator.bin').read_bytes()
    assert len(data) % 4 == 0
    assert len(data) <= 4096, 'Program exceeds default wrapper 4 KiB IMEM'
    words = struct.unpack(f'<{len(data)//4}I', data)
    # Fill the remainder with NOPs: exactly 1024 words for 4 KiB IMEM.
    mem = ''.join(f'{word:08x}\n' for word in words)
    mem += '00000013\n' * (1024 - len(words))
    (ROOT / 'full_calculator.mem').write_text(mem)
    (ROOT / 'full_calculator.dis').write_text(run(
        'riscv64-unknown-elf-objdump', '-d', '-M', 'no-aliases', 'full_calculator.elf'))
    print(f'{len(data)} bytes / 4096 bytes; {len(words)} program words; entry 0x80000000')
    print('MEM SHA256:', hashlib.sha256(mem.encode()).hexdigest())

if __name__ == '__main__':
    main()
