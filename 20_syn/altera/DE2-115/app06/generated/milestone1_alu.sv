`timescale 1ns/1ps
module milestone1_alu (
    input  logic [31:0] i_op_a,
    input  logic [31:0] i_op_b,
    input  logic [3:0]  i_alu_op,
    output logic [31:0] o_alu_data
);
    import cpu_pkg::*;
    logic [31:0] arithmetic_data, shift_data;
    logic less_than;
    logic [1:0] shift_mode;

    // Exactly one instance of each reusable datapath block.
    adder u_adder (
        .i_a(i_op_a), .i_b(i_op_b), .i_sub(i_alu_op == ALU_SUB),
        .i_unsigned(1'b1), .o_sum(arithmetic_data), .o_cout()
    );
    magnitude_comparator u_comparator (
        .i_a(i_op_a), .i_b(i_op_b), .i_unsigned(i_alu_op == ALU_SLTU),
        .o_eq(), .o_lt(less_than), .o_gt()
    );
    always_comb begin
        case (i_alu_op)
            ALU_SLL: shift_mode = 2'b01;
            ALU_SRA: shift_mode = 2'b10;
            default: shift_mode = 2'b00;
        endcase
    end
    shifter u_shifter (
        .i_data(i_op_a), .i_shamt(i_op_b[4:0]), .i_mode(shift_mode), .o_data(shift_data)
    );
    always_comb begin
        case (i_alu_op)
            ALU_ADD, ALU_SUB:          o_alu_data = arithmetic_data;
            ALU_SLT, ALU_SLTU:         o_alu_data = {31'b0, less_than};
            ALU_XOR:                  o_alu_data = i_op_a ^ i_op_b;
            ALU_OR:                   o_alu_data = i_op_a | i_op_b;
            ALU_AND:                  o_alu_data = i_op_a & i_op_b;
            ALU_SLL, ALU_SRL, ALU_SRA: o_alu_data = shift_data;
            default:                  o_alu_data = 32'b0;
        endcase
    end
endmodule
