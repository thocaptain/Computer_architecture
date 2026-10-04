`include "timescale.svh"
`include "tlib.svh"
`define RESETPERIOD 55
`define FINISH      1150000

module tbench
  import rv32i_pkg::*;
();
  initial begin : proc_dump_wave
    $dumpfile("wave.vcd");
    $dumpvars(0, dut);
  end

  logic i_clk;
  logic i_rst_n;
  logic [17:0] i_ADDR;
  logic [31:0] i_WDATA;
  logic [3:0] i_BMASK;
  logic i_WREN;
  logic [31:0] o_RDATA;
  logic i_VALID;
  logic o_READY;

/* verilator lint_off UNUSEDSIGNAL */
  logic [17:0] SRAM_ADDR;
  wire  [15:0] SRAM_DQ;
  logic        SRAM_CE_N;
  logic        SRAM_WE_N;
  logic        SRAM_LB_N;
  logic        SRAM_UB_N;
  logic        SRAM_OE_N;
/* verilator lint_on UNUSEDSIGNAL */

  initial begin i_clk = 1'b0; forever #5 i_clk = ~i_clk; end
  initial tsk_timeout(`FINISH);

  data_mem #(.MEM_TYPE(MEM_FLOP), .ADDR_W(6)) dut (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_ADDR(i_ADDR), .i_WDATA(i_WDATA),
    .i_BMASK(i_BMASK), .i_WREN(i_WREN), .o_RDATA(o_RDATA),
    .i_VALID(i_VALID), .o_READY(o_READY),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ),
    .SRAM_CE_N(SRAM_CE_N), .SRAM_WE_N(SRAM_WE_N),
    .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N),
    .SRAM_OE_N(SRAM_OE_N)
  );

  task automatic wait_ready;
    int cycles;
    begin
      cycles = 0;
      while (!o_READY && cycles < 30) begin @(posedge i_clk); cycles++; end
      if (!o_READY) $fatal(1, "data memory request timed out");
      @(negedge i_clk);
      i_VALID = 1'b0;
    end
  endtask

  initial begin
    i_rst_n = 1'b0;
    i_ADDR = 18'h0004;
    i_WDATA = '0;
    i_BMASK = '0;
    i_WREN = 1'b0;
    i_VALID = 1'b0;
    tsk_reset(i_rst_n, `RESETPERIOD);

    i_WDATA = 32'haabb_ccdd;
    i_BMASK = 4'b1111;
    i_WREN = 1'b1;
    i_VALID = 1'b1;
    wait_ready();

    i_WREN = 1'b0;
    i_BMASK = '0;
    i_VALID = 1'b1;
    wait_ready();
    #1;
    if (o_RDATA !== 32'haabb_ccdd) $fatal(1, "data memory full-word read failed");
    $display("DATA MEMORY TEST PASSED");
  end
endmodule
