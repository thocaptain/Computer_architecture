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
  logic [31:0] drv_rs1_data;
  logic [31:0] drv_rs2_data;
  logic drv_br_un;
  logic act_br_eq;
  logic act_br_lt;

  initial tsk_clock_gen(i_clk);
  initial tsk_reset(i_rst_n, `RESETPERIOD);
  initial tsk_timeout(`FINISH);

  driver_branch_comp driver (
    .i_clk(i_clk),
    .o_rs1_data(drv_rs1_data),
    .o_rs2_data(drv_rs2_data),
    .o_br_un(drv_br_un)
  );

  branch_comp dut (
    .i_rs1_data(drv_rs1_data),
    .i_rs2_data(drv_rs2_data),
    .i_br_un(drv_br_un),
    .o_br_eq(act_br_eq),
    .o_br_lt(act_br_lt)
  );

  scoreboard_branch_comp scoreboard (
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .drv_rs1_data(drv_rs1_data),
    .drv_rs2_data(drv_rs2_data),
    .drv_br_un(drv_br_un),
    .act_br_eq(act_br_eq),
    .act_br_lt(act_br_lt)
  );
endmodule
