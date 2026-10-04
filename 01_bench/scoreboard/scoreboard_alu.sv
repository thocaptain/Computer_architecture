module scoreboard_alu
  import rv32i_pkg::*;
(
    input  logic        i_clk    
  , input  logic        i_rst_n  
  , input  logic [31:0] act_alu_res
  , input  logic [31:0] drv_operand_a
  , input  logic [31:0] drv_operand_b
  , input  ALUSel_e     drv_alu_op
);

  logic [31:0] golden_alu_res;

  always_comb begin
      case (drv_alu_op)
        /*0*/  ALU_ADD  : golden_alu_res = drv_operand_a + drv_operand_b;        
        /*1*/  ALU_SUB  : golden_alu_res = drv_operand_a - drv_operand_b;        
        /*2*/  ALU_XOR  : golden_alu_res = drv_operand_a ^ drv_operand_b;        
        /*3*/  ALU_OR   : golden_alu_res = drv_operand_a | drv_operand_b;        
        /*4*/  ALU_AND  : golden_alu_res = drv_operand_a & drv_operand_b;        
        /*5*/  ALU_SLL  : golden_alu_res = drv_operand_a << drv_operand_b[4:0];  
        /*6*/  ALU_SRL  : golden_alu_res = drv_operand_a >> drv_operand_b[4:0];  
        /*7*/  ALU_SRA  : golden_alu_res = $signed(drv_operand_a) >>> drv_operand_b[4:0]; 
        /*8*/  ALU_SLT  : golden_alu_res = {31'd0, $signed(drv_operand_a)   < $signed(drv_operand_b)}; 
        /*9*/  ALU_SLTU : golden_alu_res = {31'd0, $unsigned(drv_operand_a) < $unsigned(drv_operand_b)}; 
          default  : golden_alu_res = 32'b0;                         
      endcase
  end

  // always @(posedge i_clk) begin
    // $display("ALU_SCOREBOARD: @%05d rst=%1b, A=%8h, B=%8h, op=%h, actual=%8h, golden = %8h", $time, i_rst_n, drv_operand_a, drv_operand_b, drv_alu_op, act_alu_res, golden_alu_res);
  // end

  asst_alu: assert property(@(posedge i_clk) disable iff (~i_rst_n) (act_alu_res == golden_alu_res));
    else #1 $error;

endmodule
