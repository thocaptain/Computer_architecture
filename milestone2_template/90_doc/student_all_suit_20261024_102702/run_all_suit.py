from pathlib import Path
import csv
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import tempfile
from datetime import datetime

repo = Path('/home/lqhau/RISC-V-RV32i-master')
template = Path('/mnt/f/master/CTMT/milestone_2/milestone2_template')
src = template / '00_src'
report = template / '90_doc' / ('student_all_suit_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
report.mkdir(parents=True)
names = ['rv32i_pkg.sv', 'control.sv', 'regfile.sv', 'alu.sv', 'branch_comp.sv',
         'lsu_dat_handler.sv', 'rv32i_single_cycle.sv', 'singlecycle.sv', 'imem.sv', 'dmem.sv']

tb = r'''
module tb_all_suit;
    logic clk = 0;
    logic rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] sampled_addr, sampled_wdata;
    logic [3:0] sampled_mask;
    logic sampled_wren, sampled_valid;
    logic [31:0] ledr = 0;
    logic [31:0] ledg = 0;
    logic [31:0] report_addr;
    logic [31:0] data_base;
    logic [31:0] stack_top;
    integer retired = 0;
    integer memory_accesses = 0;
    integer stores = 0;

    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem data_memory (.i_clk(clk), .i_addr(addr), .i_wdata(wdata),
        .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));

    initial begin
        if (!$value$plusargs("REPORT=%h", report_addr)
            || !$value$plusargs("DATA_BASE=%h", data_base)
            || !$value$plusargs("STACK_TOP=%h", stack_top))
            $fatal(1, "Missing test parameters");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren)
                else $fatal(1, "Invalid PC/valid/write during reset");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 1000000; cycle++) begin
            #5;
            sampled_addr = addr;
            sampled_wdata = wdata;
            sampled_mask = mask;
            sampled_wren = wren;
            sampled_valid = valid;
            assert (sampled_valid) else $fatal(1, "Invalid instruction at PC=%h", pc);
            assert (pc[31] && pc[1:0] == 0) else $fatal(1, "Bad instruction PC=%h", pc);
            if (instruction[6:0] == 7'h03 || instruction[6:0] == 7'h23) begin
                memory_accesses++;
                // The high-map runs must keep every memory access in DMEM.
                if (data_base[31])
                    assert (addr >= data_base && addr < stack_top)
                        else $fatal(1, "Out-of-map data access: %h", addr);
            end
            clk = 1;
            #5;
            if (sampled_valid) retired++;
            if (sampled_wren) begin
                stores++;
                if (sampled_addr == report_addr) begin
                    assert (sampled_mask == 4'hF) else $fatal(1, "Partial LEDR report");
                    ledr = sampled_wdata;
                end
                if (sampled_addr == report_addr + 16) begin
                    assert (sampled_mask == 4'hF) else $fatal(1, "Partial LEDG report");
                    ledg = sampled_wdata;
                    assert (ledr == 32'h3FFF && ledg == 32'h600D)
                        else $fatal(1, "all_suit FAIL: LEDR=%h LEDG=%h PC=%h", ledr, ledg, pc);
                    assert (retired == cycle) else $fatal(1, "IPC differs from one");
                    $display("ALL_SUIT PASS checks=14/14 cycles=%0d instructions=%0d reset_cycles=2 total_cycles=%0d IPC=1.000000 LEDR=0x%08h LEDG=0x%08h memory_accesses=%0d stores=%0d", cycle, retired, cycle+2, ledr, ledg, memory_accesses, stores);
                    $finish;
                end
            end
            clk = 0;
        end
        $fatal(1, "all_suit timeout: PC=%h LEDR=%h LEDG=%h", pc, ledr, ledg);
    end
endmodule
'''
(report / 'tb_all_suit.sv').write_text(tb)
hashes = {name: hashlib.sha256((src / name).read_bytes()).hexdigest() for name in names}
(report / 'rtl_sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
shutil.copy2(__file__, report / 'run_all_suit.py')

def run(command, cwd, log):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            env=dict(os.environ, MAKEFLAGS='CXX=g++-10'))
    (report / log).write_text(result.stdout + result.stderr)
    if result.returncode:
        print(result.stdout[-5000:])
        print(result.stderr[-5000:])
        print('Reports:', report)
        raise SystemExit(result.returncode)
    return result.stdout

variants = [
    ('original_rom', 0x2000, 0x4000, 0x7000),
    ('ta_c_map', 0x80080000, 0x80090000, 0x8008F000),
    ('ta_isa_map', 0x84000000, 0x84010000, 0x8400F000),
]
results = []
with tempfile.TemporaryDirectory(prefix='codex_all_suit_') as temporary:
    work = Path(temporary)
    (work / 'program.mem').write_text('00000013\n')
    (work / 'tb_all_suit.sv').write_text(tb)
    run(['/home/lqhau/tools/oss-cad-suite/bin/verilator', '--binary', '--timing', '--assert',
         '-Wall', '-Wno-UNUSEDSIGNAL', '-Wno-UNUSEDPARAM', '-Wno-EOFNEWLINE',
         '-Wno-PINCONNECTEMPTY', '-Wno-TIMESCALEMOD', '-Wno-BLKSEQ',
         '-CFLAGS', '-std=gnu++20', '--top-module', 'tb_all_suit', '--Mdir', str(work / 'build'),
         '-j', '2'] + [str(src / name) for name in names] + [str(work / 'tb_all_suit.sv')],
        work, 'build.log')
    original = (repo / '02_test/asm/all_suit.s').read_text()
    for name, data_base, stack_top, reporting in variants:
        if name == 'original_rom':
            shutil.copy2(repo / '02_test/dump/all_suit.mem', work / 'program.mem')
        else:
            assembly = original
            for pattern, replacement, expected in [
                (r'(\blui\s+sp,\s*)0x4\b', rf'\g<1>0x{stack_top >> 12:x}', 1),
                (r'(\blui\s+s0,\s*)0x2\b', rf'\g<1>0x{data_base >> 12:x}', 1),
                (r'(\blui\s+t0,\s*)0x4\b', rf'\g<1>0x{stack_top >> 12:x}', 1),
                (r'(\blui\s+t0,\s*)0x7\b', rf'\g<1>0x{reporting >> 12:x}', 1),
            ]:
                assembly, count = re.subn(pattern, replacement, assembly)
                assert count == expected, pattern
            (report / (name + '.s')).write_text(assembly)
            (work / 'program.s').write_text(assembly)
            run(['riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-mno-relax',
                 '-o', 'program.o', 'program.s'], work, name + '_assemble.log')
            run(['riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
                 '-Ttext=0x80000000', '-e', 'main', '-o', 'program.elf', 'program.o'],
                work, name + '_link.log')
            run(['riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text',
                 'program.elf', 'program.bin'], work, name + '_objcopy.log')
            binary = (work / 'program.bin').read_bytes()
            words = struct.unpack(f'<{len(binary)//4}I', binary)
            # Validate that the only machine-code changes are the four LUIs.
            baseline = [int(word, 16) for word in
                        (repo / '02_test/dump/all_suit.mem').read_text().split()]
            assert len(words) <= len(baseline)
            differences = [(index, old, new) for index, (old, new) in
                           enumerate(zip(baseline, words)) if old != new]
            assert len(differences) == 4, differences
            assert all((old & 0xfff) == (new & 0xfff) and (old & 0x7f) == 0x37
                       for _, old, new in differences)
            (report / (name + '_changed_words.json')).write_text(json.dumps(differences, indent=2) + '\n')
            (work / 'program.mem').write_text(''.join(f'{word:08x}\n' for word in words))
        shutil.copy2(work / 'program.mem', report / (name + '.mem'))
        output = run([str(work / 'build/Vtb_all_suit'), f'+REPORT={reporting:08x}',
                      f'+DATA_BASE={data_base:08x}', f'+STACK_TOP={stack_top:08x}'],
                     work, name + '.log')
        line = next(line for line in output.splitlines() if line.startswith('ALL_SUIT PASS'))
        fields = dict(re.findall(r'(\w+)=([^ ]+)', line))
        results.append(dict(variant=name, status='PASS', **fields))
        print(name + ': ' + line)

assert hashes == {name: hashlib.sha256((src / name).read_bytes()).hexdigest() for name in names}
with (report / 'results.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)
lines = ['# all_suit on the TA singlecycle interface', '',
         'Source RTL: `../../00_src`; fingerprints are recorded in `rtl_sha256.json`.',
         'Simulator: Verilator 5.053; instruction-memory format: 4B.', '',
         '| Run | Checks | Active cycles | Reset cycles | Total cycles | Instructions | IPC | LEDR | LEDG |',
         '| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |']
for row in results:
    lines.append('| ' + ' | '.join(str(row[k]) for k in ['variant', 'checks', 'cycles',
                 'reset_cycles', 'total_cycles', 'instructions', 'IPC', 'LEDR', 'LEDG']) + ' |')
lines += ['', 'All runs start at PC `0x80000000` and instantiate the actual `singlecycle`,',
          '`imem` and `dmem` modules from the F: template.',
          'The original ROM is unchanged and uses legacy addresses 0x2000/0x4000/0x7000;',
          'the simplified memories index low address bits, so this is an aliasing diagnostic.',
          'The C-map and ISA-map runs use valid DMEM addresses from the PDF.',
          'Only four LUI words are changed: data base, stack top, stack-balance check and result address.',
          'All algorithm instructions and all 14 pass/fail conditions match the original ROM.',
          'LEDR/LEDG names refer to the program result words observed by this student testbench;',
          'the TA CPU interface has no physical LED ports. Stores are checked after their clock edge.',
          'Every active clock edge reports one completed instruction. Two reset cycles are excluded from IPC.',
          'The stock mode-0 benchmark previously took 84475 total cycles because its internal memory waits;',
          'the external asynchronous-memory adapter uses a different memory timing model.',
          'This is a student regression, not the official TA testbench.', '']
(report / 'summary.md').write_text('\n'.join(lines))
print('Reports:', report)
