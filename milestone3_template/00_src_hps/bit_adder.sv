// =============================================================================
// Module Name:   bit_adder
// Project:       Milestone 3 - Simple MCU
// Description:   Parameterized ripple-carry adder built from full-adder gates.
// =============================================================================

`timescale 1ns / 1ps

module bit_adder #(
    parameter int WIDTH = 32
)(
    // Adder Inputs
    input  logic [WIDTH-1:0] i_a,
    input  logic [WIDTH-1:0] i_b,
    input  logic             i_carry,

    // Adder Outputs
    output logic [WIDTH-1:0] o_sum,
    output logic             o_carry
);

    // =========================================================================
    // Carry Chain
    // =========================================================================
    wire [WIDTH:0] carry;
    assign carry[0] = i_carry;

    // =========================================================================
    // Full-Adder Stages
    // =========================================================================
    genvar bit_index;
    generate
    for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin : g_bit
        assign o_sum[bit_index]   = i_a[bit_index] ^ i_b[bit_index] ^ carry[bit_index];
        assign carry[bit_index+1] = (i_a[bit_index] & i_b[bit_index])
            | ((i_a[bit_index] ^ i_b[bit_index]) & carry[bit_index]);
    end
    endgenerate

    // =========================================================================
    // Final Carry Output
    // =========================================================================
    assign o_carry = carry[WIDTH];
endmodule: bit_adder
