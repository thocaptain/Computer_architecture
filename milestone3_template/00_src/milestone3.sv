// =============================================================================
// Module Name:   milestone3
// Project:       Milestone 3 - Simple MCU
// Description:   Single-cycle RV32I MCU integrating memories, a bus and I/O devices.
// =============================================================================

`timescale 1ns / 1ps
`include "mcu_config.svh"

module milestone3 #(
    parameter PROGRAMFILE                  = `IMEM_FILE,
    parameter int unsigned IMEM_ADDR_WIDTH = `IMEM_ADDR_WIDTH,
    parameter int unsigned DMEM_ADDR_WIDTH = `DMEM_ADDR_WIDTH
)(
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Switches & Buttons
    input  logic [17:0] i_sw,
    input  logic [3:0]  i_key,

    // LED Outputs
    output wire  [31:0] o_ledr,
    output wire  [31:0] o_ledg,
    output wire  [31:0] o_ledb,

    // Seven-Segment Outputs
    output wire  [6:0]  o_hex0,
    output wire  [6:0]  o_hex1,
    output wire  [6:0]  o_hex2,
    output wire  [6:0]  o_hex3,
    output wire  [6:0]  o_hex4,
    output wire  [6:0]  o_hex5,
    output wire  [6:0]  o_hex6,
    output wire  [6:0]  o_hex7,

    // GPIO Signals
    input  logic [31:0] i_gpio_in,
    output wire  [31:0] o_gpio_out,
    output wire  [31:0] o_gpio_dir,

`ifdef DMEM_USE_SRAM
    // External 16-Bit SRAM Pins
    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_CE_N,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_UB_N,
`endif

    // Simulation & Debug Outputs
    output wire         o_event_valid,
    output wire  [31:0] o_event_data,
    output wire         o_print_valid,
    output wire  [7:0]  o_print_char,
    output wire         o_halt,
    output wire         o_db_valid
);

    // =========================================================================
    // Internal Bus and Device Signals
    // =========================================================================
    wire [31:0]      imem_addr;
    wire [31:0]      instruction;
    wire [31:0]      bus_addr;
    wire [31:0]      bus_wdata;
    wire [31:0]      bus_rdata;
    wire [3:0]       bus_bmsk;
    wire             bus_wren;
`ifdef DMEM_USE_SRAM
    wire             dmem_valid;
    wire             dmem_ready;
`endif
    wire [7:0]       device_wren;
    wire [7:0][31:0] device_rdata;
    wire [7:0][6:0]  hex_pins;

    // =========================================================================
    // Seven-Segment Pin Mapping
    // =========================================================================
    assign {o_hex7, o_hex6, o_hex5, o_hex4, o_hex3, o_hex2, o_hex1, o_hex0} =
        hex_pins;

    // =========================================================================
    // Single-Cycle Processor
    // =========================================================================
    singlecycle cpu (
        .i_clk        (i_clk),
        .i_rstn       (i_rstn),
        .o_imem_addr  (imem_addr),
        .i_imem_rdata (instruction),
`ifdef DMEM_USE_SRAM
        .i_dmem_ready (dmem_ready),
        .o_dmem_valid (dmem_valid),
`endif
        .o_dmem_addr  (bus_addr),
        .o_dmem_wdata (bus_wdata),
        .o_dmem_bmsk  (bus_bmsk),
        .o_dmem_wren  (bus_wren),
        .i_dmem_rdata (bus_rdata),
        .o_db_valid   (o_db_valid)
    );

    // =========================================================================
    // Instruction Memory
    // =========================================================================
    imem #(
        .ADDR_WIDTH  (IMEM_ADDR_WIDTH),
        .PROGRAMFILE (PROGRAMFILE)
    ) imem (
        .i_clk  (i_clk),
        .i_addr (imem_addr),
        .o_data (instruction)
    );

    // =========================================================================
    // Single-Master Bus
    // =========================================================================
    simple_bus bus (
        .i_addr  (bus_addr),
        .i_wren  (bus_wren),
        .i_rdata (device_rdata),
        .o_wren  (device_wren),
        .o_rdata (bus_rdata)
    );

    // =========================================================================
    // Data Memory
    // =========================================================================
    dmem #(
        .ADDR_WIDTH (DMEM_ADDR_WIDTH)
    ) dmem (
        .i_clk   (i_clk),
`ifdef DMEM_USE_SRAM
        .i_rstn    (i_rstn),
        .i_valid   (dmem_valid),
        .o_ready   (dmem_ready),
        .SRAM_ADDR (SRAM_ADDR),
        .SRAM_DQ   (SRAM_DQ),
        .SRAM_CE_N (SRAM_CE_N),
        .SRAM_WE_N (SRAM_WE_N),
        .SRAM_OE_N (SRAM_OE_N),
        .SRAM_LB_N (SRAM_LB_N),
        .SRAM_UB_N (SRAM_UB_N),
`endif
        .i_addr  (bus_addr),
        .i_wdata (bus_wdata),
        .i_bmsk  (bus_bmsk),
        .i_wren  (device_wren[0]),
        .o_rdata (device_rdata[0])
    );

    // =========================================================================
    // LED and Seven-Segment Devices
    // =========================================================================
    led_device led (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_addr  (bus_addr[11:0]),
        .i_wdata (bus_wdata),
        .i_bmsk  (bus_bmsk),
        .i_wren  (device_wren[1]),
        .o_rdata (device_rdata[1]),
        .o_ledr  (o_ledr),
        .o_ledg  (o_ledg),
        .o_ledb  (o_ledb)
    );

    hex_device hex_display (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_addr  (bus_addr[11:0]),
        .i_wdata (bus_wdata),
        .i_bmsk  (bus_bmsk),
        .i_wren  (device_wren[2]),
        .o_rdata (device_rdata[2]),
        .o_hex   (hex_pins)
    );

    // =========================================================================
    // Switch and Button Inputs
    // =========================================================================
    input_device switches (
        .i_addr  (bus_addr[11:0]),
        .i_value ({14'b0, i_sw}),
        .o_rdata (device_rdata[3])
    );

    input_device keys (
        .i_addr  (bus_addr[11:0]),
        .i_value ({28'b0, ~i_key}),
        .o_rdata (device_rdata[4])
    );

    // =========================================================================
    // Timer Device
    // =========================================================================
    timer_device timer (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_addr  (bus_addr[11:0]),
        .i_wdata (bus_wdata),
        .i_bmsk  (bus_bmsk),
        .i_wren  (device_wren[5]),
        .o_rdata (device_rdata[5])
    );

    // =========================================================================
    // GPIO Device
    // =========================================================================
    gpio_device gpio (
        .i_clk      (i_clk),
        .i_rstn     (i_rstn),
        .i_addr     (bus_addr[11:0]),
        .i_wdata    (bus_wdata),
        .i_bmsk     (bus_bmsk),
        .i_wren     (device_wren[6]),
        .o_rdata    (device_rdata[6]),
        .i_gpio_in  (i_gpio_in),
        .o_gpio_out (o_gpio_out),
        .o_gpio_dir (o_gpio_dir)
    );

    // =========================================================================
    // Simulation Testbench Device
    // =========================================================================
    // Enable with +define+SIM_ONLY when compiling simulation sources.
    // The testbench device is write-only and has no read-data port.
    assign device_rdata[7] = 32'b0;

`ifdef SIM_ONLY
    tb_device simulation_device (
        .i_addr        (bus_addr[11:0]),
        .i_wdata       (bus_wdata),
        .i_wren        (device_wren[7]),
        .o_event_valid (o_event_valid),
        .o_event_data  (o_event_data),
        .o_print_valid (o_print_valid),
        .o_print_char  (o_print_char),
        .o_halt        (o_halt)
    );
`else
    assign o_event_valid = 1'b0;
    assign o_event_data  = 32'b0;
    assign o_print_valid = 1'b0;
    assign o_print_char = 8'b0;
    assign o_halt = 1'b0;
`endif
endmodule: milestone3
