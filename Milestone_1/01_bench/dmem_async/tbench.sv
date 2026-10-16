// Self-checking testbench: asynchronous-read data memory.
// START_ADDR is intentionally not aligned to the memory size to exercise range checking.
module tbench;

  localparam logic [31:0] START_ADDR = 32'h1000_0100;
  localparam int unsigned ADDR_WIDTH = 10;
  localparam int unsigned SIZE       = 2 ** ADDR_WIDTH;

  logic        i_clk = 1'b0;
  logic [31:0] i_addr, i_wdata;
  logic [3:0]  i_bmsk;
  logic        i_wren;
  logic [31:0] o_rdata;

  dmem_async #(.START_ADDR(START_ADDR), .ADDR_WIDTH(ADDR_WIDTH)) dut (.*);

  always #500 i_clk = ~i_clk;

  logic [7:0] ref_mem [SIZE];
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

  task automatic check_read(input string tag);
    logic [31:0] exp_data;
    exp_data = ref_read(i_addr);
    checks++;
    if (o_rdata !== exp_data) begin
      errors++;
      $display("[FAIL] %s addr=%h | rdata=%h exp=%h", tag, i_addr, o_rdata, exp_data);
    end
  endtask

  // Inputs change at negedge. Read is checked before and after the write edge.
  task automatic step(input logic [31:0] addr, input logic [31:0] wdata,
                      input logic [3:0] bmsk, input logic wren);
    @(negedge i_clk);
    i_addr = addr; i_wdata = wdata; i_bmsk = bmsk; i_wren = wren;
    #1;
    check_read("pre-edge");
    @(posedge i_clk);
    if (wren) ref_write(addr, wdata, bmsk);
    #1;
    check_read("post-edge");
  endtask

  function automatic logic [31:0] pick_addr();
    logic [31:0] end_addr;
    end_addr = START_ADDR + SIZE;
    case ($urandom % 10)
      0:       return START_ADDR - 4 + ($urandom % 4);        // just below
      1:       return end_addr + ($urandom % 8);              // just above
      2:       return START_ADDR + ($urandom % 4);            // first word
      3:       return end_addr - 1 - ($urandom % 4);          // last word
      4:       return $urandom;                               // anywhere
      default: return START_ADDR + ($urandom % SIZE);         // in range
    endcase
  endfunction

  initial begin
    $dumpfile("wave_dmem_async.vcd");
    $dumpvars(0, tbench);

    foreach (ref_mem[i]) ref_mem[i] = 8'd0;
    i_addr = START_ADDR; i_wdata = '0; i_bmsk = '0; i_wren = 1'b0;

    // Directed (mirrors the example waveform)
    step(START_ADDR + 32'h4, 32'hAABB_CCDD, 4'b1111, 1'b1);
    step(START_ADDR + 32'h4, 32'h1234_5678, 4'b0011, 1'b1);   // -> AABB_5678
    step(START_ADDR + 32'h4, 32'hFFFF_FFFF, 4'b0000, 1'b1);   // no byte written
    step(START_ADDR + 32'h4, 32'hFFFF_FFFF, 4'b1111, 1'b0);   // wren low
    step(START_ADDR + SIZE - 4, 32'h1234_5678, 4'b1111, 1'b1);  // last word
    step(START_ADDR + SIZE,     32'h1234_5678, 4'b1111, 1'b1);  // out of range, ignored
    step(START_ADDR - 4,        32'h1234_5678, 4'b1111, 1'b1);  // out of range, ignored

    // Little-endian check: bytes of 0x1234_5678 at +0..+3 are 78 56 34 12
    step(START_ADDR, 32'h1234_5678, 4'b1111, 1'b1);
    step(START_ADDR + 32'd1, 32'h0, 4'b0000, 1'b0);
    if (ref_mem[0] !== 8'h78 || ref_mem[1] !== 8'h56 || ref_mem[2] !== 8'h34 || ref_mem[3] !== 8'h12) begin
      errors++;
      $display("[FAIL] reference model byte order");
    end

    // Random
    for (int n = 0; n != 50000; n++) begin
      step(pick_addr(), $urandom, $urandom, $urandom % 2);
    end

    if (errors == 0) $display("[PASS] dmem_async: %0d checks", checks);
    else             $fatal(1, "[FAIL] dmem_async: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
