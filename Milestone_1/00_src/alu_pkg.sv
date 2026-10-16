// ALU operation encoding shared by the ALU and its testbench.
package alu_pkg;

  typedef enum logic [3:0] {
    ALU_ADD  = 4'd0,
    ALU_SUB  = 4'd1,
    ALU_SLT  = 4'd2,
    ALU_SLTU = 4'd3,
    ALU_XOR  = 4'd4,
    ALU_OR   = 4'd5,
    ALU_AND  = 4'd6,
    ALU_SLL  = 4'd7,
    ALU_SRL  = 4'd8,
    ALU_SRA  = 4'd9
  } alu_op_e;

endpackage : alu_pkg
