# Milestone 1 LaTeX report

- `Milestone1_Report.tex`: concise report; edit student-information macros near the top.
- `Milestone1_Report.pdf`: compiled preview.
- `assets/`: university/department branding extracted from the supplied milestone-1.pdf.
- `images/`: add actual screenshots WF01.png through WF15.png and LOG01.png. Missing images leave reserved panels; existing images are inserted automatically on compilation.
- `waveform_capture_checklist.md` / `.csv`: testcase inputs, expected results, signals and capture windows.
- `capture_cases.json`: structured testcase data for the optional generator.
- `evidence_*.log` / `evidence_manifest.json`: recorded results and source/result hashes.

The report follows the guideline's sans-serif text, blue section titles, gray table headers, blue information panels, ruled running headers/footers and branded cover. Theory is shortened; testcase evidence is retained in 15 waveform groups plus a terminal figure (34 actual screenshots). The old Word report, Markdown report and Word generator have been removed.

Compile from this folder using `xelatex Milestone1_Report.tex` twice, `build_latex.ps1` on Windows, or `bash build_latex.sh` on Linux. For Overleaf upload the .tex file plus assets/ and images/.

From the repository root run `bash 10_sim/run_milestone1.sh +wave` in WSL to regenerate 02_test/Milestone1/wave.vcd. Capture windows assume the unchanged deterministic bench. No RTL or bench modifications were made for the report.

`python 99_doc/Report/generate_latex.py` is optional: it regenerates .tex from concise content and capture_cases.json, overwriting manual LaTeX edits. Normal compilation does not run the generator.

## GTKWave screenshots

All 33 waveform PNGs are unmodified GTKWave 3.3.116 window screenshots, captured by scrot on a dedicated X11 display. LOG01.png is an actual xterm window running the Verilator test script. No waveform plotting, image drawing or compositing is used. The report includes all primary and additional time-window screenshots.

- `capture_gtkwave.py`: GTKWave GUI automation and window capture; run in WSL. Requires GTKWave, Xvfb, xdotool, scrot and xterm.
- `gtk_sessions/`: Tcl configurations and logs that select the exact signals and time windows.
- `gtk_capture_windows.json`: selected windows in ns.
- `gtkwave_capture_manifest.json`: viewer version, window ranges and SHA-256 of each screenshot and source VCD.
- `verify_capture_cases.py`: independent checks of 15 testcases / 62 sampled signal values; it does not create images.
- `testcases_waveform.md` and `capture_results.json`: stimulus, expectations and measured values.

Reproduce from the repository root:

```sh
bash 10_sim/run_milestone1.sh +wave
python3 99_doc/Report/verify_capture_cases.py
python3 99_doc/Report/capture_gtkwave.py
python3 99_doc/Report/generate_latex.py
```

Then compile the report with XeLaTeX twice. To reopen an individual GTKWave view on your desktop, run for example:

```sh
gtkwave 02_test/Milestone1/wave.vcd --rcfile 99_doc/Report/gtk_sessions/capture.rc --script 99_doc/Report/gtk_sessions/WF14_1.tcl
```

The former Python plot renderer has been removed. Do not regenerate screenshots from plotting libraries.

Current report layout: results-only summary tables and 33 GTKWave screenshots. Source-code paths, implementation explanations, procedural text and reference-file lists are omitted from the PDF. The original terminal screenshot remains in images/ as supporting evidence.
