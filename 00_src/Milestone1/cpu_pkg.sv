`timescale 1ns/1ps
package cpu_pkg;
    // Same operation encoding as the existing CPU ALU.
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_XOR  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_AND  = 4'd4,
        ALU_SLL  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_SLT  = 4'd8,
        ALU_SLTU = 4'd9
    } alu_op_e;

    typedef struct packed {
        logic eq;
        logic lt;
        logic gt;
    } compare_result_t;

    // Shared branch/magnitude comparison logic, synthesizable as combinational RTL.
    // Relational operators below only control the fixed loop, not operand comparison.
    function automatic compare_result_t compare_operands(
        input logic [31:0] a,
        input logic [31:0] b,
        input logic        unsigned_mode
    );
        compare_result_t result;
        logic equal_above;
        logic unsigned_lt;

        equal_above = 1'b1;
        unsigned_lt = 1'b0;
        for (int bit_idx = 31; bit_idx >= 0; bit_idx--) begin
            unsigned_lt = unsigned_lt | (equal_above & ~a[bit_idx] & b[bit_idx]);
            equal_above = equal_above & ~(a[bit_idx] ^ b[bit_idx]);
        end
        result.eq = equal_above;
        result.lt = (!unsigned_mode && (a[31] ^ b[31])) ? a[31] : unsigned_lt;
        result.gt = ~(result.eq | result.lt);
        return result;
    endfunction
endpackage
