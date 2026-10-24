# all_suit on the TA singlecycle interface

Source RTL: `../../00_src`; fingerprints are recorded in `rtl_sha256.json`.
Simulator: Verilator 5.053; instruction-memory format: 4B.

| Run | Checks | Active cycles | Reset cycles | Total cycles | Instructions | IPC | LEDR | LEDG |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| original_rom | 14/14 | 24263 | 2 | 24265 | 24263 | 1.000000 | 0x00003fff | 0x0000600d |
| ta_c_map | 14/14 | 24263 | 2 | 24265 | 24263 | 1.000000 | 0x00003fff | 0x0000600d |
| ta_isa_map | 14/14 | 24263 | 2 | 24265 | 24263 | 1.000000 | 0x00003fff | 0x0000600d |

All runs start at PC `0x80000000` and instantiate the actual `singlecycle`,
`imem` and `dmem` modules from the F: template.
The original ROM is unchanged and uses legacy addresses 0x2000/0x4000/0x7000;
the simplified memories index low address bits, so this is an aliasing diagnostic.
The C-map and ISA-map runs use valid DMEM addresses from the PDF.
Only four LUI words are changed: data base, stack top, stack-balance check and result address.
All algorithm instructions and all 14 pass/fail conditions match the original ROM.
LEDR/LEDG names refer to the program result words observed by this student testbench;
the TA CPU interface has no physical LED ports. Stores are checked after their clock edge.
Every active clock edge reports one completed instruction. Two reset cycles are excluded from IPC.
The stock mode-0 benchmark previously took 84475 total cycles because its internal memory waits;
the external asynchronous-memory adapter uses a different memory timing model.
This is a student regression, not the official TA testbench.
