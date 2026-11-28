#!/usr/bin/env python3
from pathlib import Path
import os
import random
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT.parents[1]/'00_src_hps'
HOST=SRC/'software'

def expected(a,b,operation):
    if operation==0: value=a+b
    elif operation==1: value=a-b
    elif operation==2: value=a*b
    else:
        if b==0: return 0,0,1
        if a==-(1<<31) and b==-1: return 0,0,2
        value=abs(a)//abs(b)
        if (a<0)!=(b<0): value=-value
        return value,a-value*b,0
    if not -(1<<31)<=value<(1<<31): return 0,0,2
    return value,0,0

def main():
    subprocess.run(['python3',str(ROOT/'build.py')],check=True)
    with tempfile.TemporaryDirectory(prefix='calculator-hps-test-') as tmp:
        work=Path(tmp)
        subprocess.run(['gcc','-std=gnu99','-Wall','-Wextra','-Werror','-fsanitize=undefined',
                        '-I'+str(HOST),str(ROOT/'tests/test_host.c'),str(HOST/'calculator_protocol.c'),
                        '-o',str(work/'test_host')],check=True)
        host_test=subprocess.run([str(work/'test_host')],text=True,capture_output=True,timeout=10)
        (ROOT/'tests/host.log').write_text(host_test.stdout+host_test.stderr)
        print(host_test.stdout+host_test.stderr,end='')
        host_test.check_returncode()
        edge=[0,1,-1,5,-5,65536,-65536,(1<<31)-1,-(1<<31)]
        pairs=[(a,b) for a in edge for b in edge]
        pairs += [(-905969664,1128352817),(12,-5),(-12,5),(-12,-5)]
        randomizer=random.Random(20261125)
        pairs += [(randomizer.randint(-(1<<31),(1<<31)-1),randomizer.randint(-(1<<31),(1<<31)-1)) for _ in range(64)]
        vectors=[]
        for a,b in pairs:
            for operation in range(4):
                vectors.extend([a,b,operation,*expected(a,b,operation)])
        count=len(vectors)//6
        (work/'vectors.mem').write_text(''.join(f'{v&0xffffffff:08x}\n' for v in vectors))
        shutil.copyfile(ROOT/'full_calculator_hps.mem',work/'full_calculator_hps.mem')
        files=[SRC/'rv32i_pkg.sv']+sorted(p for p in SRC.glob('*.sv') if p.name!='rv32i_pkg.sv' and not p.name.startswith('example_'))
        bundled=Path('/home/lqhau/tools/oss-cad-suite/bin/verilator')
        verilator=os.environ.get('VERILATOR',str(bundled) if bundled.exists() else 'verilator')
        args=[verilator,'--binary','--timing','--assert','--sv','--top-module','tb_calculator_hps',
              '-GCASES='+str(count),'--Mdir',str(work/'obj'),'--build-jobs','2','-Wno-fatal','+incdir+'+str(SRC)]
        args+=list(map(str,files))+[str(ROOT/'tests/tb_calculator_hps.sv')]
        env=dict(os.environ)
        if shutil.which('g++-10'): env['MAKEFLAGS']='CXX=g++-10'
        built=subprocess.run(args,cwd=work,env=env,text=True,capture_output=True)
        (ROOT/'tests/build.log').write_text(built.stdout+built.stderr)
        built.check_returncode()
        run=subprocess.run([str(work/'obj/Vtb_calculator_hps')],cwd=work,text=True,capture_output=True)
        (ROOT/'tests/result.log').write_text(run.stdout+run.stderr)
        print(run.stdout+run.stderr,end='')
        run.check_returncode()

if __name__=='__main__':
    main()
