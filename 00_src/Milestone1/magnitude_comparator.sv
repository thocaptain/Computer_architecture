`timescale 1ns/1ps
module magnitude_comparator (
    input  logic [31:0] i_a,
    input  logic [31:0] i_b,
    input  logic        i_unsigned,
    output logic        o_eq,
    output logic        o_lt,
    output logic        o_gt
);
    import cpu_pkg::*;
    compare_result_t result;

    assign result = compare_operands(i_a, i_b, i_unsigned);
    assign o_eq = result.eq;
    assign o_lt = result.lt;
    assign o_gt = result.gt;
endmodule
