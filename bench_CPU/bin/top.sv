`default_nettype none

module top #(
  parameter integer CORE_MODE = 0
) (
  input  logic [17:1]      io_sw_i  ,
  output logic [31:0]      io_lcd_o ,
  output logic [31:0]      io_ledg_o,
  output logic [31:0]      io_ledr_o,
  output logic [31:0]      io_hex0_o,
  output logic [31:0]      io_hex1_o,
  output logic [31:0]      io_hex2_o,
  output logic [31:0]      io_hex3_o,
  output logic [31:0]      io_hex4_o,
  output logic [31:0]      io_hex5_o,
  output logic [31:0]      io_hex6_o,
  output logic [31:0]      io_hex7_o,
  output logic [31:0]      pc_debug_o,
  output logic             insn_valid_o,
  input  logic             clk_i    ,
  input  logic             rst_ni
);
  logic [31:0] core_ledr, core_ledg, core_lcd, core_pc;
  logic [6:0] core_hex0, core_hex1, core_hex2, core_hex3;
  logic [6:0] core_hex4, core_hex5, core_hex6, core_hex7;
  logic core_insn_valid;

  assign io_ledr_o = core_ledr;
  assign io_ledg_o = core_ledg;
  assign io_lcd_o = core_lcd;
  assign io_hex0_o = {25'd0, core_hex0};
  assign io_hex1_o = {25'd0, core_hex1};
  assign io_hex2_o = {25'd0, core_hex2};
  assign io_hex3_o = {25'd0, core_hex3};
  assign io_hex4_o = {25'd0, core_hex4};
  assign io_hex5_o = {25'd0, core_hex5};
  assign io_hex6_o = {25'd0, core_hex6};
  assign io_hex7_o = {25'd0, core_hex7};
  assign pc_debug_o = core_pc;
  assign insn_valid_o = core_insn_valid;

  generate
    if (CORE_MODE == 0) begin : g_single_cycle
      logic [31:0] switches;
      TOP_SINGLE_CYCLE #(
        .INST_MEM_ADDR_W(10),
        .MEM_TYPE(0),
        .CACHE(0)
      ) cpu (
        .i_clk(clk_i),
        .i_rst_n(rst_ni),
        .o_pc_debug(core_pc),
        .o_insn_vld(core_insn_valid),
        .o_io_ledr(core_ledr),
        .o_io_ledg(core_ledg),
        .o_io_hex0(core_hex0),
        .o_io_hex1(core_hex1),
        .o_io_hex2(core_hex2),
        .o_io_hex3(core_hex3),
        .o_io_hex4(core_hex4),
        .o_io_hex5(core_hex5),
        .o_io_hex6(core_hex6),
        .o_io_hex7(core_hex7),
        .o_io_lcd(core_lcd),
        .i_io_sw(switches),
        .i_io_btn(4'b0),
        .o_lcd_vld(),
        .SRAM_ADDR(),
        .SRAM_DQ(),
        .SRAM_CE_N(),
        .SRAM_WE_N(),
        .SRAM_LB_N(),
        .SRAM_UB_N(),
        .SRAM_OE_N()
      );
      assign switches = {14'd0, io_sw_i, rst_ni};
    end else if (CORE_MODE == 1) begin : g_pipeline_stall
      logic [31:0] switches;
      rv32i_pipeline_stall cpu (
        .i_clk(clk_i), .i_rst_n(rst_ni),
        .o_pc_debug(core_pc), .o_insn_vld(core_insn_valid),
        .o_io_ledr(core_ledr), .o_io_ledg(core_ledg),
        .o_io_hex0(core_hex0), .o_io_hex1(core_hex1),
        .o_io_hex2(core_hex2), .o_io_hex3(core_hex3),
        .o_io_hex4(core_hex4), .o_io_hex5(core_hex5),
        .o_io_hex6(core_hex6), .o_io_hex7(core_hex7),
        .o_io_lcd(core_lcd), .i_io_sw(switches), .i_io_btn(4'b0),
        .o_lcd_vld(), .SRAM_ADDR(), .SRAM_DQ(),
        .SRAM_CE_N(), .SRAM_WE_N(), .SRAM_LB_N(), .SRAM_UB_N(), .SRAM_OE_N()
      );
      assign switches = {14'd0, io_sw_i, rst_ni};
    end else if (CORE_MODE == 2) begin : g_pipeline_hazard
      logic [31:0] switches;
      rv32i_pipeline_hazard cpu (
        .i_clk(clk_i), .i_rst_n(rst_ni),
        .o_pc_debug(core_pc), .o_insn_vld(core_insn_valid),
        .o_io_ledr(core_ledr), .o_io_ledg(core_ledg),
        .o_io_hex0(core_hex0), .o_io_hex1(core_hex1),
        .o_io_hex2(core_hex2), .o_io_hex3(core_hex3),
        .o_io_hex4(core_hex4), .o_io_hex5(core_hex5),
        .o_io_hex6(core_hex6), .o_io_hex7(core_hex7),
        .o_io_lcd(core_lcd), .i_io_sw(switches), .i_io_btn(4'b0),
        .o_lcd_vld(), .SRAM_ADDR(), .SRAM_DQ(),
        .SRAM_CE_N(), .SRAM_WE_N(), .SRAM_LB_N(), .SRAM_UB_N(), .SRAM_OE_N()
      );
      assign switches = {14'd0, io_sw_i, rst_ni};
    end else if (CORE_MODE == 3) begin : g_top_synth
      logic [17:0] board_sw;
      logic [17:0] board_ledr;
      logic [8:0] board_ledg;
      logic [6:0] hex0, hex1, hex2, hex3;
      logic [6:0] hex4, hex5, hex6, hex7;
      logic [7:0] lcd_data;
      logic lcd_rw, lcd_en, lcd_rs, lcd_on;

      assign board_sw = {io_sw_i, rst_ni};
      assign core_ledr = {14'd0, board_ledr};
      assign core_ledg = {23'd0, board_ledg};
      assign core_hex0 = hex0;
      assign core_hex1 = hex1;
      assign core_hex2 = hex2;
      assign core_hex3 = hex3;
      assign core_hex4 = hex4;
      assign core_hex5 = hex5;
      assign core_hex6 = hex6;
      assign core_hex7 = hex7;
      assign core_lcd = {20'd0, lcd_on, lcd_en, lcd_rs, lcd_rw, lcd_data};
      assign core_pc = 32'd0;
      assign core_insn_valid = 1'b0;

      TOP_SYNTH dut (
        .CLOCK_27(clk_i),
        .SW(board_sw),
        .KEY(4'b0),
        .LEDG(board_ledg),
        .LEDR(board_ledr),
        .HEX0(hex0),
        .HEX1(hex1),
        .HEX2(hex2),
        .HEX3(hex3),
        .HEX4(hex4),
        .HEX5(hex5),
        .HEX6(hex6),
        .HEX7(hex7),
        .LCD_DATA(lcd_data),
        .LCD_RW(lcd_rw),
        .LCD_EN(lcd_en),
        .LCD_RS(lcd_rs),
        .LCD_ON(lcd_on),
        .SRAM_ADDR(),
        .SRAM_DQ(),
        .SRAM_CE_N(),
        .SRAM_WE_N(),
        .SRAM_LB_N(),
        .SRAM_UB_N(),
        .SRAM_OE_N()
      );
    end else begin : g_invalid_mode
      assign core_ledr = 32'd0;
      assign core_ledg = 32'd0;
      assign core_lcd = 32'd0;
      assign core_pc = 32'd0;
      assign core_insn_valid = 1'b0;
      assign core_hex0 = 7'd0;
      assign core_hex1 = 7'd0;
      assign core_hex2 = 7'd0;
      assign core_hex3 = 7'd0;
      assign core_hex4 = 7'd0;
      assign core_hex5 = 7'd0;
      assign core_hex6 = 7'd0;
      assign core_hex7 = 7'd0;
    end
  endgenerate

endmodule : top
