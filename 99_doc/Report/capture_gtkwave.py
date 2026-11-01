"""Capture unmodified GTKWave GUI pixels, using the real Verilator VCD.

Run inside WSL: python3 99_doc/Report/capture_gtkwave.py [--case WF14]
Requires GTKWave, Xvfb, xdotool, scrot. No waveform drawing or compositing.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
VCD=ROOT/'02_test/Milestone1/wave.vcd'
SESSIONS=HERE/'gtk_sessions'


def run(args,env):
    return subprocess.check_output([str(x) for x in args],env=env,text=True,stderr=subprocess.STDOUT).strip()


def tcl_file(cid,signals,start,end,index):
    path=SESSIONS/f'{cid}_{index}.tcl'
    ready=path.with_suffix('.ready')
    ready.unlink(missing_ok=True)
    # Select the exact top-level trace names returned by GTKWave itself.
    code=r'''
set requested [list @SIGNALS@]
set selected [list]
foreach short $requested {
    for {set i 0} {$i < [gtkwave::getNumFacs]} {incr i} {
        set full [gtkwave::getFacName $i]
        if {[regexp {^TOP\.tbench\.([^\.\[]+)} $full -> name] && $name eq $short} {
            lappend selected $full
            break
        }
    }
}
if {[llength $selected] != [llength $requested]} {error "Missing GTKWave traces: $selected"}
gtkwave::addSignalsFromList $selected
gtkwave::/Edit/Set_Trace_Max_Hier 1
gtkwave::setLeftJustifySigs 1
gtkwave::highlightSignalsFromList $selected
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/UnHighlight_All
foreach full $selected {
    if {[string match {*mask*} $full]} {
        gtkwave::highlightSignalsFromList [list $full]
        gtkwave::/Edit/Data_Format/Binary
        gtkwave::/Edit/UnHighlight_All
    }
}
gtkwave::setFromEntry {@FROM@ ns}
gtkwave::setToEntry {@TO@ ns}
gtkwave::setZoomRangeTimes @START@ @END@
gtkwave::setMarker @MARKER@
gtkwave::setNamedMarker A @MARKER@ {Sample}
set f [open {@READY@} w]
puts $f "selected=$selected"
puts $f "start=[gtkwave::getWindowStartTime] end=[gtkwave::getWindowEndTime]"
puts $f [info commands gtkwave::*]
close $f
'''
    code=code.replace('@SIGNALS@',' '.join(signals)).replace('@START@',str(round(start*1000))).replace('@END@',str(round(end*1000))).replace('@MARKER@',str(round((start+(end-start)*.3)*1000))).replace('@READY@',ready.as_posix()).replace('@FROM@',str(start)).replace('@TO@',str(end))
    path.write_text(code)
    return path,ready


def main():
    args=argparse.ArgumentParser();args.add_argument('--case');opts=args.parse_args()
    SESSIONS.mkdir(exist_ok=True)
    cases=json.loads((HERE/'capture_cases.json').read_text())
    panels=json.loads((HERE/'gtk_capture_windows.json').read_text())
    env=os.environ.copy(); env['DISPLAY']=':97';env['GDK_BACKEND']='x11'
    xvfb=subprocess.Popen(['Xvfb',':97','-screen','0','1600x820x24','-nolisten','tcp'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    time.sleep(.8)
    if xvfb.poll() is not None: raise RuntimeError('Dedicated X display :97 is unavailable')
    rc=SESSIONS/'capture.rc'
    rc.write_text('initial_window_x 1600\ninitial_window_y 820\ninitial_window_xpos 0\ninitial_window_ypos 0\nfontname_signals Monospace 14\nfontname_waves Monospace 14\nhide_sst 1\nuse_nonprop_fonts 0\n')
    captures=[]
    try:
        for case in cases:
            cid=case[0]
            if opts.case and cid!=opts.case: continue
            for index,(start,end) in enumerate(panels[cid],1):
                tcl,ready=tcl_file(cid,case[3].split(','),start,end,index)
                logpath=tcl.with_suffix('.log')
                with logpath.open('w') as logfile:
                    proc=subprocess.Popen(['gtkwave',str(VCD),'--rcfile',str(rc),'--script',str(tcl)],env=env,stdout=logfile,stderr=subprocess.STDOUT)
                    try:
                        deadline=time.monotonic()+20
                        while not ready.exists() and time.monotonic()<deadline:
                            if proc.poll() is not None: break
                            time.sleep(.1)
                        if not ready.exists(): raise RuntimeError(logpath.read_text())
                        window=run(['xdotool','search','--onlyvisible','--pid',proc.pid],env).splitlines()[0]
                        height=min(760,190+32*len(case[3].split(',')))
                        run(['xdotool','windowsize',window,'1600',str(height)],env)
                        run(['xdotool','windowmove',window,'0','0'],env)
                        run(['xdotool','windowfocus',window],env)
                        time.sleep(.7)
                        name=f'{cid}.png' if index==1 else f'{cid}_p{index}.png'
                        image=HERE/'images'/name
                        run(['scrot','--overwrite','--focused',str(image)],env)
                        captures.append({'id':cid,'panel':index,'image':f'images/{name}','window_ns':[start,end],
                                         'source':'GTKWave GUI screenshot (scrot), no drawing/compositing',
                                         'sha256':hashlib.sha256(image.read_bytes()).hexdigest()})
                        print('CAPTURED',name,ready.read_text().splitlines()[1],flush=True)
                    finally:
                        proc.terminate()
                        try:proc.wait(timeout=3)
                        except subprocess.TimeoutExpired:proc.kill();proc.wait()
        if not opts.case:
            ready=SESSIONS/'terminal.ready';ready.unlink(missing_ok=True)
            helper=SESSIONS/'run_terminal_test.py'
            helper.write_text('import subprocess,time\nfrom pathlib import Path\n'
                +f'print("Command: bash 10_sim/run_milestone1.sh +wave",flush=True)\n'
                +f'r=subprocess.run(["bash",{str(ROOT/"10_sim/run_milestone1.sh")!r},"+wave"],cwd={str(ROOT)!r})\n'
                +f'Path({str(ready)!r}).write_text(str(r.returncode))\n'
                +'print("Simulation exit code:",r.returncode,flush=True)\n'
                +'time.sleep(3600)\n')
            terminal=subprocess.Popen(['xterm','-fa','DejaVu Sans Mono','-fs','14','-geometry','112x18',
                '-title','Milestone1 Verilator simulation results','-e','python3',str(helper)],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            try:
                deadline=time.monotonic()+120
                while not ready.exists() and time.monotonic()<deadline:
                    if terminal.poll() is not None: break
                    time.sleep(.2)
                if not ready.exists() or ready.read_text()!='0': raise RuntimeError('Terminal simulation did not pass')
                window=run(['xdotool','search','--onlyvisible','--pid',terminal.pid],env).splitlines()[0]
                run(['xdotool','windowfocus',window],env);time.sleep(.5)
                image=HERE/'images/LOG01.png'
                run(['scrot','--overwrite','--focused',str(image)],env)
                captures.append({'id':'LOG01','image':'images/LOG01.png','source':'Unmodified xterm screenshot of actual Verilator runner execution',
                    'sha256':hashlib.sha256(image.read_bytes()).hexdigest()})
                print('CAPTURED LOG01.png from actual simulator terminal',flush=True)
            finally:
                terminal.terminate();terminal.wait(timeout=5)
    finally:
        xvfb.terminate();xvfb.wait(timeout=5)
    (HERE/'gtkwave_capture_manifest.json').write_text(json.dumps({'viewer_version':subprocess.check_output(['gtkwave','--version'],stderr=subprocess.STDOUT,text=True).strip(),
        'vcd_sha256':hashlib.sha256(VCD.read_bytes()).hexdigest(),'capture_method':'Unmodified GTKWave X11 window screenshots on dedicated virtual display',
        'captures':captures},indent=2)+'\n')
    print('GTKWave captures complete:',len(captures),flush=True)


if __name__=='__main__':main()
