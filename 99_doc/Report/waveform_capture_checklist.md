# Milestone 1 waveform capture checklist

Capture status: all 33 waveform windows were captured directly from GTKWave; LOG01 is an actual simulator-terminal screenshot. No waveform drawing or image compositing is used. See gtkwave_capture_manifest.json and testcases_waveform.md.

The PDF does not specify a mandatory screenshot count. This checklist proposes 15 waveform figures plus one terminal figure, with multi-panel captures where needed. Exercises 1-6 use WF01-WF12; WF13-WF15 support optional Exercise 7. WF15 also strengthens required async-memory boundary coverage.

Run `bash 10_sim/run_milestone1.sh +wave` from the repository root. Open `02_test/Milestone1/wave.vcd`; all signals below are under `TOP.tbench`. Values are hexadecimal unless stated. Display time in ns. The current VCD has 1ps precision. Capture windows refer to the unchanged deterministic bench; regenerate/update them after stimulus changes.

## [x] WF01 - Adder: basic add/subtract

- PDF pages: 3.
- Window: 148-152; 296-300 ns.
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Stimulus: a=0,b=1 and a=1,b=0; both sub values and both signedness values.
- Expected: 0+1=1; 0-1=FFFFFFFF; 1+0=1; 1-0=1. Output is combinational.
- Save as: `images/WF01.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF02 - Adder: unsigned carry and borrow

- PDF pages: 3.
- Window: 148-152; 444-448 ns.
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Stimulus: unsigned_mode=1; FFFFFFFF+1 and 0-1. Use two panels if necessary.
- Expected: FFFFFFFF+1 -> sum=00000000,cout=1; 0-1 -> sum=FFFFFFFF,cout=0 (borrow).
- Save as: `images/WF02.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF03 - Adder: signed boundary/status convention

- PDF pages: 3.
- Window: 740-744; 888-892 ns.
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Stimulus: unsigned_mode=0; 7FFFFFFF+1 and 80000000-1.
- Expected: Results 80000000 and 7FFFFFFF. cout is respectively 0 and 1 under the documented 33-bit signed-result convention; it is not an overflow flag.
- Save as: `images/WF03.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF04 - Comparator: signedness, equality and one-hot outputs

- PDF pages: 4.
- Window: 0-4; 1184-1188; 1480-1484 ns.
- Signals: `a,b,unsigned_mode,eq,lt,gt`.
- Stimulus: a=7FFFFFFF,b=80000000; toggle unsigned_mode. Also include an equal pair.
- Expected: Signed: gt=1; unsigned: lt=1. Equal operands: eq=1. Exactly one of eq,lt,gt is asserted.
- Save as: `images/WF04.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF05 - Shifter: logical directions and shift boundaries

- PDF pages: 5.
- Window: 1796-1860 ns.
- Signals: `a,shamt,shift_mode,shifted`.
- Stimulus: a=12345678; mode=00 then 01; shamt sweeps 0..31. Show 0,1,31.
- Expected: Amount 0 preserves input. At amount 1: SRL=091A2B3C,SLL=2468ACF0. At amount 31 both outputs are zero for this input.
- Save as: `images/WF05.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF06 - Shifter: arithmetic sign fill and reserved mode

- PDF pages: 5.
- Window: 1944-2072 ns.
- Signals: `a,shamt,shift_mode,shifted`.
- Stimulus: a=FEDCBA98; compare SRL and SRA; include reserved mode=11.
- Expected: At amount 1: SRL=7F6E5D4C,SRA=FF6E5D4C. At amount 31 SRA=FFFFFFFF. Reserved mode always outputs zero.
- Save as: `images/WF06.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF07 - ALU: arithmetic, bitwise and unused encodings

- PDF pages: 6.
- Window: 448-464; 1632-1648 ns.
- Signals: `a,b,alu_op,alu_data`.
- Stimulus: FFFFFFFF,1 and AAAAAAAA,55555555; operation sweep 0..15.
- Expected: All ten documented opcodes match the reference. For the alternating-bit pair XOR=FFFFFFFF,OR=FFFFFFFF,AND=00000000. Opcodes A..F return zero.
- Save as: `images/WF07.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF08 - ALU: SLT/SLTU and low-five-bit shift masking

- PDF pages: 6.
- Window: 1188-1204; 1928-1944; 2076-2092 ns.
- Signals: `a,b,alu_op,alu_data`.
- Stimulus: Compare 7FFFFFFF with 80000000. Shift FEDCBA98 by b=20 hex and 12345678 by b=3F hex.
- Expected: SLT=0,SLTU=1 with bits31:1 zero. b=20 hex means shift 0; b=3F hex means shift 31.
- Save as: `images/WF08.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF09 - Register file: asynchronous reset after nonzero writes

- PDF pages: 7-8.
- Window: 22845-22895; 23245-23290 ns.
- Signals: `clk,rstn,rs1,rs2,rs1_data,rs2_data`.
- Stimulus: Assert rstn low at 23251ns between clock edges, after the register-write sweep.
- Expected: Selected read values clear at reset assertion without waiting for a rising edge; the subsequent address sweep verifies every register is zero.
- Save as: `images/WF09.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF10 - Register file: edge write, two read ports, x0 and write disable

- PDF pages: 7-8.
- Window: 22890-22925; 23210-23250 ns.
- Signals: `clk,rstn,rd_wren,rd,rd_data,rs1,rs2,rs1_data,rs2_data`.
- Stimulus: Write x0 then x1..x31 with CAFE0000|index; later disable writes and change read addresses.
- Expected: x0 remains zero; no write forwarding before the edge; the written value appears after the edge. Both reads follow addresses asynchronously; disabled writes preserve contents.
- Save as: `images/WF10.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF11 - Async memory: masks and little-endian byte lanes

- PDF pages: 8-10.
- Window: 23455-24110 ns.
- Signals: `clk,addr,wdata,mask,wren,async_data`.
- Stimulus: Masks 0..F at offsets 0..3; select focused panels for 1,2,4,8,F. Final valid write: addr=207F,wdata=01020304,mask=F.
- Expected: Only enabled lanes change at the edge; mask=0 preserves data. Word 01020304 has bytes 04,03,02,01 at ascending addresses 207C..207F.
- Save as: `images/WF11.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF12 - Async memory: range checks and unchanged data after invalid writes

- PDF pages: 8-10.
- Window: 24100-24320 ns.
- Signals: `clk,addr,wdata,mask,wren,async_data`.
- Stimulus: Last valid address=207F; invalid addresses=203F,2080,20C0,0,FFFFFFFF; then read back all valid words.
- Expected: Invalid reads return zero; invalid writes do not alias valid words. 207F accesses the last word; all valid readbacks match the model.
- Save as: `images/WF12.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF13 - Sync memory: enabled read and disabled-read hold

- PDF pages: 11-12.
- Window: 23300-23460; 24120-24150; 24320-24420 ns.
- Signals: `clk,addr,rden,wren,sync_data,async_data`.
- Stimulus: Initial writes with rden=0, followed by enabled reads and generated accesses with rden=0.
- Expected: sync_data updates only after a rising edge with rden=1, holds when rden=0, and becomes zero after an enabled out-of-range read.
- Save as: `images/WF13.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF14 - Sync memory: simultaneous read/write policy

- PDF pages: 11-12.
- Window: 23495-23530 ns.
- Signals: `clk,addr,wdata,mask,wren,rden,async_data,sync_data`.
- Stimulus: At addr=2040, old word=1234AB00; wdata=DEADBEEE,mask=1,wren=rden=1 at the 23505ns rising edge.
- Expected: After the edge async_data=1234ABEE, but sync_data=1234AB00. The next enabled read returns the updated word: read-before-write.
- Save as: `images/WF14.png`; then recompile the LaTeX report to replace its matching panel.

## [x] WF15 - Both memories: minimum size and top-of-address-space boundary

- PDF pages: 9-12.
- Window: 29595-29640 ns.
- Signals: `clk,addr,wdata,mask,wren,rden,tiny_async,tiny_sync`.
- Stimulus: Separate one-word instances: START_ADDR=FFFFFFFC,ADDR_WIDTH=2. Write 89ABCDEF through FFFFFFFF; try writing address 0; read FFFFFFFC.
- Expected: The top word stores 89ABCDEF. Address 0 is invalid and cannot wrap into it; enabled invalid reads return zero, then the original word is read back intact.
- Save as: `images/WF15.png`; then recompile the LaTeX report to replace its matching panel.

## [x] LOG01 - Terminal result

Capture the real run command and complete PASS summary including `46369 checks`. Save as `images/LOG01.png`.

Before saving each image: keep signal names and time scale visible, use cursors around sequential edges, ensure values are readable, and verify that the stated expected result is visible. A stored PNG is not automatically inserted by the report generator; the LaTeX report inserts it automatically on recompilation.
