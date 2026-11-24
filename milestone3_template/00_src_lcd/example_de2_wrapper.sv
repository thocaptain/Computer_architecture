// =============================================================================
// Module Name:   example_de2_wrapper
// Project:       Milestone 3 - Simple MCU
// Description:   DE2 board wrapper with clock division, synchronized reset and
//                inputs, direct LED/HEX outputs and 32 bidirectional GPIO pins.
// =============================================================================

`timescale 1ns / 1ps
`include "mcu_config.svh"

module example_de2_wrapper #(
    parameter PROGRAMFILE                  = `IMEM_FILE,
    parameter int unsigned CLOCK_DIV_LOG2  = 1,
    parameter int unsigned IMEM_ADDR_WIDTH = 12,
`ifdef DMEM_USE_SRAM
    parameter int unsigned DMEM_ADDR_WIDTH = 14
`else
    parameter int unsigned DMEM_ADDR_WIDTH = 10
`endif
)(
    // Board Clock & Active-Low Push Buttons
    input  logic        CLOCK_50,
    input  logic [3:0]  KEY,

    // Slide Switches
    input  logic [17:0] SW,

    // LED Outputs
    output wire  [17:0] LEDR,
    output wire  [7:0]  LEDG,

    // Active-Low Seven-Segment Outputs
    output wire  [6:0]  HEX0,
    output wire  [6:0]  HEX1,
    output wire  [6:0]  HEX2,
    output wire  [6:0]  HEX3,
    output wire  [6:0]  HEX4,
    output wire  [6:0]  HEX5,
    output wire  [6:0]  HEX6,
    output wire  [6:0]  HEX7,

    // DE2 character LCD, write-only 8-bit interface.
    output wire [7:0] LCD_DATA,
    output wire LCD_RS, LCD_RW, LCD_EN, LCD_ON, LCD_BLON,

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

    // Bidirectional GPIO Header Pins
    inout  wire  [31:0] GPIO
);

    // =========================================================================
    // Board Build Configuration
    // =========================================================================
    // Clock frequency is 50 MHz / 2**CLOCK_DIV_LOG2. A value of 0 bypasses
    // the divider. The default is 25 MHz with 4 KiB IMEM.
    // Flop DMEM defaults to 1 KiB. External SRAM DMEM defaults to 16 KiB.
    // PROGRAMFILE selects the application image in 32-bit-word hex format.
    // Define the input and generated clocks in the board project's SDC file,
    // and check setup/hold timing at the actual MCU clock after compilation.
    // KEY[0] is reserved for reset. Software receives KEY[3:1] in bits [3:1],
    // with bit 0 tied inactive. Button debouncing can be handled in software.
    // Use the pin assignments for the actual board and GPIO header in use.

    // =========================================================================
    // Internal Clock, Reset and Device Signals
    // =========================================================================
    wire         mcu_clk;
    wire         mcu_rstn;
    wire [31:0]  ledr;
    wire [31:0]  ledg;
    wire [31:0]  gpio_out;
    wire [31:0]  gpio_dir;

    (* async_reg = "true" *) logic [1:0]  reset_sync;
    (* async_reg = "true" *) logic [17:0] sw_meta;
    (* async_reg = "true" *) logic [17:0] sw_sync;
    (* async_reg = "true" *) logic [2:0]  key_meta;
    (* async_reg = "true" *) logic [2:0]  key_sync;
    (* async_reg = "true" *) logic [31:0] gpio_meta;
    (* async_reg = "true" *) logic [31:0] gpio_sync;

    // =========================================================================
    // Optional Clock Divider
    // =========================================================================
    generate
        if (CLOCK_DIV_LOG2 == 0) begin : g_board_clock
            assign mcu_clk = CLOCK_50;
        end else begin : g_divided_clock
            logic [CLOCK_DIV_LOG2-1:0] clock_count;
            wire  [CLOCK_DIV_LOG2-1:0] next_clock_count;
            wire                       divider_rstn;
            (* async_reg = "true" *) logic [1:0] divider_reset_sync;

            // Release the divider's reset in the board-clock domain.
            always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
                if (!KEY[0]) begin
                    divider_reset_sync <= 2'b00;
                end else begin
                    divider_reset_sync <= {divider_reset_sync[0], 1'b1};
                end
            end

            assign divider_rstn = divider_reset_sync[1];

            bit_adder #(
                .WIDTH (CLOCK_DIV_LOG2)
            ) divider_increment (
                .i_a     (clock_count),
                .i_b     (CLOCK_DIV_LOG2'(1)),
                .i_carry (1'b0),
                .o_sum   (next_clock_count),
                .o_carry ()
            );

            always_ff @(posedge CLOCK_50 or negedge divider_rstn) begin
                if (!divider_rstn) begin
                    clock_count <= '0;
                end else begin
                    clock_count <= next_clock_count;
                end
            end

            assign mcu_clk = clock_count[CLOCK_DIV_LOG2-1];
        end
    endgenerate

    // =========================================================================
    // Asynchronous Reset Assertion and Synchronous Release
    // =========================================================================
    always_ff @(posedge mcu_clk or negedge KEY[0]) begin
        if (!KEY[0]) begin
            reset_sync <= 2'b00;
        end else begin
            reset_sync <= {reset_sync[0], 1'b1};
        end
    end

    assign mcu_rstn = reset_sync[1];

    // =========================================================================
    // Two-Stage Input Synchronizers
    // =========================================================================
    always_ff @(posedge mcu_clk or negedge mcu_rstn) begin
        if (!mcu_rstn) begin
            sw_meta   <= '0;
            sw_sync   <= '0;
            key_meta  <= '1;
            key_sync  <= '1;
            gpio_meta <= '0;
            gpio_sync <= '0;
        end else begin
            sw_meta   <= SW;
            sw_sync   <= sw_meta;
            key_meta  <= KEY[3:1];
            key_sync  <= key_meta;
            gpio_meta <= GPIO;
            gpio_sync <= gpio_meta;
        end
    end

    // =========================================================================
    // GPIO Tri-State Buffers
    // =========================================================================
    // DIR=1 drives the output value. DIR=0 releases the pin for external input.
    genvar pin_index;
    generate
        for (pin_index = 0; pin_index < 32; pin_index = pin_index + 1) begin : g_gpio
            assign GPIO[pin_index] = gpio_dir[pin_index]
                ? gpio_out[pin_index]
                : 1'bz;
        end
    endgenerate

    // =========================================================================
    // Board LED Pin Mapping
    // =========================================================================
    assign LEDR = ledr[17:0];
    assign LEDG = ledg[7:0];

    // =========================================================================
    // MCU Instance
    // =========================================================================
    milestone3 #(
        .PROGRAMFILE     (PROGRAMFILE),
        .IMEM_ADDR_WIDTH (IMEM_ADDR_WIDTH),
        .DMEM_ADDR_WIDTH (DMEM_ADDR_WIDTH)
    ) mcu (
        .i_clk         (mcu_clk),
        .i_rstn        (mcu_rstn),
        .i_sw          (sw_sync),
        .i_key         ({key_sync, 1'b1}),
        .o_ledr        (ledr),
        .o_ledg        (ledg),
        .o_ledb        (),
        .o_hex0        (HEX0),
        .o_hex1        (HEX1),
        .o_hex2        (HEX2),
        .o_hex3        (HEX3),
        .o_hex4        (HEX4),
        .o_hex5        (HEX5),
        .o_hex6        (HEX6),
        .o_hex7        (HEX7),
        .o_lcd_data    (LCD_DATA),
        .o_lcd_rs      (LCD_RS),
        .o_lcd_rw      (LCD_RW),
        .o_lcd_en      (LCD_EN),
        .o_lcd_on      (LCD_ON),
        .o_lcd_blon    (LCD_BLON),
`ifdef DMEM_USE_SRAM
        .SRAM_ADDR     (SRAM_ADDR),
        .SRAM_DQ       (SRAM_DQ),
        .SRAM_CE_N     (SRAM_CE_N),
        .SRAM_WE_N     (SRAM_WE_N),
        .SRAM_OE_N     (SRAM_OE_N),
        .SRAM_LB_N     (SRAM_LB_N),
        .SRAM_UB_N     (SRAM_UB_N),
`endif
        .i_gpio_in     (gpio_sync),
        .o_gpio_out    (gpio_out),
        .o_gpio_dir    (gpio_dir),
        .o_event_valid (), //unused
        .o_event_data  (), //unused
        .o_print_valid (), //unused
        .o_print_char  (), //unused
        .o_halt        (), //unused
        .o_db_valid    ()  //unused
    );
endmodule: example_de2_wrapper
