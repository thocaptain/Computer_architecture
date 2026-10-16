// Self-checking testbench: adder.
module tbench;

  logic [31:0] i_a, i_b;
  logic        i_sub, i_unsigned;
  logic [31:0] o_sum;
  logic        o_cout;

  adder dut (.*);

  int errors = 0;
  int checks = 0;

  task automatic check(input logic [31:0] a, input logic [31:0] b,
                       input logic sub, input logic uns);
    logic [32:0] ref33;
    logic [31:0] exp_sum;
    logic        exp_cout;

    i_a = a; i_b = b; i_sub = sub; i_unsigned = uns;
    #1;

    ref33   = sub ? ({1'b0, a} - {1'b0, b}) : ({1'b0, a} + {1'b0, b});
    exp_sum = ref33[31:0];
    if (uns)      exp_cout = ref33[32];                                    // carry / borrow
    else if (sub) exp_cout = (a[31] != b[31]) && (exp_sum[31] != a[31]);  // signed overflow
    else          exp_cout = (a[31] == b[31]) && (exp_sum[31] != a[31]);

    checks++;
    if (o_sum !== exp_sum || o_cout !== exp_cout) begin
      errors++;
      $display("[FAIL] a=%h b=%h sub=%b uns=%b | sum=%h exp=%h | cout=%b exp=%b",
               a, b, sub, uns, o_sum, exp_sum, o_cout, exp_cout);
    end
  endtask

  logic [31:0] corner [9];

  initial begin
    $dumpfile("wave_adder.vcd");
    $dumpvars(0, tbench);

    corner = '{32'h0000_0000, 32'h0000_0001, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF,
               32'h5555_5555, 32'hAAAA_AAAA, 32'h0000_FFFF, 32'hFFFF_0000};

    // Directed corner cases, all mode combinations
    foreach (corner[x]) begin
      foreach (corner[y]) begin
        for (int m = 0; m != 4; m++) begin
          check(corner[x], corner[y], m[1], m[0]);
        end
      end
    end

    // Random and near-equal operands
    for (int n = 0; n != 50000; n++) begin
      logic [31:0] a, b;
      a = $urandom;
      b = (n % 4 == 0) ? a : (n % 4 == 1) ? (a ^ (32'd1 << ($urandom % 32))) : $urandom;
      check(a, b, $urandom % 2, $urandom % 2);
    end

    if (errors == 0) $display("[PASS] adder: %0d checks", checks);
    else             $fatal(1, "[FAIL] adder: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
