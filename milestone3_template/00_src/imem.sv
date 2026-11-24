// =============================================================================
// Module Name:   imem
// Project:       Milestone 3 - Simple MCU
// Description:   Asynchronous instruction memory with optional word-hex initialization.
// =============================================================================

`timescale 1ns / 1ps

module imem #(
    parameter logic [31:0] START_ADDR = 32'h8000_0000,
    parameter int unsigned ADDR_WIDTH = 16,
    parameter PROGRAMFILE             = ""
)(
    // Clock & Reset
    input  logic        i_clk,

    // Bus Interface
    input  logic [31:0] i_addr,

    // Control Signals
    output logic [31:0] o_data
);

    // =========================================================================
    // Memory Storage and Address Selection
    // =========================================================================
    localparam int N_WORDS = 2**(ADDR_WIDTH-2);
    logic [31:0] mem [0:N_WORDS-1];
    wire         selected = (i_addr[31:ADDR_WIDTH] == START_ADDR[31:ADDR_WIDTH]);

    // =========================================================================
    // Instruction Read Port
    // =========================================================================
    assign o_data = selected ? mem[i_addr[ADDR_WIDTH-1:2]] : 32'b0;

    // =========================================================================
    // Program Image Initialization
    // =========================================================================
    initial begin
        if (PROGRAMFILE != "") begin
            $readmemh(PROGRAMFILE, mem);
        end
    end
endmodule: imem
