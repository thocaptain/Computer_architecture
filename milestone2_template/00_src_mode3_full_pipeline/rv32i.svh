`ifndef RV32I_SVH
`define RV32I_SVH

//`define INST_MEM_PATH "./../02_test/dump/all_inst_and_lsu.mem"
//`define INST_MEM_PATH "./../02_test/dump/cache_benchmark.mem"
// `define INST_MEM_PATH "./../02_test/dump/branch_pred_benchmark.mem"
// `define INST_MEM_PATH "./../02_test/dump/cache.mem"
// `define INST_MEM_PATH "./../02_test/dump/stopwatch.mem"
// `define INST_MEM_PATH "./../02_test/dump/all_alu.mem"
// `define INST_MEM_PATH "./../02_test/dump/datmem.mem"
// `define INST_MEM_PATH "./../02_test/dump/distance.mem"
// `define INST_MEM_PATH "./../02_test/dump/distance_test.mem"
// `define INST_MEM_PATH "./../02_test/dump/mem.dump"
//`define INST_MEM_PATH "./../02_test/dump/sw_led.mem"
`ifdef ALTERA_BUILD
`define INST_MEM_PATH "./../../../02_test/dump/all_suit.mem"
`else
`define INST_MEM_PATH "./../02_test/dump/all_suit.mem"
`endif
//`define INST_MEM_PATH "./../bench_CPU/memory/instmem.data.sim"


`define PRIM_FF_RST(OUT, IN, RST_N, CLOCK, RST_VAL) \
    always_ff @( posedge CLOCK ) begin : \ff_``OUT   \
       OUT <= (~RST_N) ? RST_VAL : IN;                  \
    end : \ff_``OUT

`define PRIM_FF_EN_RST(OUT, IN, EN, RST_N, CLOCK, RST_VAL) \
    always_ff @( posedge CLOCK ) begin : \ff_``OUT   \
       OUT <= (~RST_N) ? RST_VAL : (EN)? IN : OUT;   \
    end : \ff_``OUT

`endif
