// Self-checking testbench: comparator.
module tbench;

  logic [31:0] i_a, i_b;
  logic        i_unsigned;
  logic        o_eq, o_lt, o_gt;

  comparator dut (.*);

  int errors = 0;
  int checks = 0;

  task automatic check(input logic [31:0] a, input logic [31:0] b, input logic uns);
    logic exp_eq, exp_lt, exp_gt;

    i_a = a; i_b = b; i_unsigned = uns;
    #1;

    if (uns) begin
      exp_eq = (a == b); exp_lt = (a < b); exp_gt = (a > b);
    end else begin
      exp_eq = ($signed(a) == $signed(b));
      exp_lt = ($signed(a) <  $signed(b));
      exp_gt = ($signed(a) >  $signed(b));
    end

    checks++;
    if (o_eq !== exp_eq || o_lt !== exp_lt || o_gt !== exp_gt || (o_eq + o_lt + o_gt) != 1) begin
      errors++;
      $display("[FAIL] a=%h b=%h uns=%b | eq/lt/gt=%b%b%b exp=%b%b%b",
               a, b, uns, o_eq, o_lt, o_gt, exp_eq, exp_lt, exp_gt);
    end
  endtask

  logic [31:0] corner [9];

  initial begin
    $dumpfile("wave_comparator.vcd");
    $dumpvars(0, tbench);

    corner = '{32'h0000_0000, 32'h0000_0001, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF,
               32'h5555_5555, 32'hAAAA_AAAA, 32'h0000_FFFF, 32'hFFFF_0000};

    foreach (corner[x]) begin
      foreach (corner[y]) begin
        check(corner[x], corner[y], 1'b0);
        check(corner[x], corner[y], 1'b1);
      end
    end

    // Every single-bit position as the first difference
    for (int bit_pos = 0; bit_pos != 32; bit_pos++) begin
      for (int n = 0; n != 200; n++) begin
        logic [31:0] a, b;
        a = $urandom;
        b = a ^ (32'd1 << bit_pos);
        check(a, b, 1'b0);
        check(a, b, 1'b1);
        check(b, a, 1'b0);
        check(b, a, 1'b1);
      end
    end

    // Random
    for (int n = 0; n != 50000; n++) begin
      logic [31:0] a, b;
      a = $urandom;
      b = (n % 8 == 0) ? a : $urandom;
      check(a, b, $urandom % 2);
    end

    if (errors == 0) $display("[PASS] comparator: %0d checks", checks);
    else             $fatal(1, "[FAIL] comparator: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
