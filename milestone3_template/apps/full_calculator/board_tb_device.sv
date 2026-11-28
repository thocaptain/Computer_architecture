// FPGA-only replacement for the absent TA simulation device in this checkout.
// Add this file only if the project does not already provide module tb_device.
// No calculator behavior is implemented in this module.
`timescale 1ns/1ps
module tb_device (
    input wire [11:0] i_addr,
    input wire [31:0] i_wdata,
    input wire i_wren,
    output wire o_event_valid,
    output wire [31:0] o_event_data,
    output wire o_print_valid,
    output wire [7:0] o_print_char,
    output wire o_halt
);
    assign o_event_valid = 1'b0;
    assign o_event_data = 32'b0;
    assign o_print_valid = 1'b0;
    assign o_print_char = 8'b0;
    assign o_halt = 1'b0;
endmodule
