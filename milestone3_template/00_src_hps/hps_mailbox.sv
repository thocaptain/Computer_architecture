// =============================================================================
// Module Name:   hps_mailbox
// Project:       Milestone 3 - Simple MCU
// Description:   Two-way HPS/CPU mailbox with byte-enabled data and response IRQ.
// =============================================================================

`timescale 1ns / 1ps

module hps_mailbox (
    // Clock & Reset
    input  logic        clk,
    input  logic        reset_n,

    // HPS Avalon-MM Slave Interface
    input  logic [ 2:0]  avs_address,
    input  logic        avs_read,
    input  logic        avs_write,
    input  logic [31:0] avs_writedata,
    input  logic [ 3:0]  avs_byteenable,
    output logic [31:0] avs_readdata,
    output logic        avs_waitrequest,

    // CPU Memory-Mapped Interface
    input  logic [ 2:0]  cpu_address,
    input  logic        cpu_wren,
    input  logic [31:0] cpu_wdata,
    input  logic [ 3:0]  cpu_byteenable,
    output logic [31:0] cpu_rdata,

    // Interrupt Output
    output logic        irq
);

    // =========================================================================
    // Register Addresses and Identification
    // =========================================================================
    // Both interfaces use word addresses (byte offset / 4).
    localparam logic [ 2:0]  REG_ID         = 3'd0;
    localparam logic [ 2:0]  REG_STATUS     = 3'd1;
    localparam logic [ 2:0]  REG_COMMAND    = 3'd2;
    localparam logic [ 2:0]  REG_RESPONSE   = 3'd3;
    localparam logic [ 2:0]  REG_CONTROL    = 3'd4;
    localparam logic [ 2:0]  REG_IRQ_ENABLE = 3'd5;
    localparam logic [31:0] MAILBOX_ID     = 32'h4850_5331; // "HPS1"

    // =========================================================================
    // Mailbox State and Control Signals
    // =========================================================================
    // Both interfaces must share clk/reset_n. Only one command may be in flight.
    logic [31:0] command_data;
    logic [31:0] response_data;
    logic        command_pending;
    logic        response_pending;
    logic        irq_enable;

    wire mailbox_idle     = ~command_pending & ~response_pending;
    wire write_command    = avs_write & (avs_address == REG_COMMAND) & mailbox_idle;
    wire write_response   = cpu_wren & (cpu_address == REG_RESPONSE) & command_pending;
    wire host_control     = avs_write & (avs_address == REG_CONTROL) & avs_byteenable[0];
    wire start_command    = host_control & avs_writedata[0] & mailbox_idle;
    wire acknowledge      = host_control & avs_writedata[1];
    wire write_irq_enable = avs_write & (avs_address == REG_IRQ_ENABLE) & avs_byteenable[0];
    wire complete_command = cpu_wren & (cpu_address == REG_CONTROL) & cpu_byteenable[0]
                            & cpu_wdata[0] & command_pending & ~response_pending;

    // =========================================================================
    // Byte-Enabled Command and Response Storage
    // =========================================================================
    // HPS owns command data. CPU owns response data. Busy writes are ignored.
    genvar lane;

    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : g_byte
            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) begin
                    command_data[8*lane +: 8]  <= '0;
                    response_data[8*lane +: 8] <= '0;
                end else begin
                    if (write_command & avs_byteenable[lane]) begin
                        command_data[8*lane +: 8] <= avs_writedata[8*lane +: 8];
                    end

                    if (write_response & cpu_byteenable[lane]) begin
                        response_data[8*lane +: 8] <= cpu_wdata[8*lane +: 8];
                    end
                end
            end
        end
    endgenerate

    // =========================================================================
    // Command, Response and Interrupt Control
    // =========================================================================
    // START, ACK and COMPLETE are write-one commands; CONTROL reads as zero.
    // CPU completion takes priority over a simultaneous host acknowledgement.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            command_pending  <= 1'b0;
            response_pending <= 1'b0;
            irq_enable       <= 1'b0;
        end else begin
            if (start_command) begin
                command_pending  <= 1'b1;
            end

            if (acknowledge) begin
                response_pending <= 1'b0;
            end

            if (write_irq_enable) begin
                irq_enable       <= avs_writedata[0];
            end

            if (complete_command) begin
                command_pending  <= 1'b0;
                response_pending <= 1'b1;
            end
        end
    end

    // =========================================================================
    // HPS Register Readback
    // =========================================================================
    // Avalon addressUnits=WORDS, readLatency=0, no wait states.
    always_comb begin
        avs_readdata = '0;

        if (avs_read) begin
            case (avs_address)
                REG_ID         : avs_readdata = MAILBOX_ID;
                REG_STATUS     : avs_readdata = {30'b0, response_pending, command_pending};
                REG_COMMAND    : avs_readdata = command_data;
                REG_RESPONSE   : avs_readdata = response_data;
                REG_IRQ_ENABLE : avs_readdata = {31'b0, irq_enable};
                default        : avs_readdata = '0;
            endcase
        end
    end

    // =========================================================================
    // CPU Register Readback
    // =========================================================================
    always_comb begin
        case (cpu_address)
            REG_ID         : cpu_rdata = MAILBOX_ID;
            REG_STATUS     : cpu_rdata = {30'b0, response_pending, command_pending};
            REG_COMMAND    : cpu_rdata = command_data;
            REG_RESPONSE   : cpu_rdata = response_data;
            REG_IRQ_ENABLE : cpu_rdata = {31'b0, irq_enable};
            default        : cpu_rdata = '0;
        endcase
    end

    // =========================================================================
    // Avalon Flow Control and Response Interrupt
    // =========================================================================
    assign avs_waitrequest = 1'b0;
    assign irq             = irq_enable & response_pending;
endmodule : hps_mailbox
