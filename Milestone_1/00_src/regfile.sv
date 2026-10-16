// Exercise 5: Register file, 32 x 32-bit.
// Two asynchronous read ports, one synchronous write port,
// asynchronous active-low reset, x0 hard-wired to zero.
module regfile (
  input  logic        i_clk,
  input  logic        i_rstn,
  input  logic [4:0]  i_rs1_addr,
  input  logic [4:0]  i_rs2_addr,
  input  logic [4:0]  i_rd_addr,
  input  logic [31:0] i_rd_data,
  input  logic        i_rd_wren,
  output logic [31:0] o_rs1_data,
  output logic [31:0] o_rs2_data
);

  logic [31:0] regs [32];

  always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn) begin
      for (int i = 0; i != 32; i++) begin
        regs[i] <= 32'd0;
      end
    end else if (i_rd_wren && (i_rd_addr != 5'd0)) begin
      regs[i_rd_addr] <= i_rd_data;
    end
  end

  assign o_rs1_data = (i_rs1_addr == 5'd0) ? 32'd0 : regs[i_rs1_addr];
  assign o_rs2_data = (i_rs2_addr == 5'd0) ? 32'd0 : regs[i_rs2_addr];

endmodule : regfile
