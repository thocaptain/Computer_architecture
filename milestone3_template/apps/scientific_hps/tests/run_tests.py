#!/usr/bin/env python3
from pathlib import Path
import math
import os
import random
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT.parents[1]/'00_src_hps'
HOST=SRC/'software'

def main():
    subprocess.run(['python3',str(ROOT/'build.py')],check=True)
    cases=[]
    randomizer=random.Random(20261126)
    xs=list(range(-9000,9001,250))+[-9000,-8999,-1,0,1,8999,9000]
    xs += [randomizer.randint(-9000,9000) for _ in range(64)]
    cases += [(x,0,round(math.exp(x/1000)*1000),0) for x in xs]
    angles=[-360000000,360000000,-180000001,-359999999,359999999]
    for angle in [-720,-360,-270,-180,-90,-60,-45,-30,0,30,45,60,90,180,270,360,720]:
        angles += [angle*1000-1,angle*1000,angle*1000+1]
    angles += [randomizer.randint(-360000000,360000000) for _ in range(96)]
    for operation,function in [(1,math.sin),(2,math.cos)]:
        cases += [(x,operation,round(function(math.radians(x/1000))*1000),0) for x in angles]
    cases += [(9001,0,0,4),(-9001,0,0,4),(2147483647,0,0,4),(-2147483648,0,0,4),
              (360000001,1,0,4),(-360000001,2,0,4),(-2147483648,1,0,4)]
    cases=[(*c,0,0) for c in cases]
    pairs=[(a,b) for a in [-2147483648,-2147483647,-1,0,1,2147483647] for b in [-2147483648,-1,0,1,2147483647]]
    pairs += [(randomizer.randint(-2147483648,2147483647),randomizer.randint(-2147483648,2147483647)) for _ in range(100)]
    pairs += [(-17,5),(17,-5),(-17,-5),(12345,6789),(46340,46340),(46341,46341)]
    for op in range(3,7):
        for a,b in pairs:
            error=0; rem=0
            if op==3: value=a+b
            elif op==4: value=a-b
            elif op==5: value=a*b
            elif b==0: value=0;error=1
            else:
                value=(abs(a)//abs(b))*(-1 if (a<0)!=(b<0) else 1)
                rem=a-value*b
            if not -2147483648<=value<=2147483647: error=2
            if error: value=0;rem=0
            cases.append((a,op,value,error,b,rem))
    with tempfile.TemporaryDirectory(prefix='scientific-test-') as tmp:
        work=Path(tmp)
        subprocess.run(['gcc','-std=gnu99','-Wall','-Wextra','-Werror','-fsanitize=undefined',
                        '-I'+str(HOST),str(ROOT/'tests/test_host.c'),str(HOST/'scientific_protocol.c'),
                        '-o',str(work/'test_host')],check=True)
        run=subprocess.run([str(work/'test_host')],capture_output=True,text=True,timeout=10)
        (ROOT/'tests/host.log').write_text(run.stdout+run.stderr)
        print(run.stdout+run.stderr,end='');run.check_returncode()
        (work/'vectors.mem').write_text(''.join(f'{v&0xffffffff:08x}\n' for c in cases for v in c))
        shutil.copyfile(ROOT/'scientific_hps.mem',work/'scientific_hps.mem')
        files=[SRC/'rv32i_pkg.sv']+sorted(p for p in SRC.glob('*.sv') if p.name!='rv32i_pkg.sv' and not p.name.startswith('example_'))
        bundled=Path('/home/lqhau/tools/oss-cad-suite/bin/verilator')
        verilator=os.environ.get('VERILATOR',str(bundled) if bundled.exists() else 'verilator')
        args=[verilator,'--binary','--timing','--assert','--sv','--top-module','tb_scientific',
              '-GCASES='+str(len(cases)),'--Mdir',str(work/'obj'),'--build-jobs','2','-Wno-fatal','+incdir+'+str(SRC)]
        args+=list(map(str,files))+[str(ROOT/'tests/tb_scientific.sv')]
        env=dict(os.environ)
        if shutil.which('g++-10'):env['MAKEFLAGS']='CXX=g++-10'
        run=subprocess.run(args,cwd=work,env=env,text=True,capture_output=True)
        (ROOT/'tests/build.log').write_text(run.stdout+run.stderr);run.check_returncode()
        run=subprocess.run([str(work/'obj/Vtb_scientific')],cwd=work,text=True,capture_output=True,timeout=180)
        (ROOT/'tests/result.log').write_text(run.stdout+run.stderr)
        print(run.stdout+run.stderr,end='');run.check_returncode()

if __name__=='__main__':main()
