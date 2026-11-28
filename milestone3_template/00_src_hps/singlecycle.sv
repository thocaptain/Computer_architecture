// =============================================================================
// Module Name:   singlecycle
// Project:       Milestone 3 - Simple MCU
// Description:   Milestone-compatible wrapper around the single-cycle RV32I core.
// =============================================================================

`timescale 1ns / 1ps
`include "mcu_config.svh"

module singlecycle (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Instruction Memory Interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_rdata,

    // Load/Store Bus Interface
`ifdef DMEM_USE_SRAM
    input  logic        i_dmem_ready,
    output logic        o_dmem_valid,
`endif
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [3:0]  o_dmem_bmsk,
    output logic        o_dmem_wren,
    input  logic [31:0] i_dmem_rdata,

    // Simulation & Debug Outputs
    output logic        o_db_valid
);

    // =========================================================================
    // Processor Instance
    // =========================================================================
    rv32i_single_cycle #(
        .RESET_PC (32'h8000_0000)
    ) cpu (
        .i_clk        (i_clk),
        .i_rst_n      (i_rstn),
        .o_imem_addr  (o_imem_addr),
        .i_imem_rdata (i_imem_rdata),
`ifdef DMEM_USE_SRAM
        .i_dmem_ready (i_dmem_ready),
        .o_dmem_valid (o_dmem_valid),
`endif
        .o_dmem_addr  (o_dmem_addr),
        .o_dmem_wdata (o_dmem_wdata),
        .o_dmem_bmsk  (o_dmem_bmsk),
        .o_dmem_wren  (o_dmem_wren),
        .i_dmem_rdata (i_dmem_rdata),
        .o_insn_vld   (o_db_valid)
    );
endmodule: singlecycle
