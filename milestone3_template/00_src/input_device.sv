// =============================================================================
// Module Name:   input_device
// Project:       Milestone 3 - Simple MCU
// Description:   Read-only memory-mapped register for switch or button input values.
// =============================================================================

`timescale 1ns / 1ps

module input_device (
    // Bus Interface
    input  logic [11:0] i_addr,

    // Register Value
    input  logic [31:0] i_value,

    // Bus Interface
    output logic [31:0] o_rdata
);

    // =========================================================================
    // Input Register Readback
    // =========================================================================
    assign o_rdata = (i_addr[11:2] == 10'b0) ? i_value : 32'b0;
endmodule: input_device
