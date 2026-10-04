module data_memory #(
  parameter int unsigned DMEM_W = 12
) (
  // APB Protocol
  input  logic [DMEM_W-1:0] paddr_i  ,
  input  logic              penable_i,
  input  logic              psel_i   ,
  input  logic              pwrite_i ,
  input  logic [31:0]       pwdata_i ,
  input  logic [3:0]        pstrb_i  ,
  output logic [31:0]       prdata_o ,
  output logic              pready_o ,

  /* verilator lint_off UNUSED */
  input  logic              clk_i   ,
  input  logic              rst_ni
  /* verilator lint_on UNUSED */
);

  /* verilator lint_off UNUSED */
  logic unused;
  assign unused = |paddr_i[1:0];
  /* verilator lint_on UNUSED */

  logic [3:0][7:0] dmem [0:2**(DMEM_W-2)-1];
  // initial begin
  //   $readmemh("./memory/inst_mem.mem", mem);
  // end
  initial begin
    for (int i=0; i < 2**(DMEM_W-2); i++) begin
      dmem[i] = 0;
    end
  end

  // Read - Write
  always_ff @(posedge clk_i) begin : proc_data
    if (psel_i && penable_i && pwrite_i) begin
    // with 32 bit data, bitmask has 3 bits
    // in order to decide write 1 byte, 2 bytes or 4 bytes
      if (pstrb_i[0]) begin
        dmem[paddr_i[DMEM_W-1:2]][0] <= pwdata_i[ 7: 0];
      end
      if (pstrb_i[1]) begin
        dmem[paddr_i[DMEM_W-1:2]][1] <= pwdata_i[15: 8];
      end
      if (pstrb_i[2]) begin
        dmem[paddr_i[DMEM_W-1:2]][2] <= pwdata_i[23:16];
      end
      if (pstrb_i[3]) begin
        dmem[paddr_i[DMEM_W-1:2]][3] <= pwdata_i[31:24];
      end
    end
    //$writememh("./memory/data_mem.mem", dmem);
  end

  assign prdata_o = dmem[paddr_i[DMEM_W-1:2]];
  assign pready_o = 1'b1;

endmodule : data_memory
