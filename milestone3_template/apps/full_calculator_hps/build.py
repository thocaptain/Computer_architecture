#!/usr/bin/env python3
"""Reuse the original calculator core and build a separate HPS firmware image."""
from pathlib import Path
import hashlib
import struct
import subprocess
import tempfile
import shutil

ROOT = Path(__file__).resolve().parent
ORIGINAL = ROOT.parent/'full_calculator/full_calculator.s'

def main():
    original = ORIGINAL.read_text()
    core = original.split('\ncalculate:\n', 1)[1].split('\n# Render active-high', 1)[0]
    core = '# Extracted unchanged from ../full_calculator/full_calculator.s\ncalculate:\n' + core
    (ROOT/'calculator_core.s').write_text(core)
    with tempfile.TemporaryDirectory(prefix='hps-calculator-') as tmp:
        work = Path(tmp)
        (work/'combined.s').write_text((ROOT/'full_calculator_hps.s').read_text()+'\n'+core)
        subprocess.run(['riscv64-unknown-elf-as','-march=rv32i','-mabi=ilp32','-mno-relax',
                        '-o',str(work/'firmware.o'),str(work/'combined.s')],check=True)
        subprocess.run(['riscv64-unknown-elf-ld','-m','elf32lriscv','--no-relax',
                        '-Ttext=0x80000000','-e','_start','-o',str(work/'firmware.elf'),
                        str(work/'firmware.o')],check=True)
        subprocess.run(['riscv64-unknown-elf-objcopy','-O','binary','-j','.text',
                        str(work/'firmware.elf'),str(work/'firmware.bin')],check=True)
        data = (work/'firmware.bin').read_bytes()
        dis = subprocess.check_output(['riscv64-unknown-elf-objdump','-d','-M','no-aliases',
                                      str(work/'firmware.elf')],text=True)
    if len(data)%4 or len(data)>4096:
        raise ValueError('Firmware does not fit 4 KiB IMEM')
    words = struct.unpack('<'+'I'*(len(data)//4),data)
    image = ''.join(f'{x:08x}\n' for x in words)+'00000013\n'*(1024-len(words))
    (ROOT/'full_calculator_hps.mem').write_text(image)
    shutil.copyfile(ROOT/'full_calculator_hps.mem',
                    ROOT.parents[1]/'00_src_hps/full_calculator_hps.mem')
    (ROOT/'full_calculator_hps.dis').write_text(dis)
    (ROOT/'core_origin.txt').write_text('Arithmetic extracted unchanged from '+str(ORIGINAL.relative_to(ROOT.parent.parent))+
                                     '\nOriginal SHA256: '+hashlib.sha256(original.encode()).hexdigest()+'\n')
    print(f'Calculator firmware: {len(data)} bytes / 4096 bytes; pure RV32I')

if __name__=='__main__':
    main()
