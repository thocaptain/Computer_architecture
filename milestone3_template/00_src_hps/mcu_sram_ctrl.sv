// =============================================================================
// Module Name:   mcu_sram_ctrl
// Project:       Milestone 3 - Simple MCU
// Description:   32-bit request/ACK adapter for an asynchronous 16-bit SRAM.
//                Transfers lower and upper halfwords with byte enables.
//                Write setup, pulse and hold occupy separate clock cycles.
// =============================================================================

`timescale 1ns / 1ps

module mcu_sram_ctrl (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Request Interface
    input  logic        i_request,
    input  logic [17:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    input  logic        i_wren,
    output logic [31:0] o_rdata,
    output wire         o_ack,

    // External SRAM Pins
    output logic [17:0] SRAM_ADDR,
    inout  wire  [15:0] SRAM_DQ,
    output logic        SRAM_CE_N,
    output logic        SRAM_WE_N,
    output logic        SRAM_OE_N,
    output logic        SRAM_LB_N,
    output logic        SRAM_UB_N
);

    // =========================================================================
    // Transaction State and Captured Request
    // =========================================================================
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_READ_LO,
        ST_READ_HI,
        ST_WRITE_LO_SETUP,
        ST_WRITE_LO_PULSE,
        ST_WRITE_LO_HOLD,
        ST_WRITE_HI_SETUP,
        ST_WRITE_HI_PULSE,
        ST_WRITE_HI_HOLD,
        ST_COMPLETE
    } state_e;

    state_e      state;
    logic [17:0] address;
    logic [31:0] write_data;
    logic [3:0]  byte_mask;
    logic        drive_data;
    logic [15:0] output_data;

    // =========================================================================
    // Transaction Sequencing and Read Data Capture
    // =========================================================================
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            state      <= ST_IDLE;
            address    <= '0;
            write_data <= '0;
            byte_mask  <= '0;
            o_rdata    <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (i_request) begin
                        address    <= {i_addr[17:1], 1'b0};
                        write_data <= i_wdata;
                        byte_mask  <= i_bmsk;
                        if (i_wren) begin
                            state <= ST_WRITE_LO_SETUP;
                        end else begin
                            state <= ST_READ_LO;
                        end
                    end
                end
                ST_READ_LO: begin
                    o_rdata[15:0] <= SRAM_DQ;
                    state        <= ST_READ_HI;
                end
                ST_READ_HI: begin
                    o_rdata[31:16] <= SRAM_DQ;
                    state         <= ST_COMPLETE;
                end
                ST_WRITE_LO_SETUP: state <= ST_WRITE_LO_PULSE;
                ST_WRITE_LO_PULSE: state <= ST_WRITE_LO_HOLD;
                ST_WRITE_LO_HOLD:  state <= ST_WRITE_HI_SETUP;
                ST_WRITE_HI_SETUP: state <= ST_WRITE_HI_PULSE;
                ST_WRITE_HI_PULSE: state <= ST_WRITE_HI_HOLD;
                ST_WRITE_HI_HOLD:  state <= ST_COMPLETE;
                // The CPU consumes ACK at this edge and advances its request.
                ST_COMPLETE: state <= ST_IDLE;
                default:     state <= ST_IDLE;
            endcase
        end
    end

    // =========================================================================
    // SRAM Address, Direction and Byte Controls
    // =========================================================================
    always_comb begin
        SRAM_ADDR = address;
        SRAM_CE_N = 1'b1;
        SRAM_WE_N = 1'b1;
        SRAM_OE_N = 1'b1;
        SRAM_LB_N = 1'b1;
        SRAM_UB_N = 1'b1;
        drive_data = 1'b0;
        output_data = write_data[15:0];

        if (i_rstn) begin
            case (state)
                ST_READ_LO, ST_READ_HI: begin
                    SRAM_CE_N = 1'b0;
                    SRAM_OE_N = 1'b0;
                    SRAM_LB_N = 1'b0;
                    SRAM_UB_N = 1'b0;
                    if (state == ST_READ_HI) SRAM_ADDR = address | 18'd1;
                end
                ST_WRITE_LO_SETUP, ST_WRITE_LO_PULSE, ST_WRITE_LO_HOLD: begin
                    SRAM_CE_N = 1'b0;
                    SRAM_LB_N = ~byte_mask[0];
                    SRAM_UB_N = ~byte_mask[1];
                    SRAM_WE_N = (state != ST_WRITE_LO_PULSE);
                    drive_data = 1'b1;
                end
                ST_WRITE_HI_SETUP, ST_WRITE_HI_PULSE, ST_WRITE_HI_HOLD: begin
                    SRAM_ADDR = address | 18'd1;
                    SRAM_CE_N = 1'b0;
                    SRAM_LB_N = ~byte_mask[2];
                    SRAM_UB_N = ~byte_mask[3];
                    SRAM_WE_N = (state != ST_WRITE_HI_PULSE);
                    drive_data = 1'b1;
                    output_data = write_data[31:16];
                end
                default: begin end
            endcase
        end
    end

    assign SRAM_DQ = drive_data ? output_data : 16'bz;
    assign o_ack   = i_rstn & (state == ST_COMPLETE);
endmodule: mcu_sram_ctrl
