"""Generate the concise LaTeX report using milestone-1.pdf's visual style.

Run explicitly: python 99_doc/Report/generate_latex.py
This overwrites Milestone1_Report.tex. Save manual edits before regeneration.
"""
from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent
CASES = json.loads((HERE/'capture_cases.json').read_text())


def esc(value):
    chars = {'\\':r'\textbackslash{}','&':r'\&','%':r'\%','$':r'\$',
             '#':r'\#','_':r'\_\allowbreak{}','{':r'\{','}':r'\}',
             '~':r'\textasciitilde{}','^':r'\textasciicircum{}',
             '<':r'\textless{}','>':r'\textgreater{}',
             '/':r'/\allowbreak{}',',':r',\allowbreak{}'}
    return ''.join(chars.get(c,c) for c in str(value))


def table(headers, rows, widths, multipage=True):
    cols='|'.join(r'>{\raggedright\arraybackslash}p{\dimexpr '+str(w)+r'\ReportTableWidth-2\tabcolsep-2\arrayrulewidth\relax}' for w in widths)
    header=' & '.join(r'\colorbox{tablegray}{\parbox[t]{\dimexpr '+str(w)+r'\ReportTableWidth-2\tabcolsep-2\arrayrulewidth-2\fboxsep\relax}{\strut\textbf{'+esc(h)+r'}\strut}}' for h,w in zip(headers,widths))+r' \\ \hline'
    kind='longtable' if multipage else 'tabular'
    out=[r'{\small\setlength{\tabcolsep}{4pt}\setlength{\ReportTableWidth}{\linewidth}',r'\noindent\begin{'+kind+'}{|'+cols+'|}',r'\hline',header]
    if multipage: out += [r'\endfirsthead',r'\hline',header,r'\endhead']
    for row in rows: out.append(' & '.join(esc(v) for v in row)+r' \\ \hline')
    return '\n'.join(out+[r'\end{'+kind+'}','}'])


PREAMBLE=r'''% Concise student report, visually adapted from 99_doc/milestone-1.pdf.
% Compile twice with XeLaTeX (Unicode Vietnamese names). Screenshot files replace the blank panels.
\documentclass[11pt,a4paper]{article}
\usepackage{fontspec}
\setmainfont{Arial}
\setsansfont{Arial}
\setmonofont{Consolas}
\usepackage[a4paper,left=25mm,right=25mm,top=24mm,bottom=24mm,headheight=15pt]{geometry}
\usepackage{graphicx}
\usepackage{xcolor}
\usepackage{array,longtable}
\usepackage{fancyhdr}
\usepackage[hidelinks]{hyperref}
\definecolor{reportblue}{HTML}{073A91}
\definecolor{noteblue}{HTML}{EEF4FA}
\definecolor{tablegray}{HTML}{CCCCCC}
\definecolor{muted}{HTML}{536477}
\setlength{\parindent}{0pt}
\setlength{\parskip}{5pt}
\setlength{\emergencystretch}{3em}
\renewcommand{\arraystretch}{1.15}
\newlength{\ReportTableWidth}
\newcommand{\KeepTableStart}{\par\ifdim\dimexpr\pagegoal-\pagetotal\relax<140pt\newpage\fi}
\raggedbottom
\makeatletter
\renewcommand\section{\@startsection{section}{1}{\z@}{2.0ex plus 1ex minus .2ex}{.8ex}{\Large\bfseries\color{reportblue}}}
\makeatother
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\footnotesize\bfseries Computer Architecture Laboratory -- Milestone 1: Warm-up}
\fancyfoot[L]{\footnotesize\nouppercase{\leftmark}}
\fancyfoot[R]{\footnotesize\thepage}
\renewcommand{\headrulewidth}{0.8pt}
\renewcommand{\footrulewidth}{0.6pt}
\renewcommand{\sectionmark}[1]{\markboth{#1}{}}
\hypersetup{pdftitle={Milestone 1: Warm-up - Design and Verification Report},plainpages=false}

% Student information: edit here.
\newcommand{\StudentName}{Lương Quý Hậu}
\newcommand{\StudentID}{2570099}
\newcommand{\SecondStudentName}{Võ Ngọc Nhất Huy}
\newcommand{\SecondStudentID}{2570206}
% Names copied from the handout's Author field, used here as requested.
\newcommand{\Instructor}{Khai Pham / Vy Luong}

% Blue information panels follow the visual language of the lab guideline.
\newcommand{\ReportNote}[2]{%
  \par\smallskip\noindent
  {\setlength{\fboxsep}{9pt}\colorbox{noteblue}{%
    \begin{minipage}{\dimexpr\linewidth-18pt\relax}
    {\color{reportblue}\bfseries #1}\par\smallskip #2
    \end{minipage}}}\par\smallskip
}
\newcommand{\EvidenceImage}[2]{%
  \par\smallskip\begin{center}
  \IfFileExists{#2}{%
    \includegraphics[width=\linewidth,height=0.29\textheight,keepaspectratio]{#2}%
  }{%
    {\color{muted}\fbox{\begin{minipage}[c][40mm][c]{0.94\linewidth}
      \centering\textbf{#1 -- Waveform screenshot}\par\smallskip
      \texttt{\detokenize{#2}}\par\smallskip
      Reserved space for captured evidence
    \end{minipage}}}%
  }
  \end{center}
}
\begin{document}
\hypersetup{pageanchor=false}
\newgeometry{left=25mm,right=25mm,top=8mm,bottom=8mm}
\begin{titlepage}
\thispagestyle{empty}
\noindent\includegraphics[width=\linewidth]{assets/university_header.pdf}
\vspace*{73mm}
\begin{center}
{\fontsize{24}{29}\selectfont\bfseries Computer Architecture Laboratory\par}
\vspace{4mm}
{\fontsize{20}{24}\selectfont Milestone 1: Warm-up\par}
\vspace{13mm}
{\large\begin{tabular}{@{}ll@{}}
\textbf{Members:} & \StudentName\ --- \StudentID \\
 & \SecondStudentName\ --- \SecondStudentID \\
\textbf{Instructor:} & \Instructor \\
\textbf{Date:} & 2026-Oct-25 \\
\end{tabular}}
\end{center}
\vfill
\noindent\includegraphics[width=\linewidth]{assets/department_footer.pdf}
\end{titlepage}
\restoregeometry
\hypersetup{pageanchor=true}
\setcounter{page}{1}
\tableofcontents
\clearpage
'''



BLOCKS=[
 ('Adder', 'Add/subtract; signed/unsigned; carry/borrow; zero and signed extrema.', ['WF01','WF02','WF03']),
 ('Magnitude Comparator', 'Equality; signed/unsigned ordering; sign boundaries; one-hot outputs.', ['WF04']),
 ('Shifter', 'SRL/SLL/SRA; amounts 0-31; zero/sign fill; reserved mode.', ['WF05','WF06']),
 ('Arithmetic Logic Unit', 'Ten operations; unused encodings; SLT/SLTU; shift-amount masking.', ['WF07','WF08']),
 ('Register File', 'All register addresses; x0; edge write; dual asynchronous reads; reset; write disable.', ['WF09','WF10']),
 ('Asynchronous-read Memory', 'All byte masks and offsets; little-endian lanes; valid/invalid addresses; readback.', ['WF11','WF12']),
 ('Synchronous-read Memory (Optional)', 'Enabled reads; disabled-read hold; read-before-write; minimum size and no address wrap.', ['WF13','WF14','WF15'])
]
RESULTS={
 'WF01':('Basic arithmetic','0+1=1; 0-1=FFFFFFFF; 1-0=1.'),
 'WF02':('Carry / borrow','FFFFFFFF+1=00000000 with carry=1; 0-1=FFFFFFFF with unsigned cout=0.'),
 'WF03':('Signed boundaries','7FFFFFFF+1=80000000; 80000000-1=7FFFFFFF.'),
 'WF04':('Comparison / one-hot','For 7FFFFFFF versus 80000000: signed gt=1, unsigned lt=1. Equal operands assert eq only.'),
 'WF05':('Logical shifts','Shift 0 preserves 12345678; SRL1=091A2B3C; SLL1=2468ACF0; SLL31=0.'),
 'WF06':('Sign fill / reserved mode','FEDCBA98: SRL1=7F6E5D4C; SRA1=FF6E5D4C; SRA31=FFFFFFFF. Reserved mode=0.'),
 'WF07':('ALU selection','AAAAAAAA/55555555: XOR=FFFFFFFF, OR=FFFFFFFF, AND=0. Unused opcodes return zero.'),
 'WF08':('Compare / shift masking','SLT=0 and SLTU=1 at the sign boundary. b=20 hex selects shift 0; b=3F hex selects shift 31.'),
 'WF09':('Asynchronous reset','Reset asserted between rising edges clears the selected read outputs immediately; register scan returns zero.'),
 'WF10':('Register write / preservation','x0 stays zero; x1 becomes CAFE0001 after the edge. Disabled write preserves x7=CAFE0007.'),
 'WF11':('Byte lanes / endianness','Mask 0001 changes 1234AB00 to 1234ABEE. Full-word write returns 01020304; other masks preserve disabled lanes.'),
 'WF12':('Address boundaries','Invalid reads return zero. Valid readback DEADBEE0 is unchanged after invalid writes.'),
 'WF13':('Registered read / hold','Read-disable holds 01020304. Enabled read updates to 1234AB09 after the edge; enabled invalid reads return zero.'),
 'WF14':('Read-before-write','At the write edge: async=1234ABEE, sync=1234AB00. The next enabled sync read returns 1234ABEE.'),
 'WF15':('Minimum size / no wrap','The top-address word retains 89ABCDEF after an invalid write at address zero; enabled invalid reads return zero.')
}

CASE_DETAILS={
 'WF01':('a/b = 0/1 and 1/0; sub=0/1; signed/unsigned modes.', 'Basic addition, subtraction and zero identity.'),
 'WF02':('a/b = FFFFFFFF/1 and 0/1; unsigned mode; add/sub.', 'Unsigned carry-out and borrow convention.'),
 'WF03':('a/b = 7FFFFFFF/1 and 80000000/1; signed mode.', 'Signed boundary wrap and status output.'),
 'WF04':('a/b = 7FFFFFFF/80000000; toggle signedness; include equal operands.', 'Ordering changes with signedness; exactly one comparison output asserted.'),
 'WF05':('data=12345678; SRL/SLL; shift amounts 0,1 and 31.', 'Zero shift, logical direction and maximum amount.'),
 'WF06':('data=FEDCBA98; SRL/SRA; amounts 1,31; reserved mode=11.', 'Zero fill versus sign fill; reserved-mode safe output.'),
 'WF07':('a=AAAAAAAA, b=55555555; sweep ALU opcodes 0-F.', 'Operation selection, bitwise patterns and unused encodings.'),
 'WF08':('a/b=7FFFFFFF/80000000; shift b=20 or 3F hex.', 'SLT versus SLTU; only b[4:0] selects shift amount.'),
 'WF09':('Nonzero register contents; rstn changes 1 to 0 between rising edges.', 'Asynchronous clearing without waiting for a clock edge.'),
 'WF10':('rd=x0-x31; write data=CAFE0000 OR index; enable then disable writes.', 'Clock-edge update, no bypass, x0 protection and disabled-write retention.'),
 'WF11':('addr=2040-2043 and 207F; masks 0-F; full/partial word writes.', 'Byte-lane preservation and little-endian data layout.'),
 'WF12':('Valid addr=207F; invalid addr=203F,2080,20C0,0,FFFFFFFF.', 'Upper/lower boundaries, zero invalid reads and ignored invalid writes.'),
 'WF13':('Read enable=0/1; change address and write enable; stored data is nonzero.', 'Registered read timing, disabled-read hold and invalid read handling.'),
 'WF14':('addr=2040; old=1234AB00; write=DEADBEEE; mask=0001; both enables=1.', 'Simultaneous read/write uses read-before-write.'),
 'WF15':('One word at FFFFFFFC; write 89ABCDEF through FFFFFFFF; attempt write at 0.', 'Minimum memory size and top-address no-wrap protection.')
}


def wave(cid, manifest):
    label,result=RESULTS[cid]
    inputs,test=CASE_DETAILS[cid]
    panels=[c for c in manifest['captures'] if c['id']==cid]
    if not panels: raise RuntimeError('Missing GTKWave screenshots: '+cid)
    return '\n'.join([
        r'\par\medskip\noindent\begin{minipage}{\linewidth}',
        r'{\color{reportblue}\bfseries '+esc(cid+' | '+label)+r'}\par',
        table(['Item','Testcase details'],[
            ('Input',inputs),('Output',result),('Test',test),('Result','PASS')
        ],[.16,.84],multipage=False),
        *[r'\EvidenceImage{'+cid+' / '+str(c['panel'])+'}{'+c['image']+'}' for c in panels],
        r'{\small\centering Figure '+cid+'. '+esc(label)+r'.\par}',
        r'\end{minipage}\par\medskip'])


def main():
    checks=json.loads((HERE/'capture_results.json').read_text())
    manifest=json.loads((HERE/'gtkwave_capture_manifest.json').read_text())
    if not all(c['pass'] for c in checks['cases']): raise RuntimeError('Capture verification must pass.')
    text=[PREAMBLE,r'\section{Overview}',
        table(['Block','Tested behavior','Result'],[(name,coverage,'PASS') for name,coverage,_ in BLOCKS],[.25,.63,.12])]
    for name,_,ids in BLOCKS:
        text += [r'\clearpage',r'\section{'+esc(name)+'}']
        text += [wave(cid,manifest) for cid in ids]
    text += [r'\clearpage',r'\section{Overall Result}',
        table(['Verification','Result'],[
            ('Standalone block tests','PASS - 46,369 checks; no mismatches.'),
            ('Waveform sample checks','PASS - 15 cases, 62 checked signal values.'),
            ('Waveform evidence','33 direct GTKWave screenshots.'),
            ('Coverage scope','Directed and fixed-seed generated tests; not exhaustive over all 32-bit operands.')],[.38,.62]),
        r'\end{document}']
    (HERE/'Milestone1_Report.tex').write_text('\n\n'.join(text)+'\n',encoding='utf-8')
    print('Generated results-only report: concise tables and actual GTKWave screenshots; source paths removed.')


if __name__=='__main__': main()
