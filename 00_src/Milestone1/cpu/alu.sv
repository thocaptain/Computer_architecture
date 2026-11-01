// Legacy CPU interface -> the actual Milestone1 ALU.
module alu import rv32i_pkg::*; (
    input  logic [31:0] i_operand_a,
    input  logic [31:0] i_operand_b,
    input  ALUSel_e     i_alu_op,
    output logic [31:0] o_alu_res
);
    // Both packages deliberately use the same 0..9 operation encoding.
    milestone1_alu u_milestone1 (
        .i_op_a(i_operand_a), .i_op_b(i_operand_b),
        .i_alu_op(i_alu_op), .o_alu_data(o_alu_res)
    );
endmodule
