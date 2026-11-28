#!/usr/bin/env python3
"""Compile and run the real MCU RTL with the delivered .mem image."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
SRC = ROOT.parents[1] / '00_src'
VERILATOR = os.environ.get('VERILATOR', '/home/lqhau/tools/oss-cad-suite/bin/verilator')
if not Path(VERILATOR).is_file():
    VERILATOR = 'verilator'

def main():
    files = [SRC/'rv32i_pkg.sv'] + sorted(p for p in SRC.glob('*.sv') if p.name != 'rv32i_pkg.sv')
    with tempfile.TemporaryDirectory(prefix='calculator-rtl-') as tmp:
        work = Path(tmp)
        shutil.copy2(ROOT/'full_calculator.mem',work/'full_calculator.mem')
        command = [VERILATOR,'--binary','--timing','--assert','--sv',
                   '--top-module','tb_calculator','--Mdir',str(work/'obj'),
                   '--build-jobs','4','-Wno-fatal','+incdir+'+str(SRC)]
        command += list(map(str,files)) + [str(ROOT/'board_tb_device.sv'),str(ROOT/'tb_calculator.sv')]
        env = dict(os.environ)
        if shutil.which('g++-10'):
            env['MAKEFLAGS']='CXX=g++-10'
        result = subprocess.run(command,cwd=work,env=env,text=True,capture_output=True)
        (ROOT/'rtl_build.log').write_text(result.stdout+result.stderr)
        if result.returncode:
            raise RuntimeError('RTL build failed; see rtl_build.log')
        result = subprocess.run([str(work/'obj/Vtb_calculator')],cwd=work,text=True,capture_output=True)
        (ROOT/'rtl_test.log').write_text(result.stdout+result.stderr)
        print(result.stdout+result.stderr,end='')
        result.check_returncode()

if __name__ == '__main__':
    main()
