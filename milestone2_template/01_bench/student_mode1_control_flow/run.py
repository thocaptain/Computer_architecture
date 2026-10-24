#!/usr/bin/env python3
"""Student regressions for pipeline EX-redirect/ID-stall interactions.

Run under WSL: python3 run.py --mode 1 --suite smoke|stress --label check.
These vectors recreate the reported behavior; they are not the TA binaries.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
from datetime import datetime

parser = argparse.ArgumentParser()
parser.add_argument('--suite', choices=['smoke', 'stress'], default='stress')
parser.add_argument('--mode', type=int, choices=range(1, 6), default=1)
parser.add_argument('--label', default='check')
parser.add_argument('--source', type=Path, help='Optional source snapshot for before/after comparisons')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
manifest = json.loads((root / '90_doc/cpu_modes/modes.json').read_text())
selected = next(item for item in manifest if item['mode'] == args.mode)
source = args.source.resolve() if args.source else root / selected['folder']
selected = next((item for item in manifest if item['folder'] == source.name), selected)
names = selected['files']
report = root / '90_doc/control_flow_modes' / (datetime.now().strftime('%Y%m%d_%H%M%S') + '_mode' + str(selected['mode']) + '_' + args.label)
report.mkdir(parents=True)
snapshot = report / 'rtl_snapshot'
snapshot.mkdir()
for file in source.iterdir():
    if file.is_file():
        shutil.copy2(file, snapshot / file.name)

tb = r'''
module tb_mode1_control_flow;
    logic clk = 0, rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] reported_case = 0;
    logic sampled_write;
    logic [31:0] sampled_addr, sampled_data;
    integer expected;
    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.ADDR_WIDTH(26), .PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem #(.START_ADDR(32'h84000000)) data_memory
        (.i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));
    initial begin : run_test
        if (!$value$plusargs("EXPECTED=%d", expected)) $fatal(1, "Missing expected count");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren) else $fatal(1, "Bad reset");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 10000000; cycle++) begin
            #5;
            sampled_write = wren;
            sampled_addr = addr;
            sampled_data = wdata;
            if (sampled_write && sampled_addr == 32'h8400F000) reported_case = sampled_data;
            if ((dut.cpu.core.EX_is_pred_wrong || dut.cpu.core.EX_is_jalr_inst)
                && dut.cpu.core.EX_is_depend_load)
                $display("REDIRECT_AND_ID_STALL cycle=%0d pc=%h EX_pc=%h EX_inst=%h ID_pc=%h ID_inst=%h pc_en=%b",
                    cycle, pc, dut.cpu.core.ID_EX_dreg_q.pc, dut.cpu.core.ID_EX_dreg_q.inst,
                    dut.cpu.core.IF_ID_dreg_q.pc, dut.cpu.core.IF_ID_dreg_q.inst, dut.cpu.core.pc_en);
            clk = 1; #5;
            if (sampled_write && sampled_addr == 32'h8400F010) begin
                if (sampled_data != 32'h600D || reported_case != 32'(expected)) begin
                    $display("RESULT FAIL first_case=%0d status=%h cycles=%0d", reported_case, sampled_data, cycle);
                    $finish;
                    disable run_test;
                end
                $display("RESULT PASS cases=%0d cycles=%0d", reported_case, cycle);
                $finish;
                disable run_test;
            end
            clk = 0;
        end
        $display("RESULT TIMEOUT first_case=%0d pc=%h", reported_case, pc);
        $finish;
    end
endmodule
'''
(report / 'tb_mode1_control_flow.sv').write_text(tb)

def execute(command, cwd, log):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            env=dict(os.environ, MAKEFLAGS='CXX=g++-10'))
    log.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(str(log) + '\n' + (result.stdout + result.stderr)[-4000:])
    return result.stdout

def header():
    return ['.option norvc', '.option norelax', '.option nopic', '.section .text',
            '.globl _start', '_start:', 'lui x24, 0x8400f', 'lui x25, 0x84000',
            'li x30, 1', 'sw x30, 0(x25)']

def fail_inline(label):
    return ['sw x26, 0(x24)', 'li x30, 0x0bad', 'sw x30, 16(x24)', label + ':', 'j ' + label]

def check_equal(lhs, rhs, label):
    return [f'beq {lhs}, {rhs}, {label}_ok'] + fail_inline(label + '_fail') + [label + '_ok:']

def footer(count):
    return [f'li x26, {count}', 'sw x26, 0(x24)', 'li x30, 0x600d', 'sw x30, 16(x24)', 'halt:', 'j halt']

predicates = {
    'beq': lambda a,b: a == b, 'bne': lambda a,b: a != b,
    'blt': lambda a,b: signed(a) < signed(b), 'bge': lambda a,b: signed(a) >= signed(b),
    'bltu': lambda a,b: a < b, 'bgeu': lambda a,b: a >= b,
}
def signed(value):
    return value if value < 0x80000000 else value - 0x100000000

def smoke_jalr():
    return header() + ['li x26, 1', 'li x28, 0', 'lui x5, %hi(target)',
        'addi x5, x5, %lo(target)', 'jalr x1, 0(x5)', 'addi x28, x1, 0'] \
        + fail_inline('wrong_fallthrough') + ['target:'] \
        + check_equal('x28', 'x0', 'wrong_path') + footer(1)

def smoke_branch(op):
    a, b = {'beq':(0,0), 'bne':(0,1), 'blt':(0,1), 'bge':(0,0),
            'bltu':(0,1), 'bgeu':(0,0)}[op]
    return header() + ['li x26, 1', 'li x28, 0', f'li x6, {a}', f'li x7, {b}', 'nop', 'nop', 'nop',
        'addi x5, x0, 1', f'{op} x6, x7, target', 'addi x28, x5, 0'] \
        + fail_inline('wrong_fallthrough') + ['target:'] \
        + check_equal('x28', 'x0', 'wrong_path') + footer(1)

def branch_vectors(op, count):
    lines = header()
    edges = [0,1,0xffffffff,0x80000000,0x7fffffff,0x80000001,0x7ffffffe,
             0xaaaaaaaa,0x55555555,0x10000,0xffff0000,0x12345678]
    state = 0x14597a31
    for i in range(count):
        r1 = i % 24
        r2 = (i // 24) % 24
        state = (1664525 * state + 1013904223) & 0xffffffff
        a = edges[i % len(edges)] if i % 3 else state
        b = a if i % 4 == 0 else edges[(i // 7) % len(edges)] if i % 3 else (state ^ 0xffffffff)
        actual_a = 0 if r1 == 0 else b if r1 == r2 else a
        actual_b = 0 if r2 == 0 else b
        taken = predicates[op](actual_a, actual_b)
        prefix = f'{op}_{i}'
        lines += [f'li x26, {i+1}', 'li x28, 0', f'li x{r1}, {signed(a)}', f'li x{r2}, {signed(b)}']
        lines += ['nop', 'nop', 'nop']
        lines += ['lw x29, 0(x25)' if i % 2 else 'addi x29, x0, 1']
        lines += ['nop'] * ((i // 576) % 3)
        lines += [f'{op} x{r1}, x{r2}, {prefix}_taken', 'addi x28, x29, 0',
                  f'j {prefix}_end', prefix + '_taken:', 'nop', prefix + '_end:',
                  f'li x31, {0 if taken else 1}']
        lines += check_equal('x28', 'x31', prefix + '_check')
    return lines + footer(count)

def jalr_vectors(count):
    lines = header()
    for i in range(count):
        imm = i - 2048
        rs = 1 + (i % 23)
        rd = rs if i % 4 == 0 else (i // 23) % 24
        odd = (i // 16) & 1
        label = f'jalr_{i}'
        lines += [f'li x26, {i+1}', 'li x28, 0', f'lui x{rs}, %hi({label}_target)',
                  f'addi x{rs}, x{rs}, %lo({label}_target)', f'li x30, {-imm+odd}',
                  f'add x{rs}, x{rs}, x30']
        if i % 5 == 0:
            lines += [f'sw x{rs}, 8(x25)', f'lw x{rs}, 8(x25)']
        lines += [f'jalr x{rd}, {imm}(x{rs})', label + '_return:',
                  f'addi x28, x{rd if rd else rs}, 0']
        lines += fail_inline(label + '_wrong_path')
        lines += [label + '_target:', 'auipc x29, 0', f'lui x31, %hi({label}_target)',
                  f'addi x31, x31, %lo({label}_target)']
        lines += check_equal('x29', 'x31', label + '_pc')
        lines += check_equal('x28', 'x0', label + '_side_effect')
        if rd:
            lines += [f'lui x31, %hi({label}_return)', f'addi x31, x31, %lo({label}_return)']
            lines += check_equal(f'x{rd}', 'x31', label + '_link')
    return lines + footer(count)

tests = [('jalr_redirect_vs_stall', 1, smoke_jalr())]
tests += [(op + '_redirect_vs_stall', 1, smoke_branch(op)) for op in predicates]
if args.suite == 'stress':
    tests += [('JALR_TARGET', 4096, jalr_vectors(4096))]
    tests += [(op.upper() + '_COMPARE', 7094, branch_vectors(op, 7094)) for op in predicates]

rows = []
with tempfile.TemporaryDirectory(prefix='codex_mode1_control_') as temporary:
    work = Path(temporary)
    (work / 'tb_mode1_control_flow.sv').write_text(tb)
    execute(['/home/lqhau/tools/oss-cad-suite/bin/verilator', '--binary', '--timing', '--assert',
             '-Wall', '-Wno-UNUSEDSIGNAL', '-Wno-UNUSEDPARAM', '-Wno-EOFNEWLINE',
             '-Wno-PINCONNECTEMPTY', '-Wno-TIMESCALEMOD', '-Wno-BLKSEQ',
             '-CFLAGS', '-std=gnu++20', '--top-module', 'tb_mode1_control_flow',
             '--Mdir', str(work / 'build'), '-j', '2', '-I' + str(source)]
            + [str(source / name) for name in names] + [str(work / 'tb_mode1_control_flow.sv')],
            work, report / 'build.log')
    for name, count, assembly in tests:
        (report / (name + '.s')).write_text('\n'.join(assembly) + '\n')
        shutil.copy2(report / (name + '.s'), work / 'program.s')
        execute(['riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-mno-relax',
                 '-o', 'program.o', 'program.s'], work, report / (name + '_assemble.log'))
        execute(['riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
                 '-Ttext=0x80000000', '-e', '_start', '-o', 'program.elf', 'program.o'],
                work, report / (name + '_link.log'))
        execute(['riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text',
                 'program.elf', 'program.bin'], work, report / (name + '_objcopy.log'))
        binary = (work / 'program.bin').read_bytes()
        words = struct.unpack(f'<{len(binary)//4}I', binary)
        (work / 'program.mem').write_text(''.join(f'{word:08x}\n' for word in words))
        shutil.copy2(work / 'program.mem', report / (name + '.mem'))
        output = execute([str(work / 'build/Vtb_mode1_control_flow'), f'+EXPECTED={count}'],
                         work, report / (name + '.log'))
        result = next(line for line in output.splitlines() if line.startswith('RESULT '))
        status = result.split()[1]
        rows.append(dict(test=name, status=status, cases=count, result=result))
        print(name + ': ' + result, flush=True)

with (report / 'results.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
print('REPORT=' + str(report), flush=True)
raise SystemExit(0 if all(row['status'] == 'PASS' for row in rows) else 1)
