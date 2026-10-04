module scoreboard_lsu_dat_handler
  import rv32i_pkg::*;
(
    input logic                    i_clk    
  , input logic                    i_rst_n  

  , input logic [FUNCT3_WIDTH-1:0] drv_funct3
  , input logic [1:0]              drv_lsb_addr
  , input logic [31:0]             drv_ld_data
  , input logic [31:0]             drv_st_data

  , input logic [31:0]             act_st_data
  , input logic [3:0]              act_st_strb
  , input logic [31:0]             act_ld_data
);

  asst_lsu_dat_handler_st_strb_byte: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b00) |-> (act_st_strb == (4'b0001 << drv_lsb_addr[1:0]))
  );
    else #1 $error;

  asst_lsu_dat_handler_st_strb_half: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b01) |-> (act_st_strb == (4'b0011 << 2*drv_lsb_addr[1]))
  );
    else #1 $error;

  asst_lsu_dat_handler_st_strb_word: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b10) |-> (act_st_strb == 4'b1111)
  );
    else #1 $error;


  asst_lsu_dat_handler_st_dat_byte: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b00) |-> (act_st_data[8*drv_lsb_addr[1:0]+:8] == drv_st_data[7:0])
  );
    else #1 $error;

  asst_lsu_dat_handler_st_dat_half: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b01) |-> (act_st_data[16*drv_lsb_addr[1]+:16] == drv_st_data[15:0])
  );
    else #1 $error;

  asst_lsu_dat_handler_st_dat_word: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b10) |-> (act_st_data == drv_st_data)
  );
    else #1 $error;


  logic is_unsigned;
  assign is_unsigned =  drv_funct3[2];

  asst_lsu_dat_handler_ld_dat_byte: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b00) |-> (act_ld_data == {(is_unsigned)? 24'd0 : {24{drv_ld_data[8*drv_lsb_addr[1:0]+7]}}, drv_ld_data[8*drv_lsb_addr[1:0]+:8]})
  );
    else #1 $error;
  asst_lsu_dat_handler_ld_dat_half: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b01) |-> (act_ld_data == {(is_unsigned)? 16'd0 : {16{drv_ld_data[16*drv_lsb_addr[1]+15]}}, drv_ld_data[16*drv_lsb_addr[1]+:16]})
  );
    else #1 $error;
  asst_lsu_dat_handler_ld_dat_word: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_funct3[1:0] == 2'b10) |-> (act_ld_data == drv_ld_data)
  );
    else #1 $error;
endmodule
