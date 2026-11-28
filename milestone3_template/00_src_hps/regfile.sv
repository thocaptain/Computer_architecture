// =============================================================================
// Module Name:   regfile
// Project:       Milestone 3 - Simple MCU
// Description:   RV32I register file with x0 tied to zero and optional read bypass.
// =============================================================================

`timescale 1ns / 1ps

module regfile
    import rv32i_pkg::*;
#(
    parameter BYPASS = 1
)(
    // Clock & Reset
    input  logic                    i_clk,
    input  logic                    i_rst_n,

    // Read Addresses
    input  logic [REGIDX_WIDTH-1:0] i_rs1_addr,
    input  logic [REGIDX_WIDTH-1:0] i_rs2_addr,

    // Write Port
    input  logic [REGIDX_WIDTH-1:0] i_rd_addr,
    input  logic                    i_rd_wen,
    input  logic [31:0]             i_rd_data,

    // Read Data
    output logic [31:0]             o_rs1_data,
    output logic [31:0]             o_rs2_data
);

    // =========================================================================
    // Register Storage
    // =========================================================================
    logic [31:0] regs [0:31];

    // =========================================================================
    // Combinational Read Ports
    // =========================================================================
    generate
        if (BYPASS) begin : g_bypass
            // Forward the pending write to reads for the pipelined core.
            assign o_rs1_data = ((i_rs1_addr == i_rd_addr) & i_rd_wen & |i_rd_addr) ? i_rd_data : regs[i_rs1_addr];
            assign o_rs2_data = ((i_rs2_addr == i_rd_addr) & i_rd_wen & |i_rd_addr) ? i_rd_data : regs[i_rs2_addr];
        end else begin : g_no_bypass
            assign o_rs1_data = regs[i_rs1_addr];
            assign o_rs2_data = regs[i_rs2_addr];
        end
    endgenerate

    // =========================================================================
    // Zero Register and Synchronous Writes
    // =========================================================================
    assign regs[0] = '0;
    generate
        genvar i;
        for (i = 1; i < 32; i++) begin : g_regfile
            always_ff @(posedge i_clk or negedge i_rst_n) begin
                if (!i_rst_n) begin
                    regs[i] <= '0;
                end else begin
                    regs[i] <= (i_rd_wen & (REGIDX_WIDTH'(i) == i_rd_addr))
                        ? i_rd_data
                        : regs[i];
                end
            end
        end
    endgenerate
endmodule: regfile
