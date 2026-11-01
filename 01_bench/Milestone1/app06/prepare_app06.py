"""Assemble actual RV32I firmware; prepare isolated FPGA/simulation file lists."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / '02_test/Milestone1/app06'
PROJECT = ROOT / '20_syn/altera/DE2-115/app06'
SRC = ROOT / '00_src'
M1 = SRC / 'Milestone1'


def run(args):
    subprocess.run([str(x) for x in args], check=True)


def prepare():
    PROJECT.mkdir(parents=True, exist_ok=True)
    gen = PROJECT / 'generated'
    gen.mkdir(exist_ok=True)
    assembly = (OUT / 'app06.S').read_text()
    def expand(match):
        strings = re.findall(r'"([^"]*)"', match[0])
        lines = []
        for row, value in enumerate(strings):
            value = value.rstrip()
            if len(value) > 16:
                raise ValueError(f'LCD row too long: {value!r}')
            if row:
                lines += ['li a0, 0x800000c0', 'jal ra, lcd_write']
            for ch in value.ljust(16):
                lines += [f'li a0, {0x80000200 | ord(ch):#x}', 'jal ra, lcd_write']
        return '\n'.join(lines)
    assembly = re.sub(r'^\s*#@lcd[^\n]*', expand, assembly, flags=re.M)
    expanded = OUT / 'app06.expanded.s'
    expanded.write_text(assembly)
    metadata = {}
    for name, hz in [('app06', 5000000), ('app06_sim', 1000)]:
        stem = OUT / name
        run(['riscv64-linux-gnu-as', '-march=rv32i', '-mabi=ilp32', '-mno-relax',
             '--defsym', f'APP_CPU_HZ={hz}', '-o', stem.with_suffix('.o'), expanded])
        run(['riscv64-linux-gnu-ld', '-m', 'elf32lriscv', '--no-relax', '-Ttext=0',
             '-e', '_start', '-o', stem.with_suffix('.elf'), stem.with_suffix('.o')])
        run(['riscv64-linux-gnu-objcopy', '-O', 'binary', '--only-section=.text',
             stem.with_suffix('.elf'), stem.with_suffix('.bin')])
        binary = stem.with_suffix('.bin').read_bytes()
        if len(binary) > 8192 or len(binary) % 4:
            raise RuntimeError(f'ROM does not fit: {len(binary)} bytes')
        words = [int.from_bytes(binary[i:i+4], 'little') for i in range(0,len(binary),4)]
        words += [0x13] * (2048-len(words))
        stem.with_suffix('.mem').write_text(''.join(f'{w:08x}\n' for w in words))
        dis = subprocess.check_output(['riscv64-linux-gnu-objdump', '-d', '-M', 'no-aliases',
                                       str(stem.with_suffix('.elf'))], text=True)
        stem.with_suffix('.dump').write_text(dis)
        # Decode all generated words with GNU, reject extensions/unrecognized code.
        if '\t.word\t' in dis or '\t.4byte\t' in dis:
            raise RuntimeError('Unknown instruction in GNU disassembly')
        metadata[name] = {'cpu_hz':hz, 'code_bytes':len(binary), 'rom_bytes':8192,
                          'sha256':hashlib.sha256(binary).hexdigest()}
    (OUT/'build.json').write_text(json.dumps(metadata, indent=2)+'\n')
    (PROJECT/'app06.mem').write_text((OUT/'app06.mem').read_text())
    for name in ['alu', 'regfile']:
        body = (M1/f'{name}.sv').read_text()
        body, count = re.subn(rf'(?m)^module\s+{name}\b', f'module milestone1_{name}', body)
        assert count == 1
        (gen/f'milestone1_{name}.sv').write_text(body)
    files = [SRC/'rv32i_pkg.sv', M1/'cpu_pkg.sv', M1/'adder.sv',
             M1/'magnitude_comparator.sv', M1/'shifter.sv',
             gen/'milestone1_alu.sv', gen/'milestone1_regfile.sv',
             M1/'data_mem_sync.sv']
    files += [M1/'cpu'/f'{n}.sv' for n in ['alu','regfile','branch_comp','data_mem']]
    files += [M1/'board/app06_inst_mem.sv']
    files += [SRC/f'{n}.sv' for n in ['control','lsu_dat_handler','lsu',
                                     'rv32i_single_cycle','TOP_SINGLE_CYCLE']]
    files += [M1/'board/app06_de2_115.sv']
    rel = lambda p: os.path.relpath(p, PROJECT).replace('\\','/')
    qsf = ['set_global_assignment -name FAMILY "Cyclone IV E"',
           'set_global_assignment -name DEVICE EP4CE115F29C7',
           'set_global_assignment -name TOP_LEVEL_ENTITY app06_de2_115',
           'set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files',
           'set_global_assignment -name NUM_PARALLEL_PROCESSORS 4',
           'set_global_assignment -name VERILOG_MACRO MILESTONE1_SYNC_MEMORY',
           'set_global_assignment -name SDC_FILE app06.sdc',
           f'set_global_assignment -name SEARCH_PATH "{rel(SRC)}"',
           'set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"']
    qsf += [f'set_global_assignment -name SYSTEMVERILOG_FILE "{rel(p)}"' for p in files]
    pins = json.loads((Path(__file__).parent/'pins.json').read_text())
    for name, (pin, voltage) in pins.items():
        qsf += [f'set_location_assignment PIN_{pin} -to {{{name}}}',
                f'set_instance_assignment -name IO_STANDARD "{voltage} V" -to {{{name}}}']
    (PROJECT/'app06.qsf').write_text('\n'.join(qsf)+'\n')
    (PROJECT/'app06.qpf').write_text('PROJECT_REVISION = "app06"\n')
    (OUT/'filelist').write_text('+define+MILESTONE1_SYNC_MEMORY\n'+
                               f'+incdir+{SRC.as_posix()}\n'+
                               '\n'.join(p.as_posix() for p in files)+'\n')
    print(json.dumps(metadata, indent=2))
    print(f'Prepared DE2-115 project: {PROJECT}')


if __name__ == '__main__':
    prepare()
