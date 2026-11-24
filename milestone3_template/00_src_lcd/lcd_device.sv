// =============================================================================
// Module Name:   lcd_device
// Project:       Milestone 3 - Simple MCU
// Description:   Memory-mapped LCD registers and transfer handshake with lcd_ctrl.
// =============================================================================

`timescale 1ns / 1ps

module lcd_device (
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rstn,

    // Bus Interface
    input  logic        i_wren,
    input  logic [11:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [3:0]  i_bmsk,
    output logic [31:0] o_rdata,

    // LCD Outputs
    output wire  [7:0]  o_lcd_data,
    output wire         o_lcd_rs,
    output wire         o_lcd_rw,
    output wire         o_lcd_en,
    output wire         o_lcd_on,
    output wire         o_lcd_blon
);
    // =========================================================================
    // Register Address Selection
    // =========================================================================
    wire [9:0] word_offset = i_addr[11:2];

    // =========================================================================
    // LCD Register Signals
    // =========================================================================
    wire [31:0] data_value;
    wire [31:0] ctrl_value;
    logic [7:0] transfer_data;
    logic       transfer_rs;
    logic       transfer_valid;
    wire        transfer_ready;
    wire        transfer_busy = transfer_valid | ~transfer_ready;
    wire        transfer_request = i_wren & (word_offset == 10'd1)
        & i_bmsk[0] & i_wdata[1];

    // =========================================================================
    // LCD Register Storage
    // =========================================================================
    // DATA (+0): bits [7:0] hold the next command or character.
    mmio_register #(
        .WRITE_MASK (32'h0000_00ff)
    ) data_reg (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (word_offset == 10'd0)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (data_value)
    );

    // CTRL (+4): RS[0], SEND[1] (write-one pulse), ON[2], BLON[3].
    // SEND is a command, so it is not stored and always reads back as zero.
    mmio_register #(
        .WRITE_MASK (32'h0000_000d)
    ) ctrl_reg (
        .i_clk   (i_clk),
        .i_rstn  (i_rstn),
        .i_wren  (i_wren & (word_offset == 10'd1)),
        .i_wdata (i_wdata),
        .i_bmsk  (i_bmsk),
        .o_value (ctrl_value)
    );

    // =========================================================================
    // Transfer Request and Payload Storage
    // =========================================================================
    // Snapshot payload before asserting valid to the controller. Keep it stable
    // throughout the transfer, even if software changes DATA or CTRL while busy.
    // Requests while busy are ignored; software must poll STATUS before sending.
    always_ff @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            transfer_data  <= '0;
            transfer_rs    <= 1'b0;
            transfer_valid <= 1'b0;
        end else begin
            transfer_valid <= transfer_request & ~transfer_busy;
            if (transfer_request & ~transfer_busy) begin
                transfer_data <= data_value[7:0];
                transfer_rs   <= i_wdata[0];
            end
        end
    end

    // =========================================================================
    // LCD Controller and Physical Interface
    // =========================================================================
    // Reuses 00_src/lcd_ctrl.sv. At 25 MHz each cycle is 40 ns.
    // Use a 480 ns pulse so the requested width is an exact number of cycles.
    lcd_ctrl #(
        .T_PERIOD_NS (40),
        .T_AS_NS     (80),
        .T_PW_NS     (480),
        .T_CYCE_NS   (1000)
    ) controller (
        .i_clk      (i_clk),
        .i_rst_n    (i_rstn),
        .i_vld      (transfer_valid),
        .o_rdy      (transfer_ready),
        .i_LCD_DATA (transfer_data),
        .i_LCD_RW   (1'b0),
        .i_LCD_RS   (transfer_rs),
        .i_LCD_ON   (ctrl_value[2]),
        .o_LCD_DATA (o_lcd_data),
        .o_LCD_RW   (o_lcd_rw),
        .o_LCD_EN   (o_lcd_en),
        .o_LCD_RS   (o_lcd_rs),
        .o_LCD_ON   (o_lcd_on)
    );

    // The existing lcd_ctrl has no backlight port.
    assign o_lcd_blon = ctrl_value[3];

    // =========================================================================
    // Register Readback
    // =========================================================================
    // STATUS (+8): READY[0], BUSY[1] describe the controller handshake only.
    // LCD instruction execution still requires software delays (RW is fixed 0).
    always_comb begin
        case (word_offset)
            10'd0: o_rdata = data_value;
            10'd1: o_rdata = ctrl_value;
            10'd2: o_rdata = {30'b0, transfer_busy, ~transfer_busy};
            default: o_rdata = '0;
        endcase
    end
endmodule: lcd_device
