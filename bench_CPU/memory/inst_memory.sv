module inst_memory #(
  parameter int unsigned IMEM_W = 14
) (
  input  logic [IMEM_W-1:0] paddr_i ,
  output logic [31:0]       prdata_o,

  /* verilator lint_off UNUSED */
  input  logic              clk_i   ,
  input  logic              rst_ni
  /* verilator lint_on UNUSED */
);

  /* verilator lint_off UNUSED */
  logic unused;
  assign unused = |paddr_i[1:0];
  /* verilator lint_on UNUSED */


  logic [3:0][7:0] imem [2**(IMEM_W-2)-1:0];

`ifdef VERILATOR
  initial begin
    $readmemh("./memory/inst_mem.mem", imem);
  end
`else
  initial begin
    $readmemh("../memory/inst_mem.mem", imem);
  end
`endif


  always_comb begin : proc_data
    prdata_o = imem[paddr_i[IMEM_W-1:2]][3:0];
  end

endmodule : inst_memory
