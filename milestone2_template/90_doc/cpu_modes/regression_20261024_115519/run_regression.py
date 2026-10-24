from pathlib import Path
import concurrent.futures
import csv
import hashlib
import importlib.util
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from datetime import datetime

sys.dont_write_bytecode = True
repo = Path('/home/lqhau/RISC-V-RV32i-master')
root = Path('/mnt/f/master/CTMT/milestone_2/milestone2_template')
manifest = json.loads((root / '90_doc/cpu_modes/modes.json').read_text())
baseline_files = ['rv32i_pkg.sv', 'control.sv', 'regfile.sv', 'alu.sv', 'branch_comp.sv',
                  'lsu_dat_handler.sv', 'rv32i_single_cycle.sv', 'singlecycle.sv', 'imem.sv', 'dmem.sv']
configs = [dict(mode=0, folder='00_src', files=baseline_files)] + manifest
report = root / '90_doc/cpu_modes' / ('regression_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
report.mkdir()
shutil.copy2(__file__, report / 'run_regression.py')

tb = r'''
module tb_cpu_modes;
    logic clk = 0;
    logic rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] retire_pc, memory_pc;
    logic [31:0] sampled_addr, sampled_wdata, sampled_retire_pc, sampled_memory_pc;
    logic sampled_wren, sampled_valid;
    logic [31:0] reported_id = 0;
    logic [31:0] ending_pc = 0;
    logic report_seen = 0;
    integer expected, trace_file, retired = 0;
    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem data_memory (.i_clk(clk), .i_addr(addr), .i_wdata(wdata),
        .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));
`ifdef REFERENCE_SINGLE
    assign retire_pc = pc;
    assign memory_pc = pc;
`else
    assign retire_pc = dut.cpu.core.MEM_WB_dreg_q.pc;
    assign memory_pc = dut.cpu.core.EX_MEM_dreg_q.pc;
`endif
    initial begin
        if (!$value$plusargs("EXPECTED=%d", expected)) $fatal(1, "Missing expected result");
        trace_file = $fopen("retirement.trace", "w");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren)
                else $fatal(1, "Reset vector/valid/write incorrect");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 1000000; cycle++) begin
            #5;
            sampled_addr = addr;
            sampled_wdata = wdata;
            sampled_wren = wren;
            sampled_valid = valid;
            sampled_retire_pc = retire_pc;
            sampled_memory_pc = memory_pc;
            if (sampled_valid) begin
                assert (retire_pc[31] && retire_pc[1:0] == 0)
                    else $fatal(1, "Bad retired PC=%h", retire_pc);
                $fdisplay(trace_file, "%08h", retire_pc);
                retired++;
            end
            if (sampled_wren && sampled_addr == 32'h8008F000)
                reported_id = sampled_wdata;
            if (sampled_wren && sampled_addr == 32'h8008F010) begin
                assert (sampled_wdata == 32'h600D && reported_id == 32'(expected) && mask == 4'hF)
                    else $fatal(1, "Program FAIL: status=%h check/id=%h", sampled_wdata, reported_id);
                report_seen = 1;
                ending_pc = sampled_memory_pc;
            end
            clk = 1; #5;
            if (report_seen && sampled_valid && sampled_retire_pc == ending_pc) begin
                $fclose(trace_file);
                $display("PASS cycles=%0d retired=%0d total_cycles=%0d", cycle, retired, cycle+2);
                $finish;
            end
            clk = 0;
        end
        $fatal(1, "Timeout PC=%h", pc);
    end
endmodule
'''
(report / 'tb_cpu_modes.sv').write_text(tb)

def run(command, cwd, log):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            env=dict(os.environ, MAKEFLAGS='CXX=g++-10'))
    log.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'Command failed; inspect {log}\n' + (result.stdout + result.stderr)[-3000:])
    return result.stdout

with tempfile.TemporaryDirectory(prefix='codex_m2_modes_') as temp:
    temp = Path(temp)
    roms = temp / 'roms'
    roms.mkdir()
    spec = importlib.util.spec_from_file_location('card', repo / 'bench_CPU/tests/riscv_card/generate.py')
    card = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(card)
    emit_original = card.Case.emit
    def emit_high_memory(case, *lines):
        return emit_original(case, *(line.replace('lui s0, 2', 'lui s0, 0x80080') for line in lines))
    card.Case.emit = emit_high_memory
    for generate in [card.integer_cases, card.memory_cases, card.branch_cases,
                     card.jump_cases, card.hazard_cases, card.pseudo_cases]:
        generate()
    tests = []
    for case_id, case in enumerate(card.CASES, 1):
        assembly = ['.option norvc', '.option norelax', '.option nopic', '.section .text',
                    '.globl _start', '.extern card_data', '_start:', 'lui s8, 0x8008f',
                    f'li s11, {case_id}', 'li s10, 0'] + case.lines + [
                        'j pass', 'fail:', 'sw s10, 0(s8)', 'li t5, 0x0bad',
                        'sw t5, 16(s8)', 'j halt', 'pass:', 'sw s11, 0(s8)',
                        'li t5, 0x600d', 'sw t5, 16(s8)', 'halt:', 'j halt']
        (roms / 'case.s').write_text('\n'.join(assembly) + '\n')
        run(['riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-o', 'case.o', 'case.s'],
            roms, report / 'assemble.log')
        run(['riscv64-unknown-elf-ld', '-m', 'elf32lriscv', '--no-relax',
             '--defsym=card_data=0x80080000', '-Ttext=0x80000000', '-e', '_start',
             '-o', 'case.elf', 'case.o'], roms, report / 'link.log')
        run(['riscv64-unknown-elf-objcopy', '-O', 'binary', '-j', '.text', 'case.elf', 'case.bin'],
            roms, report / 'objcopy.log')
        binary = (roms / 'case.bin').read_bytes()
        words = struct.unpack(f'<{len(binary)//4}I', binary)
        path = roms / (case.name + '.mem')
        path.write_text(''.join(f'{word:08x}\n' for word in words))
        tests.append(dict(name=case.name, expected=case_id, rom=path))
    all_suit = sorted((root / '90_doc').glob('student_all_suit_*/ta_c_map.mem'))[-1]
    tests.append(dict(name='all_suit', expected=0x3FFF, rom=all_suit))
    golden_traces = {}

    def verify(config):
        mode = config['mode']
        source = root / config['folder']
        work = temp / f'mode{mode}'
        logs = report / f'mode{mode}'
        work.mkdir()
        logs.mkdir()
        (work / 'tb_cpu_modes.sv').write_text(tb)
        args = ['/home/lqhau/tools/oss-cad-suite/bin/verilator', '--binary', '--timing', '--assert',
                '-Wall', '-Wno-UNUSEDSIGNAL', '-Wno-UNUSEDPARAM', '-Wno-EOFNEWLINE',
                '-Wno-PINCONNECTEMPTY', '-Wno-TIMESCALEMOD', '-Wno-BLKSEQ',
                '-CFLAGS', '-std=gnu++20', '--top-module', 'tb_cpu_modes',
                '--Mdir', str(work / 'build'), '-j', '2', '-I' + str(source)]
        if mode == 0:
            args.append('+define+REFERENCE_SINGLE')
        run(args + [str(source / name) for name in config['files']] + [str(work / 'tb_cpu_modes.sv')],
            work, logs / 'build.log')
        rows = []
        for test in tests:
            shutil.copy2(test['rom'], work / 'program.mem')
            output = run([str(work / 'build/Vtb_cpu_modes'), f"+EXPECTED={test['expected']}"],
                         work, logs / (test['name'] + '.log'))
            match = re.search(r'PASS cycles=(\d+) retired=(\d+) total_cycles=(\d+)', output)
            assert match, test['name']
            trace = (work / 'retirement.trace').read_bytes()
            if mode == 0:
                golden_traces[test['name']] = trace
            elif trace != golden_traces[test['name']]:
                (logs / (test['name'] + '_actual.trace')).write_bytes(trace)
                (logs / (test['name'] + '_expected.trace')).write_bytes(golden_traces[test['name']])
                raise RuntimeError(f"Mode {mode} retirement trace mismatch: {test['name']}")
            rows.append(dict(test=test['name'], status='PASS', cycles=int(match[1]),
                             retired=int(match[2]), total_cycles=int(match[3]),
                             retirement_sha256=hashlib.sha256(trace).hexdigest()))
        with (logs / 'results.csv').open('w', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
        fingerprints = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                        for p in source.iterdir() if p.is_file()}
        (logs / 'rtl_sha256.json').write_text(json.dumps(fingerprints, indent=2) + '\n')
        result = dict(mode=mode, folder=config['folder'], instruction_cases=84, passed=84,
                      failed=0, all_suit='PASS', all_suit_cycles=rows[-1]['cycles'],
                      all_suit_retired=rows[-1]['retired'], retirement_trace='MATCH')
        print(json.dumps(result), flush=True)
        return result

    results = [verify(configs[0])]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results.extend(pool.map(verify, configs[1:]))

results.sort(key=lambda row: row['mode'])
with (report / 'summary.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=results[0].keys())
    writer.writeheader()
    writer.writerows(results)
lines = ['# External-memory CPU modes: regression results', '',
         'Simulator: Verilator 5.053. PC reset: 0x80000000; data: 0x80080000.',
         'Each run uses the actual IMEM/DMEM source files from its source folder.', '',
         '| Mode | Source folder | Instruction cases | all_suit | all_suit cycles | Retired instructions | Trace |',
         '| --- | --- | --- | --- | ---: | ---: | --- |']
for row in results:
    lines.append(f"| {row['mode']} | `{row['folder']}` | 84/84 PASS | PASS (14/14) | {row['all_suit_cycles']} | {row['all_suit_retired']} | {row['retirement_trace']} |")
lines += ['', 'Cycles exclude two reset cycles and end when the final result store retires.',
          'Pipeline measurements include filling the pipeline and all hazard/prediction bubbles.',
          'The pipeline retirement-PC sequence must match the single-cycle baseline exactly',
          'for every instruction test and all_suit; inserted flush NOPs are excluded.',
          'Source modes share asynchronous memory without cache or artificial memory latency.',
          'The 84 instruction cases are rebased copies of the student RISCV_CARD regression.',
          'all_suit is the prior C-map ROM with only its four address LUIs changed.',
          'These are student regressions; the official TA testbench and programs are unavailable.', '']
(report / 'summary.md').write_text('\n'.join(lines))
print('REPORT=' + str(report), flush=True)
