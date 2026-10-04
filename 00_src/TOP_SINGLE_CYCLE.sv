module TOP_SINGLE_CYCLE
    import rv32i_pkg::*;
#(
    parameter INST_MEM_ADDR_W = 10,
    parameter MEM_TYPE = MEM_FLOP,
    parameter CACHE = 0
)
(
      input  logic        i_clk
    , input  logic        i_rst_n
    , output logic [31:0] o_pc_debug
    , output logic        o_insn_vld
    , output logic [31:0] o_io_ledr
    , output logic [31:0] o_io_ledg
    , output logic [6:0]  o_io_hex0
    , output logic [6:0]  o_io_hex1
    , output logic [6:0]  o_io_hex2
    , output logic [6:0]  o_io_hex3
    , output logic [6:0]  o_io_hex4
    , output logic [6:0]  o_io_hex5
    , output logic [6:0]  o_io_hex6
    , output logic [6:0]  o_io_hex7
    , output logic [31:0] o_io_lcd
    , input  logic [31:0] i_io_sw
    , input  logic [3:0]  i_io_btn
    , output logic        o_lcd_vld
    , output logic [17:0] SRAM_ADDR
    , inout  wire  [15:0] SRAM_DQ
    , output logic        SRAM_CE_N
    , output logic        SRAM_WE_N
    , output logic        SRAM_LB_N
    , output logic        SRAM_UB_N
    , output logic        SRAM_OE_N
);

    rv32i_single_cycle #(
        .INST_MEM_ADDR_W(INST_MEM_ADDR_W),
        .MEM_TYPE(MEM_TYPE),
        .CACHE(CACHE)
    ) cpu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .o_pc_debug(o_pc_debug),
        .o_insn_vld(o_insn_vld),
        .o_io_ledr(o_io_ledr),
        .o_io_ledg(o_io_ledg),
        .o_io_hex0(o_io_hex0),
        .o_io_hex1(o_io_hex1),
        .o_io_hex2(o_io_hex2),
        .o_io_hex3(o_io_hex3),
        .o_io_hex4(o_io_hex4),
        .o_io_hex5(o_io_hex5),
        .o_io_hex6(o_io_hex6),
        .o_io_hex7(o_io_hex7),
        .o_io_lcd(o_io_lcd),
        .i_io_sw(i_io_sw),
        .i_io_btn(i_io_btn),
        .o_lcd_vld(o_lcd_vld),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_CE_N(SRAM_CE_N),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_OE_N(SRAM_OE_N)
    );
endmodule
