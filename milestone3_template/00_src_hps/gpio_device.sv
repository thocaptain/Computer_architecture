// =============================================================================
// Module Name:   gpio_device
// Project:       Milestone 3 - Simple MCU
// Description:   Memory-mapped output, direction and input registers for 32 GPIO pins.
// =============================================================================

`timescale 1ns / 1ps

module gpio_device (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [11:0] i_addr,
    input  logic [31:0] i_wdata,

    // GPIO Signals
    input  logic [31:0] i_gpio_in,

    // Bus Interface
    input  logic [3:0]  i_bmsk,
    output logic [31:0] o_rdata,

    // GPIO Signals
    output logic [31:0] o_gpio_out,
    output logic [31:0] o_gpio_dir
);

    // =========================================================================
    // GPIO Output Register
    // =========================================================================
    mmio_register output_value (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (i_addr[11:2] == 10'd0)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (o_gpio_out)
    );

    // =========================================================================
    // GPIO Direction Register
    // =========================================================================
    mmio_register direction (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (i_addr[11:2] == 10'd1)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (o_gpio_dir)
    );

    // =========================================================================
    // Register Readback and Pin Input Selection
    // =========================================================================
    always_comb begin
        case (i_addr[11:2])
            10'd0: o_rdata = o_gpio_out;
            10'd1: o_rdata = o_gpio_dir;
            10'd2: o_rdata = (o_gpio_out & o_gpio_dir) | (i_gpio_in & ~o_gpio_dir);
            default: o_rdata = '0;
        endcase
    end
endmodule: gpio_device
