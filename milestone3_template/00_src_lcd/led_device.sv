// =============================================================================
// Module Name:   led_device
// Project:       Milestone 3 - Simple MCU
// Description:   Independent red, green and blue LED registers with byte-mask writes.
// =============================================================================

`timescale 1ns / 1ps

module led_device (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [11:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    output logic [31:0] o_rdata,

    // LED Outputs
    output logic [31:0] o_ledr,
    output logic [31:0] o_ledg,
    output logic [31:0] o_ledb
);

    // =========================================================================
    // Register Address Selection
    // =========================================================================
    wire [9:0] word_offset = i_addr[11:2];

    // =========================================================================
    // LED Register Storage
    // =========================================================================
    mmio_register #(
        .WRITE_MASK (32'h0003_ffff)
    ) red (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (word_offset == 10'd0)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (o_ledr)
    );

    mmio_register #(
        .WRITE_MASK (32'h0000_00ff)
    ) green (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (word_offset == 10'd1)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (o_ledg)
    );

    mmio_register #(
        .WRITE_MASK (32'h0000_0001)
    ) blue (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (word_offset == 10'd2)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (o_ledb)
    );

    // =========================================================================
    // Register Readback
    // =========================================================================
    always_comb begin
        case (word_offset)
            10'd0: o_rdata = o_ledr;
            10'd1: o_rdata = o_ledg;
            10'd2: o_rdata = o_ledb;
            default: o_rdata = '0;
        endcase
    end
endmodule: led_device
