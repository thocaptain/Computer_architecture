`include "timescale.svh"
`include "tlib.svh"
`define FINISH      1150000

module tbench;
  initial begin : proc_dump_wave
    $dumpfile("wave.vcd");
    $dumpvars(0, dut);
  end

  initial tsk_timeout(`FINISH);

  logic [3:0] i_addr;
  logic [31:0] o_inst;

  inst_mem #(.ADDR_W(4)) dut (
    .i_addr(i_addr),
    .o_inst(o_inst)
  );

  initial begin
    i_addr = 4'h0;
    #1;
    if (^o_inst === 1'bx) $fatal(1, "instruction memory returned unknown data");
    i_addr = 4'h4;
    #1;
    if (^o_inst === 1'bx) $fatal(1, "instruction memory returned unknown data");
    $display("INSTRUCTION MEMORY TEST PASSED");
  end
endmodule
