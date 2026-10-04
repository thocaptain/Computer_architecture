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

  logic i_clk;
  logic i_rst_n;

  logic [31:0] i_operand_a;
  logic [31:0] i_operand_b;
  ALUSel_e     i_alu_op;
  logic [31:0] o_alu_res;

  initial tsk_clock_gen(i_clk);
  initial tsk_reset(i_rst_n, `RESETPERIOD);
  initial tsk_timeout(`FINISH);

  driver_alu driver (
    .i_clk      (i_clk      ),  
    .i_operand_a(i_operand_a),        
    .i_operand_b(i_operand_b),        
    .i_alu_op   (i_alu_op   )     
  );

  alu dut(
    .i_operand_a(i_operand_a),    
    .i_operand_b(i_operand_b),    
    .i_alu_op   (i_alu_op   ), 
    .o_alu_res  (o_alu_res  )  
  );

  scoreboard_alu scoreboard
  (
    .i_clk        (i_clk      ),  
    .i_rst_n      (i_rst_n    ),  
    .act_alu_res  (o_alu_res  ),  
    .drv_operand_a(i_operand_a),    
    .drv_operand_b(i_operand_b),    
    .drv_alu_op   (i_alu_op   ) 
  );

endmodule : tbench


