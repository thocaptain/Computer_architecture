module scoreboard_regfile
  import rv32i_pkg::*;
(
    input logic                    i_clk    
  , input logic                    i_rst_n  

/* verilator lint_off UNUSEDSIGNAL */
  , input logic [31:0][31:0]       drv_regs
/* verilator lint_off UNUSEDSIGNAL */
);
  // always @(posedge i_clk) begin
  //   for (int i = 0; i < 32; i++) begin
  //     $display("REGFILE_SCOREBOARD: @%05d rst=%1b, reg%2d=%8h", $time, i_rst_n, i, drv_regs[i]);
  //   end
  //     $display("--------------------------------------------------------");
  // end

  asst_regfile_x0: assert property(@(posedge i_clk) disable iff (~i_rst_n) 
    (drv_regs[0] == '0)
  );
    else #1 $error;

endmodule
