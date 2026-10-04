`include "timescale.svh"
`include "tlib.svh"

`define RESETPERIOD 55
`define FINISH      1150000

module tbench
  import rv32i_pkg::*;
();

// Wave dumping
  initial begin : proc_dump_wave
    $dumpfile("wave.vcd");
    $dumpvars(0, dut);
  end

/* verilator lint_off UNUSEDSIGNAL */
    logic         CLOCK_27;
    logic  [17:0] SW = 18'd1231;
    logic  [3:0]  KEY = 4'd0000;

    logic [8:0]  LEDG;
    logic [17:0] LEDR;

    logic [6:0]  HEX0;
    logic [6:0]  HEX1;
    logic [6:0]  HEX2;
    logic [6:0]  HEX3;
    logic [6:0]  HEX4;
    logic [6:0]  HEX5;
    logic [6:0]  HEX6;
    logic [6:0]  HEX7;

    logic [7:0]  LCD_DATA;
    logic        LCD_RW;
    logic        LCD_EN;
    logic        LCD_RS;
    logic        LCD_ON;

    logic [17:0] SRAM_ADDR;
    wire  [15:0] SRAM_DQ  ;
    logic        SRAM_CE_N;
    logic        SRAM_WE_N;
    logic        SRAM_LB_N;
    logic        SRAM_UB_N;
    logic        SRAM_OE_N=0;

/* verilator lint_off UNUSEDSIGNAL */
  logic i_rst_n;

  initial tsk_clock_gen(CLOCK_27);
  initial tsk_reset(i_rst_n, `RESETPERIOD);
  initial tsk_timeout(`FINISH);
  // initial tsk_button_gen(KEY);
//   initial tsk_switch_gen(SW);

  assign SW[0] = i_rst_n;

  TOP_SYNTH #(
  ) dut (
  .*
  );

  // scoreboard_br_pred scoreboard_br_pred(
  //   .i_clk        (CLOCK_27)  ,
  //   .i_rst_n      (i_rst_n),
  //   .i_is_br      (dut.rv32i.ID_EX_creg_q.is_br_inst),
  //   .i_is_correct (~dut.rv32i.EX_is_pred_wrong)
  // );

endmodule : tbench
