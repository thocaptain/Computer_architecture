// =============================================================================
// Module Name:   tb_device_local
// Project:       Milestone 3 - Simple MCU
// Description:   Local combinational event, print and halt device for simulation.
// =============================================================================

`timescale 1ns / 1ps

// Local simulation convention, pending the TA-supplied tb_device.sv.
// +0 EVENT (word), +4 PRINT (low byte), +8 HALT (any nonempty store).
// These offsets are not specified by the PDF and must be checked against the TA file.

module tb_device_local (
    // Clock & Reset
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [11:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    output logic [31:0] o_rdata,

    // Simulation & Debug Outputs
    output logic        o_event_valid,
    output logic        o_print_valid,
    output logic        o_halt,
    output logic [31:0] o_event_data,
    output logic [7:0]  o_print_char
);

    // =========================================================================
    // Write-Only Register Readback
    // =========================================================================
    assign o_rdata = '0;

    // =========================================================================
    // Event Store Outputs
    // =========================================================================
    assign o_event_valid = i_rstn & i_wren & (i_addr[11:2] == 10'd0) & (|i_bmsk);
    assign o_event_data  = i_wdata & {
        {8{i_bmsk[3]}},
        {8{i_bmsk[2]}},
        {8{i_bmsk[1]}},
        {8{i_bmsk[0]}}
    };

    // =========================================================================
    // Console Store Outputs
    // =========================================================================
    assign o_print_valid = i_rstn & i_wren & (i_addr[11:2] == 10'd1) & i_bmsk[0];
    assign o_print_char  = i_wdata[7:0];

    // =========================================================================
    // Program Halt Output
    // =========================================================================
    assign o_halt = i_rstn & i_wren & (i_addr[11:2] == 10'd2) & (|i_bmsk);
endmodule: tb_device_local
