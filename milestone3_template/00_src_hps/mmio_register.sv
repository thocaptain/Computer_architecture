// =============================================================================
// Module Name:   mmio_register
// Project:       Milestone 3 - Simple MCU
// Description:   Byte-enabled 32-bit register with reserved-bit masking and reset.
// =============================================================================

`timescale 1ns / 1ps

module mmio_register #(
    parameter logic [31:0] WRITE_MASK = 32'hffff_ffff
)(
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,

    // Register Value
    output logic [31:0] o_value
);

    // =========================================================================
    // Byte-Enabled Register Storage
    // =========================================================================
    genvar lane;
    generate
    for (lane = 0; lane < 4; lane = lane + 1) begin : g_byte
        always_ff @(posedge i_clk or negedge i_rstn) begin
            if (!i_rstn) begin
                o_value[8*lane +: 8] <= '0;
            end else if (i_wren & i_bmsk[lane]) begin
                o_value[8*lane +: 8] <= i_wdata[8*lane +: 8] & WRITE_MASK[8*lane +: 8];
            end
        end
    end
    endgenerate
endmodule: mmio_register
