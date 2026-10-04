module TOP_SINGLE_CYCLE_DE2_115
    import rv32i_pkg::*;
(
      input  logic        CLOCK_50
    , input  logic        RESET_SW
    , output logic [17:0] LEDR
    , output logic [8:0]  LEDG
    , output logic [6:0]  HEX0
    , output logic [6:0]  HEX1
    , output logic [6:0]  HEX2
    , output logic [6:0]  HEX3
    , output logic [6:0]  HEX4
    , output logic [6:0]  HEX5
    , output logic [6:0]  HEX6
    , output logic [6:0]  HEX7
);
    logic [31:0] ledr;
    logic [31:0] ledg;
    logic [6:0] hex0_bcd;
    logic [6:0] hex1_bcd;
    logic [6:0] hex2_bcd;
    logic [6:0] hex3_bcd;
    logic [6:0] hex4_bcd;
    logic [6:0] hex5_bcd;
    logic [6:0] hex6_bcd;
    logic [6:0] hex7_bcd;

    assign LEDR = ledr[17:0];
    assign LEDG = ledg[8:0];

    always_comb begin
        HEX0 = bcd_to_7seg(hex0_bcd[3:0]);
        HEX1 = bcd_to_7seg(hex1_bcd[3:0]);
        HEX2 = bcd_to_7seg(hex2_bcd[3:0]);
        HEX3 = bcd_to_7seg(hex3_bcd[3:0]);
        HEX4 = bcd_to_7seg(hex4_bcd[3:0]);
        HEX5 = bcd_to_7seg(hex5_bcd[3:0]);
        HEX6 = bcd_to_7seg(hex6_bcd[3:0]);
        HEX7 = bcd_to_7seg(hex7_bcd[3:0]);
    end

    TOP_SINGLE_CYCLE #(
        .INST_MEM_ADDR_W(10),
        .MEM_TYPE(MEM_FLOP),
        .CACHE(0)
    ) cpu (
        .i_clk(CLOCK_50),
        .i_rst_n(RESET_SW),
        .o_pc_debug(),
        .o_insn_vld(),
        .o_io_ledr(ledr),
        .o_io_ledg(ledg),
        .o_io_hex0(hex0_bcd),
        .o_io_hex1(hex1_bcd),
        .o_io_hex2(hex2_bcd),
        .o_io_hex3(hex3_bcd),
        .o_io_hex4(hex4_bcd),
        .o_io_hex5(hex5_bcd),
        .o_io_hex6(hex6_bcd),
        .o_io_hex7(hex7_bcd),
        .o_io_lcd(),
        .i_io_sw(32'b0),
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
endmodule