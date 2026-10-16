# Milestone 1: Warm-up

RTL for the seven exercises in `milestone-1.pdf`. Layout follows the sample project (`00_src`, `01_bench`, `10_sim`).

| Exercise | Module | File | Architecture |
|---|---|---|---|
| 1 | `adder` | `00_src/adder.sv` | Kogge-Stone prefix adder, carry-in as prefix element 0 |
| 2 | `comparator` | `00_src/comparator.sv` | Leading-difference detector (prefix-OR + one-hot) |
| 3 | `shifter` | `00_src/shifter.sv` | 5-stage log shifter, bit-reversal for left shift |
| 4 | `alu` | `00_src/alu.sv`, `alu_pkg.sv` | One adder, one comparator, one shifter shared |
| 5 | `regfile` | `00_src/regfile.sv` | 32x32, async read, sync write, async reset, x0 = 0 |
| 6 | `dmem_async` | `00_src/dmem_async.sv` | Byte-enable, little-endian, range-checked |
| 7 (extra) | `dmem_sync` | `00_src/dmem_sync.sv` | Same as above with registered read |

## Design decisions to document in the report

- `o_cout` (adder): unsigned add = carry-out; unsigned sub = borrow (`~carry`); signed = overflow.
- Comparator: signed mode flips both MSBs, then compares as unsigned.
- Shifter reserved mode `2'b11` and ALU unused encodings output `0`.
- ALU encoding: `ADD=0 SUB=1 SLT=2 SLTU=3 XOR=4 OR=5 AND=6 SLL=7 SRL=8 SRA=9` (see `alu_pkg.sv`).
- Memories: `i_addr[1:0]` ignored (word access); contents and `dmem_sync.o_rdata` cleared at time 0.
- `dmem_sync` with `i_rden && i_wren`: read-before-write (old data returned).
- Prohibited operators are not used in the datapath. Only elaboration-time loop counters (`i++`, `i != N`) and memory address/range arithmetic (`dmem_*`) use them.

## Run (Linux/WSL, Verilator 5+)

```
cd 10_sim
make run TB=adder      # adder | comparator | shifter | alu | regfile | dmem_async | dmem_sync
make all               # run every testbench
make lint
```

Each testbench is self-checking (reference model, directed + random vectors) and prints `[PASS]` or fails with `$fatal`. Waveforms are written to `wave_<tb>.vcd`.
