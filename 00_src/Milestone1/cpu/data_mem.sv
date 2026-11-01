// Keep the original nine-stage acknowledgement protocol while replacing storage
// and read behavior with a Milestone1 memory. SRAM hardware is outside this test.
module data_mem #(
    parameter MEM_TYPE = 0,
    parameter ADDR_W = 18
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [17:0] i_ADDR,
    input  logic [31:0] i_WDATA,
    input  logic [3:0]  i_BMASK,
    input  logic        i_WREN,
    output logic [31:0] o_RDATA,
    input  logic        i_VALID,
    output logic        o_READY,
    output logic [17:0] SRAM_ADDR,
    inout  wire  [15:0] SRAM_DQ,
    output logic        SRAM_CE_N,
    output logic        SRAM_WE_N,
    output logic        SRAM_LB_N,
    output logic        SRAM_UB_N,
    output logic        SRAM_OE_N
);
    logic previous_valid, previous_ready;
    logic [8:0] ack_pipe;
    logic request;
    assign request = i_rst_n & i_VALID & (~previous_valid | previous_ready);
    assign o_READY = ack_pipe[8];
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            previous_valid <= 0;
            previous_ready <= 0;
            ack_pipe <= 0;
        end else begin
            previous_valid <= i_VALID;
            previous_ready <= o_READY;
            ack_pipe <= {ack_pipe[7:0], request};
        end
    end

    // The original LSU already decodes 0x2000..0x3fff and passes an offset.
`ifdef MILESTONE1_SYNC_MEMORY
    data_mem_sync #(.START_ADDR(32'b0), .ADDR_WIDTH(ADDR_W)) u_milestone1 (
        .i_clk(i_clk), .i_addr({14'b0, i_ADDR}), .i_wdata(i_WDATA),
        .i_bmsk(i_BMASK), .i_wren(request & i_WREN),
        .i_rden(request & ~i_WREN), .o_rdata(o_RDATA)
    );
`else
    data_mem_async #(.START_ADDR(32'b0), .ADDR_WIDTH(ADDR_W)) u_milestone1 (
        .i_clk(i_clk), .i_addr({14'b0, i_ADDR}), .i_wdata(i_WDATA),
        .i_bmsk(i_BMASK), .i_wren(request & i_WREN), .o_rdata(o_RDATA)
    );
`endif
    assign SRAM_ADDR = 0;
    assign SRAM_DQ = 16'bz;
    assign SRAM_CE_N = 1;
    assign SRAM_WE_N = 1;
    assign SRAM_LB_N = 1;
    assign SRAM_UB_N = 1;
    assign SRAM_OE_N = 1;
    initial begin
        if (MEM_TYPE != 0) $fatal(1, "Milestone1 CPU bench requires MEM_FLOP");
    end
endmodule
