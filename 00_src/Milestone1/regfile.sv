`timescale 1ns/1ps
module regfile (
    input  logic        i_clk,
    input  logic        i_rstn,
    input  logic [4:0]  i_rs1_addr,
    input  logic [4:0]  i_rs2_addr,
    input  logic [4:0]  i_rd_addr,
    input  logic [31:0] i_rd_data,
    input  logic        i_rd_wren,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data
);
    logic [31:0] regs [1:31];
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            for (int idx = 1; idx < 32; idx++) regs[idx] <= 32'b0;
        end else if (i_rd_wren && (i_rd_addr != 5'b0)) begin
            regs[i_rd_addr] <= i_rd_data;
        end
    end
    assign o_rs1_data = (i_rs1_addr == 5'b0) ? 32'b0 : regs[i_rs1_addr];
    assign o_rs2_data = (i_rs2_addr == 5'b0) ? 32'b0 : regs[i_rs2_addr];
endmodule
