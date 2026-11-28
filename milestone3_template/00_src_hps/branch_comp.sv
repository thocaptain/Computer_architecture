// =============================================================================
// Module Name:   branch_comp
// Project:       Milestone 3 - Simple MCU
// Description:   Signed and unsigned comparisons for RV32I branch instructions.
// =============================================================================

`timescale 1ns / 1ps

module branch_comp (
    // Register Operands & Branch Comparison
    input  logic [31:0] i_rs1_data,
    input  logic [31:0] i_rs2_data,
    input  logic        i_br_un,
    output logic        o_br_eq,
    output logic        o_br_lt
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic [31:0] difference;
    logic        carry;
    logic        signed_less;

    // =========================================================================
    // Subtraction Datapath
    // =========================================================================
    bit_adder compare_subtract (
        .i_a     (i_rs1_data),
        .i_b     (~i_rs2_data),
        .i_carry (1'b1),
        .o_sum   (difference),
        .o_carry (carry)
    );

    // =========================================================================
    // Branch Comparison Results
    // =========================================================================
    assign signed_less = (i_rs1_data[31] ^ i_rs2_data[31])
        ? i_rs1_data[31]
        : difference[31];
    assign o_br_eq = (i_rs1_data == i_rs2_data);
    assign o_br_lt = i_br_un ? ~carry : signed_less;
endmodule: branch_comp
