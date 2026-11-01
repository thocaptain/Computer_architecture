`timescale 1ns/1ps
module data_mem_sync #(
    parameter logic [31:0] START_ADDR = 32'h0000_2000,
    parameter int ADDR_WIDTH = 10
) (
    input  logic        i_clk,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    input  logic        i_rden,
    input  logic        i_wren,
    output logic [31:0] o_rdata
);
    localparam int WORDS = 2**(ADDR_WIDTH-2);
    localparam logic [32:0] END_ADDR = {1'b0, START_ADDR} + (33'd1 << ADDR_WIDTH);
    logic [31:0] mem [0:WORDS-1];
    logic valid_addr;
    logic [31:0] offset;
    assign valid_addr = ({1'b0, i_addr} >= {1'b0, START_ADDR}) &&
                        ({1'b0, i_addr} < END_ADDR);
    assign offset = i_addr - START_ADDR;
    // Read-before-write: both nonblocking RHS values use the old memory contents.
    always_ff @(posedge i_clk) begin
        if (i_rden) o_rdata <= valid_addr ? mem[offset / 32'd4] : 32'b0;
        if (i_wren && valid_addr) begin
            for (int lane = 0; lane < 4; lane++) begin
                if (i_bmsk[lane])
                    mem[offset / 32'd4][8*lane +: 8] <= i_wdata[8*lane +: 8];
            end
        end
    end
    initial begin
        if ((ADDR_WIDTH < 2) || (ADDR_WIDTH > 32)) $fatal(1, "ADDR_WIDTH must be 2..32");
        if (START_ADDR[1:0] != 0) $fatal(1, "START_ADDR must be word-aligned");
    end
endmodule
