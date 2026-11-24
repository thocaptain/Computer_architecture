// =============================================================================
// Module Name:   dmem
// Project:       Milestone 3 - Simple MCU
// Description:   Selectable flop or external 16-bit SRAM data-memory backend.
// =============================================================================

`timescale 1ns / 1ps
`include "mcu_config.svh"

module dmem #(
    parameter logic [31:0] START_ADDR = 32'h8400_0000,
    parameter int unsigned ADDR_WIDTH = 14
)(
    // Clock & Reset
    input  logic        i_clk,

    // Bus Interface
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    input  logic        i_wren,
`ifdef DMEM_USE_SRAM
    // External SRAM Request/Completion Interface
    input  logic        i_rstn,
    input  logic        i_valid,
    output wire         o_ready,

    // External 16-Bit SRAM Pins
    output wire [17:0]  SRAM_ADDR,
    inout  wire [15:0]  SRAM_DQ,
    output wire         SRAM_CE_N,
    output wire         SRAM_WE_N,
    output wire         SRAM_OE_N,
    output wire         SRAM_LB_N,
    output wire         SRAM_UB_N,
`endif
    output logic [31:0] o_rdata
);

    wire selected = (i_addr[31:ADDR_WIDTH] == START_ADDR[31:ADDR_WIDTH]);

`ifdef DMEM_USE_SRAM
    // =========================================================================
    // External SRAM Backend
    // =========================================================================
    // SRAM addresses select 16-bit halfwords. Each 32-bit word starts at an
    // even halfword address. The byte offset is handled by the LSU byte mask.
    wire [17:0] halfword_address;
    wire        acknowledge;
    wire [31:0] read_data;

    assign halfword_address = {{(19-ADDR_WIDTH){1'b0}}, i_addr[ADDR_WIDTH-1:2], 1'b0};
    assign o_ready = ~i_valid | ~selected | acknowledge;
    assign o_rdata = selected ? read_data : 32'b0;

    mcu_sram_ctrl controller (
        .i_clk      (i_clk),
        .i_rstn     (i_rstn),
        .i_request  (i_valid & selected),
        .i_addr     (halfword_address),
        .i_wdata    (i_wdata),
        .i_bmsk     (i_bmsk),
        .i_wren     (i_wren),
        .o_rdata    (read_data),
        .o_ack      (acknowledge),
        .SRAM_ADDR  (SRAM_ADDR),
        .SRAM_DQ    (SRAM_DQ),
        .SRAM_CE_N  (SRAM_CE_N),
        .SRAM_WE_N  (SRAM_WE_N),
        .SRAM_OE_N  (SRAM_OE_N),
        .SRAM_LB_N  (SRAM_LB_N),
        .SRAM_UB_N  (SRAM_UB_N)
    );
`else
    // =========================================================================
    // Memory Storage and Address Selection
    // =========================================================================
    localparam int N_WORDS = 2**(ADDR_WIDTH-2);
    logic [31:0] mem [0:N_WORDS-1];

    // =========================================================================
    // Combinational Read Port
    // =========================================================================
    assign o_rdata = selected ? mem[i_addr[ADDR_WIDTH-1:2]] : 32'b0;

    // =========================================================================
    // Byte-Enabled Write Port
    // =========================================================================
    genvar lane;
    generate
    for (lane = 0; lane < 4; lane = lane + 1) begin : g_byte
        always_ff @(posedge i_clk) begin
            if (selected & i_wren & i_bmsk[lane]) begin
                mem[i_addr[ADDR_WIDTH-1:2]][8*lane +: 8] <= i_wdata[8*lane +: 8];
            end
        end
    end
    endgenerate
`endif
endmodule: dmem
