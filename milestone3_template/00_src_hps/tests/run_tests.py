#!/usr/bin/env python3
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    subprocess.run(['python3', str(ROOT/'build_firmware.py')], check=True)
    files = [ROOT/'rv32i_pkg.sv'] + sorted(
        p for p in ROOT.glob('*.sv')
        if p.name != 'rv32i_pkg.sv' and not p.name.startswith('example_'))
    with tempfile.TemporaryDirectory(prefix='hps-mcu-test-') as tmp:
        work = Path(tmp)
        shutil.copyfile(ROOT/'hps_mailbox.mem', work/'hps_mailbox.mem')
        bundled = Path('/home/lqhau/tools/oss-cad-suite/bin/verilator')
        verilator = os.environ.get('VERILATOR', str(bundled) if bundled.is_file() else 'verilator')
        args = [verilator, '--binary', '--timing', '--assert', '--sv',
                '--top-module', 'tb_hps', '--Mdir', str(work/'obj'),
                '--build-jobs', '2', '-Wno-fatal', '+incdir+'+str(ROOT)]
        args += list(map(str, files)) + [str(ROOT/'tests/tb_hps.sv')]
        env = dict(os.environ)
        if shutil.which('g++-10'): env['MAKEFLAGS'] = 'CXX=g++-10'
        result = subprocess.run(args, cwd=work, env=env, text=True, capture_output=True)
        (ROOT/'tests/build.log').write_text(result.stdout + result.stderr)
        result.check_returncode()
        result = subprocess.run([str(work/'obj/Vtb_hps')], cwd=work, text=True, capture_output=True)
        (ROOT/'tests/result.log').write_text(result.stdout + result.stderr)
        print(result.stdout + result.stderr, end='')
        result.check_returncode()

if __name__ == '__main__':
    main()
