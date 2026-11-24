// =============================================================================
// Module Name:   hex_device
// Project:       Milestone 3 - Simple MCU
// Description:   Eight memory-mapped seven-segment registers with active-low outputs.
// =============================================================================

`timescale 1ns / 1ps

module hex_device (
    // Clock & Reset
    input  logic            i_clk,
    input  logic            i_rstn,

    // Bus Interface
    input  logic            i_wren,
    input  logic [11:0]     i_addr,
    input  logic [31:0]     i_wdata,
    input  logic [3:0]      i_bmsk,
    output logic [31:0]     o_rdata,

    // Seven-Segment Outputs
    output wire  [7:0][6:0] o_hex
);

    // =========================================================================
    // Digit Register Signals
    // =========================================================================
    wire [31:0] digit [0:7];

    // =========================================================================
    // Digit Storage and Segment Outputs
    // =========================================================================
    genvar index;
    generate
    for (index = 0; index < 8; index = index + 1) begin : g_digit
        mmio_register #(
            .WRITE_MASK (32'h0000_007f)
        ) storage (
            .i_clk   (i_clk),
            .i_rstn  (i_rstn),
            .i_wren  (i_wren & (i_addr[11:2] == 10'(index))),
            .i_wdata (i_wdata),
            .i_bmsk  (i_bmsk),
            .o_value (digit[index])
        );
        assign o_hex[index] = ~digit[index][6:0];
    end
    endgenerate

    // =========================================================================
    // Register Readback
    // =========================================================================
    assign o_rdata = (i_addr[11:5] == 7'b0) ? digit[i_addr[4:2]] : 32'b0;
endmodule: hex_device
