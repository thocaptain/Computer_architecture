// Self-checking testbench: ALU.
module tbench;
  import alu_pkg::*;

  logic [31:0] i_op_a, i_op_b;
  alu_op_e     i_alu_op;
  logic [31:0] o_alu_data;

  alu dut (.*);

  int errors = 0;
  int checks = 0;

  function automatic logic [31:0] ref_alu(input logic [31:0] a, input logic [31:0] b, input logic [3:0] op);
    case (op)
      4'(ALU_ADD):  return a + b;
      4'(ALU_SUB):  return a - b;
      4'(ALU_SLT):  return {31'd0, ($signed(a) < $signed(b))};
      4'(ALU_SLTU): return {31'd0, (a < b)};
      4'(ALU_XOR):  return a ^ b;
      4'(ALU_OR):   return a | b;
      4'(ALU_AND):  return a & b;
      4'(ALU_SLL):  return a << b[4:0];
      4'(ALU_SRL):  return a >> b[4:0];
      4'(ALU_SRA):  return $signed(a) >>> b[4:0];
      default:      return 32'd0;
    endcase
  endfunction

  task automatic check(input logic [31:0] a, input logic [31:0] b, input logic [3:0] op);
    logic [31:0] exp_data;

    i_op_a = a; i_op_b = b; i_alu_op = alu_op_e'(op);
    #1;
    exp_data = ref_alu(a, b, op);

    checks++;
    if (o_alu_data !== exp_data) begin
      errors++;
      $display("[FAIL] op=%0d a=%h b=%h | out=%h exp=%h", op, a, b, o_alu_data, exp_data);
    end
  endtask

  logic [31:0] corner [8];

  initial begin
    $dumpfile("wave_alu.vcd");
    $dumpvars(0, tbench);

    corner = '{32'h0000_0000, 32'h0000_0001, 32'hFFFF_FFFF, 32'h8000_0000,
               32'h7FFF_FFFF, 32'h5555_5555, 32'hAAAA_AAAA, 32'h0000_001F};

    // All 16 encodings (10 valid + 6 reserved) on corner operands
    foreach (corner[x]) begin
      foreach (corner[y]) begin
        for (int op = 0; op != 16; op++) begin
          check(corner[x], corner[y], op[3:0]);
        end
      end
    end

    // Random
    for (int n = 0; n != 50000; n++) begin
      logic [31:0] a, b;
      a = $urandom;
      b = (n % 8 == 0) ? a : $urandom;
      check(a, b, $urandom % 16);
    end

    if (errors == 0) $display("[PASS] alu: %0d checks", checks);
    else             $fatal(1, "[FAIL] alu: %0d errors in %0d checks", errors, checks);
    $finish;
  end

endmodule : tbench
