// The comparator invokes compare_operands() from cpu_pkg.
module branch_comp (
    input  logic [31:0] i_rs1_data,
    input  logic [31:0] i_rs2_data,
    input  logic        i_br_un,
    output logic        o_br_eq,
    output logic        o_br_lt
);
    magnitude_comparator u_milestone1 (
        .i_a(i_rs1_data), .i_b(i_rs2_data), .i_unsigned(i_br_un),
        .o_eq(o_br_eq), .o_lt(o_br_lt), .o_gt()
    );
endmodule
