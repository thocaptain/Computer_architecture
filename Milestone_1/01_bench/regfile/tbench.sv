// Self-checking testbench: register file.
module tbench;

  logic        i_clk = 1'b0;
  logic        i_rstn;
  logic [4:0]  i_rs1_addr, i_rs2_addr, i_rd_addr;
  logic [31:0] i_rd_data;
  logic        i_rd_wren;
  logic [31:0] o_rs1_data, o_rs2_data;

  regfile dut (.*);

  always #500 i_clk = ~i_clk;

  logic [31:0] model [32];
  int errors = 0;
  int checks = 0;

  task automatic check_reads(input string tag);
    logic [31:0] e1, e2;
    e1 = (i_rs1_addr == 5'd0) ? 32'd0 : model[i_rs1_addr];
    e2 = (i_rs2_addr == 5'd0) ? 32'd0 : model[i_rs2_addr];
    checks++;
    if (o_rs1_data !== e1 || o_rs2_data !== e2) begin
      errors++;
      $display("[FAIL] %s t=%0t rs1[%0d]=%h exp=%h | rs2[%0d]=%h exp=%h",
               tag, $time, i_rs1_addr, o_rs1_data, e1, i_rs2_addr, o_rs2_data, e2);
    end
  endtask

  // One clock cycle: apply inputs at negedge, check async reads before the
  // write edge, update the model at the rising edge, check again after it.
  task automatic step(input logic [4:0] rs1, input logic [4:0] rs2,
                      input logic [4:0] rd, input logic [31:0] data, input logic wren);
    @(negedge i_clk);
    i_rs1_addr = rs1; i_rs2_addr = rs2; i_rd_addr = rd; i_rd_data = data; i_rd_wren = wren;
    #1;
    check_reads("pre-edge");
    @(posedge i_clk);
    if (wren && rd != 5'd0) model[rd] = data;
    #1;
    check_reads("post-edge");
  endtask

  // Assert reset away from a clock edge; every register must read zero at once.
  task automatic async_reset_test();
    @(negedge i_clk);
    #100;
    i_rstn = 1'b0;
    foreach (model[i]) model[i] = 32'd0;
    for (int a = 0; a != 32; a++) begin
      i_rs1_addr = a[4:0];
      i_rs2_addr = a[4:0];
      #1;
      check_reads("async-reset");
    end
    // Write attempt during reset must be ignored
    i_rd_addr = 5'd7; i_rd_data = 32'hDEAD_BEEF; i_rd_wren = 1'b1;
    @(posedge i_clk);
    #1;
    i_rs1_addr = 5'd7; i_rs2_addr = 5'd7;
    #1;
    check_reads("write-during-reset");
    @(negedge i_clk);
    i_rd_wren = 1'b0;
    i_rstn = 1'b1;
  endtask

  initial begin
    $dumpfile("wave_regfile.vcd");
    $dumpvars(0, tbench);

    foreach (model[i]) model[i] = 32'd0;
    i_rstn = 1'b0;
    i_rs1_addr = '0; i_rs2_addr = '0; i_rd_addr = '0; i_rd_data = '0; i_rd_wren = 1'b0;
    #100;
    check_reads("reset-init");
    i_rstn = 1'b1;

    // Directed (mirrors the example waveform)
    step(5'd5,  5'd8,  5'd5,  32'h1234_5678, 1'b1);
    step(5'd5,  5'd8,  5'd5,  32'hFFFF_FFFF, 1'b0);   // no write when wren = 0
    step(5'd0,  5'd31, 5'd31, 32'hABCD_ABCD, 1'b1);
    step(5'd31, 5'd31, 5'd0,  32'hDEAD_BEEF, 1'b1);   // write to x0 ignored
    step(5'd0,  5'd0,  5'd0,  32'hDEAD_BEEF, 1'b1);

    async_reset_test();
    step(5'd5, 5'd31, 5'd3, 32'h0BAD_CAFE, 1'b1);     // works again after reset
    step(5'd3, 5'd3,  5'd3, 32'h1111_1111, 1'b0);

    // Random, with occasional asynchronous reset
    for (int n = 0; n != 20000; n++) begin
      step($urandom, $urandom, $urandom, $urandom, $urandom % 2);
      if (n % 1000 == 999) async_reset_test();
    end

    if (errors == 0) $display("[PASS] regfile: %0d checks", checks);
    else             $fatal(1, "[FAIL] regfile: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
