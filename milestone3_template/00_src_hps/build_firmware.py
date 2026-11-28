#!/usr/bin/env python3
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent

def main():
    with tempfile.TemporaryDirectory(prefix='hps-firmware-') as tmp:
        obj, elf, binary = (str(Path(tmp) / x) for x in ('demo.o', 'demo.elf', 'demo.bin'))
        subprocess.run(['riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32',
                        '-mno-relax', '-o', obj, str(ROOT/'hps_mailbox.s')], check=True)
        subprocess.run(['riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
                        '-Ttext=0x80000000', '-e', '_start', '-o', elf, obj], check=True)
        subprocess.run(['riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text',
                        elf, binary], check=True)
        data = Path(binary).read_bytes()
    if len(data) % 4 or len(data) > 4096:
        raise ValueError('Firmware must fit 4 KiB IMEM')
    words = struct.unpack('<' + 'I'*(len(data)//4), data)
    image = ''.join(f'{x:08x}\n' for x in words) + '00000013\n'*(1024-len(words))
    (ROOT/'hps_mailbox.mem').write_text(image)
    print(f'Firmware: {len(data)} bytes, padded to 4 KiB')

if __name__ == '__main__':
    main()
