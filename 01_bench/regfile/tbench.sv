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
  logic [4:0] i_rs1_addr;
  logic [4:0] i_rs2_addr;
  logic [4:0] i_rd_addr;
  logic i_rd_wen;
  logic [31:0] i_rd_data;
  logic [31:0] o_rs1_data;
  logic [31:0] o_rs2_data;
  logic [31:0][31:0] drv_regs;

  initial tsk_clock_gen(i_clk);
  initial tsk_reset(i_rst_n, `RESETPERIOD);
  initial tsk_timeout(`FINISH);

  regfile dut (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .i_rs1_addr(i_rs1_addr),
    .i_rs2_addr(i_rs2_addr),
    .i_rd_addr(i_rd_addr),
    .i_rd_wen(i_rd_wen),
    .i_rd_data(i_rd_data),
    .o_rs1_data(o_rs1_data),
    .o_rs2_data(o_rs2_data)
  );

  generate
    for (genvar i = 0; i < 32; i++) begin : gen_reg_dump
      assign drv_regs[i] = dut.regs[i];
    end
  endgenerate

  scoreboard_regfile scoreboard (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .drv_regs(drv_regs)
  );

  initial begin
    i_rs1_addr = '0;
    i_rs2_addr = '0;
    i_rd_addr = '0;
    i_rd_wen = 1'b0;
    i_rd_data = '0;
    wait (i_rst_n);
    @(negedge i_clk);
    i_rd_addr = 5'd5;
    i_rd_data = 32'h1234_5678;
    i_rd_wen = 1'b1;
    @(negedge i_clk);
    i_rd_wen = 1'b0;
    i_rs1_addr = 5'd5;
    i_rs2_addr = 5'd0;
    #1;
    if (o_rs1_data !== 32'h1234_5678 || o_rs2_data !== 32'h0) begin
      $fatal(1, "register file read failed");
    end
  end
endmodule
