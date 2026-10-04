module scoreboard_pc
  import rv32i_pkg::*;
(
    input  logic        i_clk    
  , input  logic        i_rst_n  
  , input  logic [31:0] act_pc
  , input  PCSel_e      drv_pc_sel  
  , input  logic        drv_pc_en
  , input  logic [31:0] drv_alu_res
);


  asst_pc_048C: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (act_pc[1:0] == 2'b00)
  );
    else #1 $error;

  asst_pc_add4: assert property(@(posedge i_clk) disable iff (~i_rst_n || ~$past(i_rst_n)) 
    ($past(drv_pc_sel) == PC_4 && $past(drv_pc_en)) |-> (act_pc == $past(act_pc) + 32'h4)
  );
    else #1 $error;

  asst_pc_alu: assert property(@(posedge i_clk) disable iff (~i_rst_n || ~$past(i_rst_n)) 
    ($past(drv_pc_sel) == PC_ALU && $past(drv_pc_en)) |-> (act_pc == $past(drv_alu_res))
  );
    else #1 $error;
endmodule
