// =============================================================================
// Module Name:   simple_bus
// Project:       Milestone 3 - Simple MCU
// Description:   Address decoding and read/write routing for the MCU memory map.
// =============================================================================

`timescale 1ns / 1ps

module simple_bus (
    // Bus Interface
    input  logic [31:0]      i_addr,
    input  logic             i_wren,

    // Register File Access
    input  logic [7:0][31:0] i_rdata,

    // Control Signals
    output logic [7:0]       o_wren,

    // Bus Interface
    output logic [31:0]      o_rdata
);

    // =========================================================================
    // Device Selection Signals
    // =========================================================================
    logic [7:0] select_device;

    // =========================================================================
    // Address Decode and Bus Routing
    // =========================================================================
    always_comb begin
        select_device = '0;
        if (i_addr[31:14] == 18'h21000) begin
            select_device[0] = 1'b1;
        end

        case (i_addr[31:12])
            20'h40000: select_device[1] = 1'b1;
            20'h40001: select_device[2] = 1'b1;
            20'h40002: select_device[3] = 1'b1;
            20'h40003: select_device[4] = 1'b1;
            20'h40004: select_device[5] = 1'b1;
            20'h40005: select_device[6] = 1'b1;
            20'h4000f: select_device[7] = 1'b1;
            default: begin
            end
        endcase

        o_wren  = select_device & {8{i_wren}};
        o_rdata = (i_rdata[0] & {32{select_device[0]}}) |
                  (i_rdata[1] & {32{select_device[1]}}) |
                  (i_rdata[2] & {32{select_device[2]}}) |
                  (i_rdata[3] & {32{select_device[3]}}) |
                  (i_rdata[4] & {32{select_device[4]}}) |
                  (i_rdata[5] & {32{select_device[5]}}) |
                  (i_rdata[6] & {32{select_device[6]}}) |
                  (i_rdata[7] & {32{select_device[7]}});
    end
endmodule: simple_bus
