// =============================================================================
// Module Name:   timer_device
// Project:       Milestone 3 - Simple MCU
// Description:   64-bit cycle counter with enable, write-one clear and readback.
// =============================================================================

`timescale 1ns / 1ps

module timer_device (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [11:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    output logic [31:0] o_rdata
);

    // =========================================================================
    // Timer State and Control Signals
    // =========================================================================
    logic        enabled;
    logic [63:0] count;
    wire  [63:0] next_count;
    wire         write_control = i_wren & (i_addr[11:2] == 10'd0) & i_bmsk[0];
    wire         clear_count   = write_control & i_wdata[1];

    // =========================================================================
    // 64-Bit Counter Increment
    // =========================================================================
    bit_adder #(
        .WIDTH (64)
    ) increment (
        .i_a     (count),
        .i_b     (64'd1),
        .i_carry (1'b0),
        .o_sum   (next_count),
        .o_carry ()
    );

    // =========================================================================
    // Counter and Enable Registers
    // =========================================================================
    // CLR is a write-one command. It never remains asserted in CTRL readback.
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            enabled <= 1'b0;
            count   <= '0;
        end else begin
            if (write_control) begin
                enabled <= i_wdata[0];
            end
            if (clear_count) begin
                count <= '0;
            end else if (enabled) begin
                count <= next_count;
            end
        end
    end

    // =========================================================================
    // Timer Register Readback
    // =========================================================================
    always_comb begin
        case (i_addr[11:2])
            10'd0: o_rdata = {31'b0, enabled};
            10'd1: o_rdata = count[31:0];
            10'd2: o_rdata = count[63:32];
            default: o_rdata = '0;
        endcase
    end
endmodule: timer_device
