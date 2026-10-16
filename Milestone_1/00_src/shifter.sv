// Exercise 3: 32-bit barrel shifter (5-stage logarithmic shifter).
//
// A single right-shifter is shared by all modes. Logical left shift is done by
// bit-reversing the input and the output around the right-shifter. The fill bit
// is the sign bit only for arithmetic right shift. No shift operator is used.
//
//   i_mode = 2'b00 : logical right
//            2'b01 : logical left
//            2'b10 : arithmetic right
//            2'b11 : reserved, o_data = 0
module shifter (
  input  logic [31:0] i_data,
  input  logic [4:0]  i_shamt,
  input  logic [1:0]  i_mode,
  output logic [31:0] o_data
);

  function automatic logic [31:0] bit_reverse(input logic [31:0] x);
    return {x[0],  x[1],  x[2],  x[3],  x[4],  x[5],  x[6],  x[7],
            x[8],  x[9],  x[10], x[11], x[12], x[13], x[14], x[15],
            x[16], x[17], x[18], x[19], x[20], x[21], x[22], x[23],
            x[24], x[25], x[26], x[27], x[28], x[29], x[30], x[31]};
  endfunction

  logic        is_left;
  logic        fill;
  logic [31:0] s0, s1, s2, s3, s4, s5;
  logic [31:0] res;

  assign is_left = (i_mode == 2'b01);
  assign fill    = (i_mode == 2'b10) & i_data[31];

  assign s0 = is_left ? bit_reverse(i_data) : i_data;

  assign s1 = i_shamt[0] ? {{1{fill}},  s0[31:1]}  : s0;
  assign s2 = i_shamt[1] ? {{2{fill}},  s1[31:2]}  : s1;
  assign s3 = i_shamt[2] ? {{4{fill}},  s2[31:4]}  : s2;
  assign s4 = i_shamt[3] ? {{8{fill}},  s3[31:8]}  : s3;
  assign s5 = i_shamt[4] ? {{16{fill}}, s4[31:16]} : s4;

  assign res = is_left ? bit_reverse(s5) : s5;

  assign o_data = (i_mode == 2'b11) ? 32'd0 : res;

endmodule : shifter
