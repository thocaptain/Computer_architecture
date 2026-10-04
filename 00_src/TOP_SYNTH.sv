module TOP_SYNTH 
    import rv32i_pkg::*;
(
      input logic         CLOCK_27
    , input logic  [17:0] SW
    , input logic  [3:0]  KEY

    , output logic [8:0]  LEDG
    , output logic [17:0] LEDR

    , output logic [6:0]  HEX0
    , output logic [6:0]  HEX1
    , output logic [6:0]  HEX2
    , output logic [6:0]  HEX3
    , output logic [6:0]  HEX4
    , output logic [6:0]  HEX5
    , output logic [6:0]  HEX6
    , output logic [6:0]  HEX7

    , output logic [7:0]  LCD_DATA
    , output logic        LCD_RW
    , output logic        LCD_EN
    , output logic        LCD_RS
    , output logic        LCD_ON
    // , output logic        LCD_BLON // DE2 has no backlight

    , output logic [17:0] SRAM_ADDR
    , inout  wire  [15:0] SRAM_DQ  
    , output logic        SRAM_CE_N
    , output logic        SRAM_WE_N
    , output logic        SRAM_LB_N
    , output logic        SRAM_UB_N
    , output logic        SRAM_OE_N
);

    logic [3:0] KEY_db;

// KEY ///////////////////////////////////////////
    generate
        genvar k;
        for (k = 0; k<4; k++) begin: g_btn_db
            btn_debounce #(
                .STABLE_TIME_MS(40),
                .CLK_PERIOD_NS (40) // clock 50MHz
            ) btn_debounce (
                .i_clk(CLOCK_27 ), 
                .i_rst_n(SW[0]  ),
                .i_btn(KEY[k]   ),
                .o_btn(KEY_db[k])
            ); 
        end
    endgenerate

// LCD ///////////////////////////////////////////
    localparam LCD_ON_IDX   = 31;
    /* verilator lint_off UNUSEDPARAM */
    localparam LCD_EN_IDX   = 10;
    /* verilator lint_off UNUSEDPARAM */
    localparam LCD_RS_IDX   = 9;
    localparam LCD_RW_IDX   = 8;
    localparam LCD_DATA_IDX = 0;
    localparam LCD_DATA_W   = 8;

    logic [31:0] lcd_val;
    logic        lcd_vld;

    // assign LCD_BLON = 1'b1; // DE2 does not have backlight

lcd_ctrl #(
    .T_PERIOD_NS(40  ), // 50MHz 
    .T_AS_NS    (80  ),  
    .T_PW_NS    (460 ),  
    .T_CYCE_NS  (1000)  
) lcd_ctrl (
    .i_clk     (CLOCK_27),  
    .i_rst_n   (SW[0]   ),    

    .i_vld     (lcd_vld ),  
    /* verilator lint_off PINCONNECTEMPTY */
    .o_rdy     ( ),  
    /* verilator lint_off PINCONNECTEMPTY */

    .i_LCD_DATA(lcd_val[LCD_DATA_IDX +: LCD_DATA_W]),       
    .i_LCD_RW  (lcd_val[LCD_RW_IDX]),     
    .i_LCD_RS  (lcd_val[LCD_RS_IDX]),     
    .i_LCD_ON  (lcd_val[LCD_ON_IDX]),     

    .o_LCD_DATA(LCD_DATA),       
    .o_LCD_RW  (LCD_RW  ),       
    .o_LCD_EN  (LCD_EN  ),        
    .o_LCD_RS  (LCD_RS  ),        
    .o_LCD_ON  (LCD_ON  )        
);
/////////////////////////////////////////////////
// RISC-V
////////////////////////////////////////////////

/* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] io_ledg;
    logic [31:0] io_ledr;
/* verilator lint_off UNUSEDSIGNAL */
    logic [6:0]  io_hex0;
    logic [6:0]  io_hex1;
    logic [6:0]  io_hex2;
    logic [6:0]  io_hex3;
    logic [6:0]  io_hex4;
    logic [6:0]  io_hex5;
    logic [6:0]  io_hex6;
    logic [6:0]  io_hex7;
    logic [31:0] io_sw  ;   

    assign LEDG[8:0]  = io_ledg[8:0];
    assign LEDR[17:0] = io_ledr[17:0];
    assign io_sw      = {14'd0, SW};

    always_comb begin 
        HEX0 = bcd_to_7seg(io_hex0[3:0]);
        HEX1 = bcd_to_7seg(io_hex1[3:0]);
        HEX2 = bcd_to_7seg(io_hex2[3:0]);
        HEX3 = bcd_to_7seg(io_hex3[3:0]);
        HEX4 = bcd_to_7seg(io_hex4[3:0]);
        HEX5 = bcd_to_7seg(io_hex5[3:0]);
        HEX6 = bcd_to_7seg(io_hex6[3:0]);
        HEX7 = bcd_to_7seg(io_hex7[3:0]);
    end

    rv32i #(
        .INST_MEM_ADDR_W(10),
        .MEM_TYPE(MEM_FLOP), // 1: sram-based
        .CACHE(1)
    ) rv32i(
    .i_clk     (CLOCK_27  ), 
    .i_rst_n   (SW[0]     ),   
    .o_io_ledg (io_ledg   ),
    .o_io_ledr (io_ledr   ),
    .o_io_hex0 (io_hex0   ),     
    .o_io_hex1 (io_hex1   ),     
    .o_io_hex2 (io_hex2   ),     
    .o_io_hex3 (io_hex3   ),     
    .o_io_hex4 (io_hex4   ),     
    .o_io_hex5 (io_hex5   ),     
    .o_io_hex6 (io_hex6   ),     
    .o_io_hex7 (io_hex7   ),     
    .o_io_lcd  (lcd_val   ),
    .i_io_sw   (io_sw     ),   
    .i_io_btn  (KEY_db    ),    
    .o_lcd_vld (lcd_vld   ),
    .SRAM_ADDR (SRAM_ADDR ),      
    .SRAM_DQ   (SRAM_DQ   ),      
    .SRAM_CE_N (SRAM_CE_N ),      
    .SRAM_WE_N (SRAM_WE_N ),      
    .SRAM_LB_N (SRAM_LB_N ),      
    .SRAM_UB_N (SRAM_UB_N ),      
    .SRAM_OE_N (SRAM_OE_N ),
    /* verilator lint_off PINCONNECTEMPTY */
    .o_pc_debug(),
    .o_insn_vld()
    /* verilator lint_off PINCONNECTEMPTY */
    );
endmodule
