// =============================================================================
// Module Name:   alu
// Project:       Milestone 3 - Simple MCU
// Description:   RV32I arithmetic, logic, comparison and barrel-shift datapath.
// =============================================================================

`timescale 1ns / 1ps

module alu
    import rv32i_pkg::*;
(
    // ALU Operands & Result
    input  logic    [31:0] i_operand_a,
    input  logic    [31:0] i_operand_b,
    input  ALUSel_e        i_alu_op,
    output logic    [31:0] o_alu_res
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic        subtract;
    logic        carry;
    logic        signed_less;
    logic [31:0] sum;
    wire  [31:0] left_stage [0:5];
    wire  [31:0] right_stage [0:5];
    logic        fill;

    // =========================================================================
    // Arithmetic and Signed Comparison
    // =========================================================================
    assign subtract = (i_alu_op == ALU_SUB)
        | (i_alu_op == ALU_SLT)
        | (i_alu_op == ALU_SLTU);
    bit_adder arithmetic (
        .i_a     (i_operand_a),
        .i_b     (i_operand_b ^ {32{subtract}}),
        .i_carry (subtract),
        .o_sum   (sum),
        .o_carry (carry)
    );

    assign signed_less = (i_operand_a[31] ^ i_operand_b[31]) ? i_operand_a[31] : sum[31];

    // =========================================================================
    // Barrel Shifter
    // =========================================================================
    assign fill           = (i_alu_op == ALU_SRA) & i_operand_a[31];
    assign left_stage[0]  = i_operand_a;
    assign right_stage[0] = i_operand_a;
    genvar stage;
    generate
    for (stage = 0; stage < 5; stage = stage + 1) begin : g_shift
        localparam int DISTANCE = 2**stage;
        assign left_stage[stage+1]     = i_operand_b[stage]
            ? {left_stage[stage][31-DISTANCE:0], {DISTANCE{1'b0}}}
            : left_stage[stage];
        assign right_stage[stage+1] = i_operand_b[stage]
            ? {{DISTANCE{fill}}, right_stage[stage][31:DISTANCE]}
            : right_stage[stage];
    end
    endgenerate

    // =========================================================================
    // ALU Result Selection
    // =========================================================================
    always_comb begin
        case (i_alu_op)
            ALU_ADD, ALU_SUB: o_alu_res = sum;
            ALU_XOR: o_alu_res = i_operand_a ^ i_operand_b;
            ALU_OR: o_alu_res  = i_operand_a | i_operand_b;
            ALU_AND: o_alu_res = i_operand_a & i_operand_b;
            ALU_SLL: o_alu_res = left_stage[5];
            ALU_SRL, ALU_SRA: o_alu_res = right_stage[5];
            ALU_SLT: o_alu_res  = {31'b0, signed_less};
            ALU_SLTU: o_alu_res = {31'b0, ~carry};
            default: o_alu_res  = '0;
        endcase
    end
endmodule: alu
