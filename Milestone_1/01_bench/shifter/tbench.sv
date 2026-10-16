// Self-checking testbench: shifter.
module tbench;

  logic [31:0] i_data;
  logic [4:0]  i_shamt;
  logic [1:0]  i_mode;
  logic [31:0] o_data;

  shifter dut (.*);

  int errors = 0;
  int checks = 0;

  task automatic check(input logic [31:0] data, input logic [4:0] shamt, input logic [1:0] mode);
    logic [31:0] exp_data;

    i_data = data; i_shamt = shamt; i_mode = mode;
    #1;

    case (mode)
      2'b00:   exp_data = data >> shamt;
      2'b01:   exp_data = data << shamt;
      2'b10:   exp_data = $signed(data) >>> shamt;
      default: exp_data = 32'd0;
    endcase

    checks++;
    if (o_data !== exp_data) begin
      errors++;
      $display("[FAIL] data=%h shamt=%0d mode=%b | out=%h exp=%h", data, shamt, mode, o_data, exp_data);
    end
  endtask

  logic [31:0] corner [6];

  initial begin
    $dumpfile("wave_shifter.vcd");
    $dumpvars(0, tbench);

    corner = '{32'h0000_0000, 32'h0000_0001, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF, 32'hA5A5_5A5A};

    // Exhaustive over shift amount and mode for corner data
    foreach (corner[x]) begin
      for (int s = 0; s != 32; s++) begin
        for (int m = 0; m != 4; m++) begin
          check(corner[x], s[4:0], m[1:0]);
        end
      end
    end

    // Random
    for (int n = 0; n != 50000; n++) begin
      check($urandom, $urandom, $urandom);
    end

    if (errors == 0) $display("[PASS] shifter: %0d checks", checks);
    else             $fatal(1, "[FAIL] shifter: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
