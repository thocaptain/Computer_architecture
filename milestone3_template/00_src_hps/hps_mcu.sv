`timescale 1ns/1ps
`include "mcu_config.svh"
// Platform Designer component: common CPU/Avalon fabric clock, no divider.
module hps_mcu #(
    parameter PROGRAMFILE = `IMEM_FILE,
    parameter integer IMEM_ADDR_WIDTH = 12,
    parameter integer DMEM_ADDR_WIDTH = 10
)(
    input wire clk, reset_n,
    input wire [2:0] avs_address,
    input wire avs_read, avs_write,
    input wire [31:0] avs_writedata,
    input wire [3:0] avs_byteenable,
    output wire [31:0] avs_readdata,
    output wire avs_waitrequest, irq,
    input wire [17:0] i_sw,
    input wire [3:0] i_key,
    input wire [31:0] i_gpio_in,
    output wire [31:0] o_gpio_out, o_gpio_dir,
    output wire [31:0] o_ledr, o_ledg, o_ledb,
    output wire [55:0] o_hex
);
    milestone3 #(
        .PROGRAMFILE(PROGRAMFILE), .IMEM_ADDR_WIDTH(IMEM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH(DMEM_ADDR_WIDTH)
    ) mcu (
        .i_clk           (clk),
        .i_rstn          (reset_n),
        .i_sw            (i_sw),
        .i_key           (i_key),
        .i_gpio_in       (i_gpio_in),
        .o_gpio_out      (o_gpio_out),
        .o_gpio_dir      (o_gpio_dir),
        .o_ledr          (o_ledr),
        .o_ledg          (o_ledg),
        .o_ledb          (o_ledb),
        .o_hex0          (o_hex[6:0]),
        .o_hex1          (o_hex[13:7]),
        .o_hex2          (o_hex[20:14]),
        .o_hex3          (o_hex[27:21]),
        .o_hex4          (o_hex[34:28]),
        .o_hex5          (o_hex[41:35]),
        .o_hex6          (o_hex[48:42]),
        .o_hex7          (o_hex[55:49]),
        .avs_address     (avs_address),
        .avs_read        (avs_read),
        .avs_write       (avs_write),
        .avs_writedata   (avs_writedata),
        .avs_byteenable  (avs_byteenable),
        .avs_readdata    (avs_readdata),
        .avs_waitrequest (avs_waitrequest),
        .o_hps_irq       (irq),
        .o_event_valid   (),
        .o_event_data    (),
        .o_print_valid   (),
        .o_print_char    (),
        .o_halt          (),
        .o_db_valid      ()
    );
endmodule
