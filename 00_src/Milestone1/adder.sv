`timescale 1ns/1ps
// Ripple-carry adder/subtractor. No arithmetic operators in the datapath.
module adder (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic        i_sub,
    input  logic        i_unsigned,
    output logic [31:0] o_sum,
    output logic        o_cout
);
    logic [31:0] b_selected;
    logic signed_extension;

    assign b_selected = i_b ^ {32{i_sub}};
    for (genvar bit_idx = 0; bit_idx < 32; bit_idx++) begin : g_bit
        logic carry_in, carry_out;
        if (bit_idx == 0) begin : g_first
            assign carry_in = i_sub;
        end else begin : g_next
            assign carry_in = g_bit[bit_idx-1].carry_out;
        end
        assign o_sum[bit_idx] = i_a[bit_idx] ^ b_selected[bit_idx] ^ carry_in;
        assign carry_out = (i_a[bit_idx] & b_selected[bit_idx]) |
                           ((i_a[bit_idx] ^ b_selected[bit_idx]) & carry_in);
    end
    // Unsigned: raw carry (subtraction: 1 means no borrow).
    // Signed: bit 32 of the sign-extended arithmetic result; not overflow.
    assign signed_extension = i_a[31] ^ i_b[31] ^ i_sub ^ g_bit[31].carry_out;
    assign o_cout = i_unsigned ? g_bit[31].carry_out : signed_extension;
endmodule
