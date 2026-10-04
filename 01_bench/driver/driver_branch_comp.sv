module driver_branch_comp (
    input logic i_clk,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data,
    output logic o_br_un
);
  always_ff @(posedge i_clk) begin
    case ($urandom % 4)
      0: begin o_rs1_data <= 32'hffff_ffff; o_rs2_data <= 32'h0000_0001; end
      1: begin o_rs1_data <= 32'h0000_0001; o_rs2_data <= 32'hffff_ffff; end
      2: begin o_rs1_data <= 32'h1234_5678; o_rs2_data <= 32'h1234_5678; end
      default: begin o_rs1_data <= $urandom; o_rs2_data <= $urandom; end
    endcase
    o_br_un <= (($urandom % 2) != 0);
  end
endmodule
