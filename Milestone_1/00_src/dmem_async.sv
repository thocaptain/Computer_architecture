// Exercise 6: byte-addressed data memory, synchronous write, asynchronous read.
//
// - Valid region: START_ADDR <= i_addr < START_ADDR + 2**ADDR_WIDTH
// - Out-of-range writes are ignored, out-of-range reads return zero.
// - Little-endian, byte lane l is i_wdata[8*l +: 8] / i_bmsk[l].
// - i_addr[1:0] is ignored: the whole addressed word is read; i_bmsk selects
//   the lanes to write.
// - Memory content is cleared to zero at time 0 (simulation convenience).
module dmem_async #(
  parameter logic [31:0] START_ADDR = 32'h0000_0000,
  parameter int unsigned ADDR_WIDTH = 10
) (
  input  logic        i_clk,
  input  logic [31:0] i_addr,
  input  logic [31:0] i_wdata,
  input  logic [3:0]  i_bmsk,
  input  logic        i_wren,
  output logic [31:0] o_rdata
);

  localparam int unsigned NumWords = 2 ** (ADDR_WIDTH - 2);
  localparam int unsigned IdxW     = (ADDR_WIDTH > 2) ? (ADDR_WIDTH - 2) : 1;

  if (ADDR_WIDTH < 2) begin : g_bad_param
    $fatal(1, "dmem_async: ADDR_WIDTH must be at least 2");
  end
  if (START_ADDR[1:0] != 2'b00) begin : g_bad_start
    $fatal(1, "dmem_async: START_ADDR must be word-aligned");
  end

  logic [3:0][7:0] mem [NumWords];
  logic [3:0][7:0] wdata_b;

  logic [31:0]     offset;
  logic            in_range;
  logic [IdxW-1:0] word_idx;

  assign wdata_b  = i_wdata;
  assign offset   = i_addr - START_ADDR;
  // Any bit set above ADDR_WIDTH means out of range (also covers addr < START_ADDR by wrap-around).
  assign in_range = ((offset >> ADDR_WIDTH) == 32'd0);
  assign word_idx = IdxW'(offset >> 2);

  initial begin
    for (int w = 0; w != NumWords; w++) begin
      mem[w] = 32'd0;
    end
  end

  always_ff @(posedge i_clk) begin
    if (i_wren && in_range) begin
      for (int l = 0; l != 4; l++) begin
        if (i_bmsk[l]) begin
          mem[word_idx][l] <= wdata_b[l];
        end
      end
    end
  end

  assign o_rdata = in_range ? mem[word_idx] : 32'd0;

endmodule : dmem_async
