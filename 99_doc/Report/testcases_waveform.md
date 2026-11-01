# Waveform capture testcases

These cases exercise the existing self-checking SV bench. The waveform images are unmodified GTKWave GUI screenshots of the real Verilator VCD; LOG01 is an actual simulator terminal screenshot. All listed time-sample assertions passed before rendering. The full SV suite separately passed 46,369 checks.

## WF01: Adder: basic add/subtract

- Requirement: milestone-1.pdf pp.3.
- Stimulus: a=0,b=1 and a=1,b=0; both sub values and both signedness values.
- Expected: 0+1=1; 0-1=FFFFFFFF; 1+0=1; 1-0=1. Output is combinational.
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Capture windows (ns): [(148, 152), (296, 300)].
- Image: `images/WF01.png`.
- Result: **PASS** (3 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 148.5 | sum | 1 | 1 | PASS |
| 149.5 | sum | FFFFFFFF | FFFFFFFF | PASS |
| 296.5 | sum | 1 | 1 | PASS |

## WF02: Adder: unsigned carry and borrow

- Requirement: milestone-1.pdf pp.3.
- Stimulus: unsigned_mode=1; FFFFFFFF+1 and 0-1. Use two panels if necessary.
- Expected: FFFFFFFF+1 -> sum=00000000,cout=1; 0-1 -> sum=FFFFFFFF,cout=0 (borrow).
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Capture windows (ns): [(148, 152), (444, 448)].
- Image: `images/WF02.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 151.5 | sum | FFFFFFFF | FFFFFFFF | PASS |
| 151.5 | cout | 0 | 0 | PASS |
| 446.5 | sum | 0 | 0 | PASS |
| 446.5 | cout | 1 | 1 | PASS |

## WF03: Adder: signed boundary/status convention

- Requirement: milestone-1.pdf pp.3.
- Stimulus: unsigned_mode=0; 7FFFFFFF+1 and 80000000-1.
- Expected: Results 80000000 and 7FFFFFFF. cout is respectively 0 and 1 under the documented 33-bit signed-result convention; it is not an overflow flag.
- Signals: `a,b,sub,unsigned_mode,sum,cout`.
- Capture windows (ns): [(740, 744), (888, 892)].
- Image: `images/WF03.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 740.5 | sum | 80000000 | 80000000 | PASS |
| 740.5 | cout | 0 | 0 | PASS |
| 889.5 | sum | 7FFFFFFF | 7FFFFFFF | PASS |
| 889.5 | cout | 1 | 1 | PASS |

## WF04: Comparator: signedness, equality and one-hot outputs

- Requirement: milestone-1.pdf pp.4.
- Stimulus: a=7FFFFFFF,b=80000000; toggle unsigned_mode. Also include an equal pair.
- Expected: Signed: gt=1; unsigned: lt=1. Equal operands: eq=1. Exactly one of eq,lt,gt is asserted.
- Signals: `a,b,unsigned_mode,eq,lt,gt`.
- Capture windows (ns): [(1184, 1188), (1480, 1484)].
- Image: `images/WF04.png`.
- Result: **PASS** (5 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 1184.5 | gt | 1 | 1 | PASS |
| 1184.5 | lt | 0 | 0 | PASS |
| 1186.5 | lt | 1 | 1 | PASS |
| 1186.5 | gt | 0 | 0 | PASS |
| 1480.5 | eq | 1 | 1 | PASS |

## WF05: Shifter: logical directions and shift boundaries

- Requirement: milestone-1.pdf pp.5.
- Stimulus: a=12345678; mode=00 then 01; shamt sweeps 0..31. Show 0,1,31.
- Expected: Amount 0 preserves input. At amount 1: SRL=091A2B3C,SLL=2468ACF0. At amount 31 both outputs are zero for this input.
- Signals: `a,shamt,shift_mode,shifted`.
- Capture windows (ns): [(1796, 1800), (1828, 1832), (1856, 1860)].
- Image: `images/WF05.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 1796.5 | shifted | 12345678 | 12345678 | PASS |
| 1797.5 | shifted | 91A2B3C | 91A2B3C | PASS |
| 1829.5 | shifted | 2468ACF0 | 2468ACF0 | PASS |
| 1859.5 | shifted | 0 | 0 | PASS |

## WF06: Shifter: arithmetic sign fill and reserved mode

- Requirement: milestone-1.pdf pp.5.
- Stimulus: a=FEDCBA98; compare SRL and SRA; include reserved mode=11.
- Expected: At amount 1: SRL=7F6E5D4C,SRA=FF6E5D4C. At amount 31 SRA=FFFFFFFF. Reserved mode always outputs zero.
- Signals: `a,shamt,shift_mode,shifted`.
- Capture windows (ns): [(1944, 1948), (2008, 2012), (2038, 2043)].
- Image: `images/WF06.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 1945.5 | shifted | 7F6E5D4C | 7F6E5D4C | PASS |
| 2009.5 | shifted | FF6E5D4C | FF6E5D4C | PASS |
| 2039.5 | shifted | FFFFFFFF | FFFFFFFF | PASS |
| 2040.5 | shifted | 0 | 0 | PASS |

## WF07: ALU: arithmetic, bitwise and unused encodings

- Requirement: milestone-1.pdf pp.6.
- Stimulus: FFFFFFFF,1 and AAAAAAAA,55555555; operation sweep 0..15.
- Expected: All ten documented opcodes match the reference. For the alternating-bit pair XOR=FFFFFFFF,OR=FFFFFFFF,AND=00000000. Opcodes A..F return zero.
- Signals: `a,b,alu_op,alu_data`.
- Capture windows (ns): [(1632, 1642), (1642, 1648)].
- Image: `images/WF07.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 1634.5 | alu_data | FFFFFFFF | FFFFFFFF | PASS |
| 1635.5 | alu_data | FFFFFFFF | FFFFFFFF | PASS |
| 1636.5 | alu_data | 0 | 0 | PASS |
| 1642.5 | alu_data | 0 | 0 | PASS |

## WF08: ALU: SLT/SLTU and low-five-bit shift masking

- Requirement: milestone-1.pdf pp.6.
- Stimulus: Compare 7FFFFFFF with 80000000. Shift FEDCBA98 by b=20 hex and 12345678 by b=3F hex.
- Expected: SLT=0,SLTU=1 with bits31:1 zero. b=20 hex means shift 0; b=3F hex means shift 31.
- Signals: `a,b,alu_op,alu_data`.
- Capture windows (ns): [(1195, 1199), (1932, 1936), (2080, 2084)].
- Image: `images/WF08.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 1196.5 | alu_data | 0 | 0 | PASS |
| 1197.5 | alu_data | 1 | 1 | PASS |
| 1933.5 | alu_data | FEDCBA98 | FEDCBA98 | PASS |
| 2081.5 | alu_data | 0 | 0 | PASS |

## WF09: Register file: asynchronous reset after nonzero writes

- Requirement: milestone-1.pdf pp.7-8.
- Stimulus: Assert rstn low at 23251ns between clock edges, after the register-write sweep.
- Expected: Selected read values clear at reset assertion without waiting for a rising edge; the subsequent address sweep verifies every register is zero.
- Signals: `clk,rstn,rs1,rs2,rs1_data,rs2_data`.
- Capture windows (ns): [(22849, 22857), (23249, 23257)].
- Image: `images/WF09.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 23250.5 | rstn | 1 | 1 | PASS |
| 23250.5 | rs1_data | CAFE001F | CAFE001F | PASS |
| 23251.5 | rstn | 0 | 0 | PASS |
| 23251.5 | rs1_data | 0 | 0 | PASS |

## WF10: Register file: edge write, two read ports, x0 and write disable

- Requirement: milestone-1.pdf pp.7-8.
- Stimulus: Write x0 then x1..x31 with CAFE0000|index; later disable writes and change read addresses.
- Expected: x0 remains zero; no write forwarding before the edge; the written value appears after the edge. Both reads follow addresses asynchronously; disabled writes preserve contents.
- Signals: `clk,rstn,rd_wren,rd,rd_data,rs1,rs2,rs1_data,rs2_data`.
- Capture windows (ns): [(22890, 22910), (23216, 23225)].
- Image: `images/WF10.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 22896.5 | rs1_data | 0 | 0 | PASS |
| 22901.5 | rs1_data | 0 | 0 | PASS |
| 22906.5 | rs1_data | CAFE0001 | CAFE0001 | PASS |
| 23223.5 | rs1_data | CAFE0007 | CAFE0007 | PASS |

## WF11: Async memory: masks and little-endian byte lanes

- Requirement: milestone-1.pdf pp.8-10.
- Stimulus: Masks 0..F at offsets 0..3; select focused panels for 1,2,4,8,F. Final valid write: addr=207F,wdata=01020304,mask=F.
- Expected: Only enabled lanes change at the edge; mask=0 preserves data. Word 01020304 has bytes 04,03,02,01 at ascending addresses 207C..207F.
- Signals: `clk,addr,wdata,mask,wren,async_data`.
- Capture windows (ns): [(23500, 23520), (23540, 23560), (24095, 24110)].
- Image: `images/WF11.png`.
- Result: **PASS** (3 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 23504.5 | async_data | 1234AB00 | 1234AB00 | PASS |
| 23506.5 | async_data | 1234ABEE | 1234ABEE | PASS |
| 24106.5 | async_data | 1020304 | 1020304 | PASS |

## WF12: Async memory: range checks and unchanged data after invalid writes

- Requirement: milestone-1.pdf pp.8-10.
- Stimulus: Last valid address=207F; invalid addresses=203F,2080,20C0,0,FFFFFFFF; then read back all valid words.
- Expected: Invalid reads return zero; invalid writes do not alias valid words. 207F accesses the last word; all valid readbacks match the model.
- Signals: `clk,addr,wdata,mask,wren,async_data`.
- Capture windows (ns): [(24100, 24140), (24140, 24170)].
- Image: `images/WF12.png`.
- Result: **PASS** (4 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 24106.5 | async_data | 1020304 | 1020304 | PASS |
| 24111.5 | async_data | 0 | 0 | PASS |
| 24121.5 | async_data | 0 | 0 | PASS |
| 24161.5 | async_data | DEADBEE0 | DEADBEE0 | PASS |

## WF13: Sync memory: enabled read and disabled-read hold

- Requirement: milestone-1.pdf pp.11-12.
- Stimulus: Initial writes with rden=0, followed by enabled reads and generated accesses with rden=0.
- Expected: sync_data updates only after a rising edge with rden=1, holds when rden=0, and becomes zero after an enabled out-of-range read.
- Signals: `clk,addr,rden,wren,sync_data,async_data`.
- Capture windows (ns): [(24120, 24150), (24320, 24360)].
- Image: `images/WF13.png`.
- Result: **PASS** (7 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 24131.5 | rden | 0 | 0 | PASS |
| 24131.5 | sync_data | 0 | 0 | PASS |
| 24141.5 | sync_data | 0 | 0 | PASS |
| 24334.5 | rden | 0 | 0 | PASS |
| 24334.5 | sync_data | 1020304 | 1020304 | PASS |
| 24354.5 | sync_data | 1020304 | 1020304 | PASS |
| 24356.5 | sync_data | 1234AB09 | 1234AB09 | PASS |

## WF14: Sync memory: simultaneous read/write policy

- Requirement: milestone-1.pdf pp.11-12.
- Stimulus: At addr=2040, old word=1234AB00; wdata=DEADBEEE,mask=1,wren=rden=1 at the 23505ns rising edge.
- Expected: After the edge async_data=1234ABEE, but sync_data=1234AB00. The next enabled read returns the updated word: read-before-write.
- Signals: `clk,addr,wdata,mask,wren,rden,async_data,sync_data`.
- Capture windows (ns): [(23500, 23520)].
- Image: `images/WF14.png`.
- Result: **PASS** (3 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 23506.5 | async_data | 1234ABEE | 1234ABEE | PASS |
| 23506.5 | sync_data | 1234AB00 | 1234AB00 | PASS |
| 23516.5 | sync_data | 1234ABEE | 1234ABEE | PASS |

## WF15: Both memories: minimum size and top-of-address-space boundary

- Requirement: milestone-1.pdf pp.9-12.
- Stimulus: Separate one-word instances: START_ADDR=FFFFFFFC,ADDR_WIDTH=2. Write 89ABCDEF through FFFFFFFF; try writing address 0; read FFFFFFFC.
- Expected: The top word stores 89ABCDEF. Address 0 is invalid and cannot wrap into it; enabled invalid reads return zero, then the original word is read back intact.
- Signals: `clk,addr,wdata,mask,wren,rden,tiny_async,tiny_sync`.
- Capture windows (ns): [(29600, 29620), (29620, 29640)].
- Image: `images/WF15.png`.
- Result: **PASS** (5 sampled signal checks).

| Time (ns) | Signal | Expected (hex) | Actual (hex) | Result |
| --- | --- | --- | --- | --- |
| 29606.5 | tiny_async | 89ABCDEF | 89ABCDEF | PASS |
| 29616.5 | tiny_sync | 89ABCDEF | 89ABCDEF | PASS |
| 29626.5 | tiny_async | 0 | 0 | PASS |
| 29636.5 | tiny_async | 89ABCDEF | 89ABCDEF | PASS |
| 29636.5 | tiny_sync | 89ABCDEF | 89ABCDEF | PASS |

