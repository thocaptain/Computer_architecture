module scoreboard_lsu
  import rv32i_pkg::*;
(
    input  logic        i_clk    
  , input  logic        i_rst_n  

  , input  logic        drv_VALID
  , input  logic [31:0] drv_lsu_addr


  , input  logic        act_vld_data_mem
  , input  logic        act_vld_ledr    
  , input  logic        act_vld_ledg    
  , input  logic        act_vld_seg7    
  , input  logic        act_vld_lcd     
  , input  logic        act_vld_sw      
  , input  logic        act_vld_btn     
  , input  logic        act_vld_timer   
);


  asst_lsu_vld_datamem: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_data_mem == ((drv_lsu_addr >= DATA_BASE_ADDR) && (drv_lsu_addr < DATA_LAST_ADDR) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_ledr: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_ledr == ((drv_lsu_addr >= LEDR_BASE_ADDR) && (drv_lsu_addr < LEDR_BASE_ADDR+4) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_ledg: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_ledg == ((drv_lsu_addr >= LEDG_BASE_ADDR) && (drv_lsu_addr < LEDG_BASE_ADDR+4) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_seg7: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_seg7 == ((drv_lsu_addr >= SEG7_BASE_ADDR) && (drv_lsu_addr < SEG7_BASE_ADDR+8) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_lcd: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_lcd == ((drv_lsu_addr >= LCD_BASE_ADDR) && (drv_lsu_addr < LCD_BASE_ADDR+4) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_sw: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_sw == ((drv_lsu_addr >= SW_BASE_ADDR) && (drv_lsu_addr < SW_BASE_ADDR+4) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_btn: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_btn == ((drv_lsu_addr >= BTN_BASE_ADDR) && (drv_lsu_addr < BTN_BASE_ADDR+4) && drv_VALID)
  );
    else #1 $error;

  asst_lsu_vld_timer: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    act_vld_timer == ((drv_lsu_addr >= TIMER_BASE_ADDR) && (drv_lsu_addr < TIMER_BASE_ADDR+16) && drv_VALID)
  );
    else #1 $error;
endmodule
