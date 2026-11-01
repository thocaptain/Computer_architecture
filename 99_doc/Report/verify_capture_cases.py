"""Verify real VCD capture testcases without drawing or editing any image."""
from pathlib import Path
import bisect
import csv
import hashlib
import json
import re
import textwrap

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
VCD=ROOT/'02_test/Milestone1/wave.vcd'
LOG=ROOT/'02_test/Milestone1/results.log'
CASES=json.loads((HERE/'capture_cases.json').read_text())

# Focused windows complement the broader navigation windows in the checklist.
PANELS={
 'WF01':[(148,152),(296,300)],
 'WF02':[(148,152),(444,448)],
 'WF03':[(740,744),(888,892)],
 'WF04':[(1184,1188),(1480,1484)],
 'WF05':[(1796,1800),(1828,1832),(1856,1860)],
 'WF06':[(1944,1948),(2008,2012),(2038,2043)],
 'WF07':[(1632,1642),(1642,1648)],
 'WF08':[(1195,1199),(1932,1936),(2080,2084)],
 'WF09':[(22849,22857),(23249,23257)],
 'WF10':[(22890,22910),(23216,23225)],
 'WF11':[(23500,23520),(23540,23560),(24095,24110)],
 'WF12':[(24100,24140),(24140,24170)],
 'WF13':[(24120,24150),(24320,24360)],
 'WF14':[(23500,23520)],
 'WF15':[(29600,29620),(29620,29640)]
}

# Time in ns, signal, expected observed value. These checks are additional to
# the 46,369 checks in the SV suite, not a replacement for that full model.
EXPECT={
 'WF01':[(148.5,'sum',1),(149.5,'sum',0xffffffff),(296.5,'sum',1)],
 'WF02':[(151.5,'sum',0xffffffff),(151.5,'cout',0),(446.5,'sum',0),(446.5,'cout',1)],
 'WF03':[(740.5,'sum',0x80000000),(740.5,'cout',0),(889.5,'sum',0x7fffffff),(889.5,'cout',1)],
 'WF04':[(1184.5,'gt',1),(1184.5,'lt',0),(1186.5,'lt',1),(1186.5,'gt',0),(1480.5,'eq',1)],
 'WF05':[(1796.5,'shifted',0x12345678),(1797.5,'shifted',0x091a2b3c),(1829.5,'shifted',0x2468acf0),(1859.5,'shifted',0)],
 'WF06':[(1945.5,'shifted',0x7f6e5d4c),(2009.5,'shifted',0xff6e5d4c),(2039.5,'shifted',0xffffffff),(2040.5,'shifted',0)],
 'WF07':[(1634.5,'alu_data',0xffffffff),(1635.5,'alu_data',0xffffffff),(1636.5,'alu_data',0),(1642.5,'alu_data',0)],
 'WF08':[(1196.5,'alu_data',0),(1197.5,'alu_data',1),(1933.5,'alu_data',0xfedcba98),(2081.5,'alu_data',0)],
 'WF09':[(23250.5,'rstn',1),(23250.5,'rs1_data',0xcafe001f),(23251.5,'rstn',0),(23251.5,'rs1_data',0)],
 'WF10':[(22896.5,'rs1_data',0),(22901.5,'rs1_data',0),(22906.5,'rs1_data',0xcafe0001),(23223.5,'rs1_data',0xcafe0007)],
 'WF11':[(23504.5,'async_data',0x1234ab00),(23506.5,'async_data',0x1234abee),(24106.5,'async_data',0x01020304)],
 'WF12':[(24106.5,'async_data',0x01020304),(24111.5,'async_data',0),(24121.5,'async_data',0),(24161.5,'async_data',0xdeadbee0)],
 'WF13':[(24131.5,'rden',0),(24131.5,'sync_data',0),(24141.5,'sync_data',0),
         (24334.5,'rden',0),(24334.5,'sync_data',0x01020304),
         (24354.5,'sync_data',0x01020304),(24356.5,'sync_data',0x1234ab09)],
 'WF14':[(23506.5,'async_data',0x1234abee),(23506.5,'sync_data',0x1234ab00),(23516.5,'sync_data',0x1234abee)],
 'WF15':[(29606.5,'tiny_async',0x89abcdef),(29616.5,'tiny_sync',0x89abcdef),(29626.5,'tiny_async',0),(29636.5,'tiny_async',0x89abcdef),(29636.5,'tiny_sync',0x89abcdef)]
}


class Trace:
    def __init__(self):
        self.data={}; self.width={}; ids={}; scope=[]; body=False; tick=0
        for line in VCD.open():
            s=line.strip(); parts=s.split()
            if not body:
                if s.startswith('$scope'): scope.append(parts[2])
                elif s.startswith('$upscope'): scope.pop()
                elif s.startswith('$var') and scope==['TOP','tbench']:
                    code,name=parts[3:5]; ids[code]=name
                    self.width[name]=int(parts[2]); self.data[name]=[]
                elif s=='$enddefinitions $end': body=True
                continue
            if s.startswith('#'): tick=int(s[1:]); continue
            if s.startswith('b'): value,code=parts[0][1:],parts[1]
            elif s and s[0] in '01xz': value,code=s[0],s[1:]
            else: continue
            if code in ids:
                try: val=int(value,2)
                except ValueError: val=None
                name=ids[code]; series=self.data[name]
                if series and series[-1][0]==tick/1000: series[-1]=(tick/1000,val)
                elif not series or series[-1][1]!=val: series.append((tick/1000,val))
        self.times={n:[t for t,_ in s] for n,s in self.data.items()}

    def value(self,name,t):
        i=bisect.bisect_right(self.times[name],t)-1
        return self.data[name][i][1] if i>=0 else None

    def segments(self,name,start,end):
        changes=[(start,self.value(name,start))]
        changes += [(t,v) for t,v in self.data[name] if start<t<end]
        changes.append((end,None))
        return [(t,changes[i+1][0],v) for i,(t,v) in enumerate(changes[:-1])]

    def fmt(self,name,v):
        if v is None: return 'X'
        if name in ['mask']: return f'{v:04b}'
        if self.width[name]==1: return str(v)
        return f'{v:0{(self.width[name]+3)//4}X}'


def main():
    log=LOG.read_text()
    if 'MILESTONE1 PASS: 46369 checks' not in log: raise RuntimeError('Standalone suite must pass before capture.')
    trace=Trace(); results=[]
    for case in CASES:
        cid=case[0]; samples=[]
        for time,name,expected in EXPECT[cid]:
            actual=trace.value(name,time); passed=actual==expected
            samples.append({'time_ns':time,'signal':name,'expected_hex':f'{expected:X}','actual_hex':None if actual is None else f'{actual:X}','pass':passed})
        results.append({'id':cid,'title':case[1],'pass':all(s['pass'] for s in samples),'samples':samples,'image':f'images/{cid}.png'})
    # Fail before producing any misleading PASS-labelled images.
    (HERE/'capture_results.json').write_text(json.dumps({'vcd_sha256':hashlib.sha256(VCD.read_bytes()).hexdigest(),'cases':results},indent=2)+'\n')
    bad=[r for r in results if not r['pass']]
    if bad:
        for r in bad:
            print(r['id'],[s for s in r['samples'] if not s['pass']])
        raise RuntimeError('Capture check failed; inspect real VCD before export.')
    with (HERE/'testcases_waveform.md').open('w',encoding='utf-8') as f:
        f.write('# Waveform capture testcases\n\nThese cases exercise the existing self-checking SV bench. The waveform images are unmodified GTKWave GUI screenshots of the real Verilator VCD; LOG01 is an actual simulator terminal screenshot. All listed time-sample assertions passed before rendering. The full SV suite separately passed 46,369 checks.\n\n')
        for case,result in zip(CASES,results):
            cid,title,_,signals,stimulus,expected,pages=case
            f.write(f'## {cid}: {title}\n\n- Requirement: milestone-1.pdf pp.{pages}.\n- Stimulus: {stimulus}\n- Expected: {expected}\n- Signals: `{signals}`.\n- Capture windows (ns): {PANELS[cid]}.\n- Image: `images/{cid}.png`.\n- Result: **PASS** ({len(result["samples"])} sampled signal checks).\n\n')
            f.write('| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |\n| --- | --- | --- | --- | --- |\n')
            for sample in result['samples']:
                f.write(f'| {sample["time_ns"]} | {sample["signal"]} | {sample["expected_hex"]} | {sample["actual_hex"]} | PASS |\n')
            f.write('\n')
    print(f'PASS: {len(results)} capture testcases; {sum(len(r["samples"]) for r in results)} sampled checks; VCD verification only, no image rendering.')


if __name__=='__main__': main()
