// Exercise 7 (extra credit): byte-addressed data memory, synchronous write and read.
//
// Same organisation, parameters, byte-enable, range and endianness rules as dmem_async.
//
// Read: when i_rden is high the addressed word is registered into o_rdata on
//       the rising edge (1 cycle latency); otherwise o_rdata holds.
//       Out-of-range reads register zero.
//
// DESIGN CHOICE (i_rden && i_wren on the same word): READ-BEFORE-WRITE.
//       o_rdata receives the OLD word; the write takes effect in the memory
//       at the same edge and is visible to later reads.
//
// o_rdata and the memory content are cleared to zero at time 0.
module dmem_sync #(
  parameter logic [31:0] START_ADDR = 32'h0000_0000,
  parameter int unsigned ADDR_WIDTH = 10
) (
  input  logic        i_clk,
  input  logic [31:0] i_addr,
  input  logic [31:0] i_wdata,
  input  logic [3:0]  i_bmsk,
  input  logic        i_rden,
  input  logic        i_wren,
  output logic [31:0] o_rdata
);

  localparam int unsigned NumWords = 2 ** (ADDR_WIDTH - 2);
  localparam int unsigned IdxW     = (ADDR_WIDTH > 2) ? (ADDR_WIDTH - 2) : 1;

  if (ADDR_WIDTH < 2) begin : g_bad_param
    $fatal(1, "dmem_sync: ADDR_WIDTH must be at least 2");
  end
  if (START_ADDR[1:0] != 2'b00) begin : g_bad_start
    $fatal(1, "dmem_sync: START_ADDR must be word-aligned");
  end

  logic [3:0][7:0] mem [NumWords];
  logic [3:0][7:0] wdata_b;

  logic [31:0]     offset;
  logic            in_range;
  logic [IdxW-1:0] word_idx;

  assign wdata_b  = i_wdata;
  assign offset   = i_addr - START_ADDR;
  assign in_range = ((offset >> ADDR_WIDTH) == 32'd0);
  assign word_idx = IdxW'(offset >> 2);

  initial begin
    o_rdata = 32'd0;
    for (int w = 0; w != NumWords; w++) begin
      mem[w] = 32'd0;
    end
  end

  always_ff @(posedge i_clk) begin
    // Non-blocking assignments: the read samples the pre-write content.
    if (i_rden) begin
      o_rdata <= in_range ? mem[word_idx] : 32'd0;
    end

    if (i_wren && in_range) begin
      for (int l = 0; l != 4; l++) begin
        if (i_bmsk[l]) begin
          mem[word_idx][l] <= wdata_b[l];
        end
      end
    end
  end

endmodule : dmem_sync
