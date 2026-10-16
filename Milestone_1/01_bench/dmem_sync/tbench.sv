// Self-checking testbench: synchronous-read data memory (read-before-write).
module tbench;

  localparam logic [31:0] START_ADDR = 32'h1000_0100;
  localparam int unsigned ADDR_WIDTH = 10;
  localparam int unsigned SIZE       = 2 ** ADDR_WIDTH;

  logic        i_clk = 1'b0;
  logic [31:0] i_addr, i_wdata;
  logic [3:0]  i_bmsk;
  logic        i_rden, i_wren;
  logic [31:0] o_rdata;

  dmem_sync #(.START_ADDR(START_ADDR), .ADDR_WIDTH(ADDR_WIDTH)) dut (.*);

  always #500 i_clk = ~i_clk;

  logic [7:0]  ref_mem [SIZE];
  logic [31:0] ref_rdata = 32'd0;
  int errors = 0;
  int checks = 0;

  function automatic bit in_range(input logic [31:0] addr);
    longint unsigned a, s;
    a = {32'd0, addr};
    s = {32'd0, START_ADDR};
    return (a >= s) && (a < (s + longint'(SIZE)));
  endfunction

  function automatic logic [31:0] ref_read(input logic [31:0] addr);
    int unsigned base;
    if (!in_range(addr)) return 32'd0;
    base = (addr - START_ADDR) & 32'hFFFF_FFFC;
    return {ref_mem[base + 3], ref_mem[base + 2], ref_mem[base + 1], ref_mem[base]};
  endfunction

  task automatic ref_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] bmsk);
    int unsigned base;
    if (!in_range(addr)) return;
    base = (addr - START_ADDR) & 32'hFFFF_FFFC;
    for (int l = 0; l != 4; l++) begin
      if (bmsk[l]) ref_mem[base + l] = data[8*l +: 8];
    end
  endtask

  // Inputs change at negedge. At the rising edge the read samples the old
  // content (read-before-write), then the write is applied.
  task automatic step(input logic [31:0] addr, input logic [31:0] wdata, input logic [3:0] bmsk,
                      input logic rden, input logic wren);
    @(negedge i_clk);
    i_addr = addr; i_wdata = wdata; i_bmsk = bmsk; i_rden = rden; i_wren = wren;
    #1;
    // No read data change before the edge
    checks++;
    if (o_rdata !== ref_rdata) begin
      errors++;
      $display("[FAIL] pre-edge addr=%h | rdata=%h exp=%h", addr, o_rdata, ref_rdata);
    end
    @(posedge i_clk);
    if (rden) ref_rdata = ref_read(addr);
    if (wren) ref_write(addr, wdata, bmsk);
    #1;
    checks++;
    if (o_rdata !== ref_rdata) begin
      errors++;
      $display("[FAIL] post-edge addr=%h rden=%b wren=%b | rdata=%h exp=%h", addr, rden, wren, o_rdata, ref_rdata);
    end
  endtask

  function automatic logic [31:0] pick_addr();
    logic [31:0] end_addr;
    end_addr = START_ADDR + SIZE;
    case ($urandom % 10)
      0:       return START_ADDR - 4 + ($urandom % 4);
      1:       return end_addr + ($urandom % 8);
      2:       return START_ADDR + ($urandom % 4);
      3:       return end_addr - 1 - ($urandom % 4);
      4:       return $urandom;
      default: return START_ADDR + ($urandom % SIZE);
    endcase
  endfunction

  initial begin
    $dumpfile("wave_dmem_sync.vcd");
    $dumpvars(0, tbench);

    foreach (ref_mem[i]) ref_mem[i] = 8'd0;
    i_addr = START_ADDR; i_wdata = '0; i_bmsk = '0; i_rden = 1'b0; i_wren = 1'b0;

    // Directed (mirrors the example waveform)
    step(START_ADDR + 32'h4, 32'hAABB_CCDD, 4'b1111, 1'b0, 1'b1);  // write
    step(START_ADDR + 32'h4, 32'h0,         4'b0000, 1'b1, 1'b0);  // read -> AABB_CCDD
    step(START_ADDR + 32'h4, 32'h1234_5678, 4'b0011, 1'b0, 1'b1);  // write low half
    step(START_ADDR + 32'h4, 32'h0,         4'b0000, 1'b0, 1'b0);  // rdata holds
    step(START_ADDR + 32'h4, 32'h0,         4'b0000, 1'b1, 1'b0);  // read -> AABB_5678
    step(START_ADDR + 32'h4, 32'h1111_1111, 4'b1111, 1'b1, 1'b1);  // rden+wren: old data
    step(START_ADDR + 32'h4, 32'h0,         4'b0000, 1'b1, 1'b0);  // new data
    step(START_ADDR + SIZE,  32'h0,         4'b0000, 1'b1, 1'b0);  // out of range -> 0
    step(START_ADDR + 32'h8, 32'h0,         4'b0000, 1'b0, 1'b0);  // rdata holds

    // Random
    for (int n = 0; n != 50000; n++) begin
      step(pick_addr(), $urandom, $urandom, $urandom % 2, $urandom % 2);
    end

    if (errors == 0) $display("[PASS] dmem_sync: %0d checks", checks);
    else             $fatal(1, "[FAIL] dmem_sync: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
