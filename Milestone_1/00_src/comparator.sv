// Exercise 2: 32-bit magnitude comparator.
//
// Architecture: leading-difference detector.
//   1. Signed compare is turned into unsigned compare by flipping both MSBs.
//   2. diff = a ^ b; a prefix-OR (log depth) finds the most significant
//      differing bit and a one-hot mask isolates it.
//   3. At that bit, a = 1 means a > b and b = 1 means a < b.
// No relational operator is used.
module comparator (
  input  logic [31:0] i_a,
  input  logic [31:0] i_b,
  input  logic        i_unsigned,
  output logic        o_eq,
  output logic        o_lt,
  output logic        o_gt
);

  logic [31:0] a_c, b_c;
  logic [31:0] diff;
  logic [31:0] m1, m2, m3, m4, m5;
  logic [31:0] first_diff;

  assign a_c = {i_a[31] ^ ~i_unsigned, i_a[30:0]};
  assign b_c = {i_b[31] ^ ~i_unsigned, i_b[30:0]};

  assign diff = a_c ^ b_c;

  // m5[i] = |diff[31:i]
  assign m1 = diff | {1'b0,  diff[31:1]};
  assign m2 = m1   | {2'b0,  m1[31:2]};
  assign m3 = m2   | {4'b0,  m2[31:4]};
  assign m4 = m3   | {8'b0,  m3[31:8]};
  assign m5 = m4   | {16'b0, m4[31:16]};

  // One-hot at the most significant differing bit (all zero when a == b).
  assign first_diff = m5 & ~{1'b0, m5[31:1]};

  assign o_eq = ~m5[0];
  assign o_gt = |(first_diff & a_c);
  assign o_lt = |(first_diff & b_c);

endmodule : comparator
