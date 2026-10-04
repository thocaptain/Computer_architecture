module driver_alu
    import rv32i_pkg::*;
(
    input   logic        i_clk
  , output  logic [31:0] i_operand_a
  , output  logic [31:0] i_operand_b
  , output  ALUSel_e     i_alu_op
);

  always @(posedge i_clk) begin
    i_operand_a <= $urandom;
    i_operand_b <= $urandom;

    case ($urandom%10)
        0: i_alu_op <= ALU_ADD ;
        1: i_alu_op <= ALU_SUB ;
        2: i_alu_op <= ALU_XOR ;
        3: i_alu_op <= ALU_OR  ;
        4: i_alu_op <= ALU_AND ;
        5: i_alu_op <= ALU_SLL ;
        6: i_alu_op <= ALU_SRL ;
        7: i_alu_op <= ALU_SRA ;
        8: i_alu_op <= ALU_SLT ;
        9: i_alu_op <= ALU_SLTU;
        default: i_alu_op <= ALU_ADD;
    endcase
  end

endmodule
