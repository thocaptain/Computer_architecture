module scoreboard_branch_comp
  import rv32i_pkg::*;
(
      input logic        i_clk
    , input logic        i_rst_n
    , input logic [31:0] drv_rs1_data
    , input logic [31:0] drv_rs2_data
    , input logic        drv_br_un 
    , input logic        act_br_eq
    , input logic        act_br_lt
);

  asst_br_sign_lt: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (~drv_br_un) |-> (act_br_lt == ($signed(drv_rs1_data) < $signed(drv_rs2_data)))
  );
    else #1 $error;

  asst_br_usign_lt: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_br_un) |-> (act_br_lt == ($unsigned(drv_rs1_data) < $unsigned(drv_rs2_data)))
  );
    else #1 $error;

  asst_br_eq: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (act_br_eq == ($unsigned(drv_rs1_data) == $unsigned(drv_rs2_data)))
  );
    else #1 $error;
endmodule

