`include "rv32i.svh"

module data_mem 
    import rv32i_pkg::*;
#(
    parameter MEM_TYPE = 1, // 0: flop-based, 1: SRAM-based
    parameter ADDR_W   = 18 // this param is only for MEM_TYPE == 0
)
(
      input  logic              i_clk
    , input  logic              i_rst_n
    // LSU interface
/* verilator lint_off UNUSEDSIGNAL */
    , input  logic [17:0]       i_ADDR 
/* verilator lint_off UNUSEDSIGNAL */
    , input  logic [31:0]       i_WDATA
    , input  logic [ 3:0]       i_BMASK
    , input  logic              i_WREN // 1: write, 0: read 
    , output logic [31:0]       o_RDATA
    // AXI handshake
    , input  logic              i_VALID
    , output logic              o_READY 

    // SRAM interface
    , output logic [17:0] SRAM_ADDR
    , inout  wire  [15:0] SRAM_DQ  
    , output logic        SRAM_CE_N
    , output logic        SRAM_WE_N
    , output logic        SRAM_LB_N
    , output logic        SRAM_UB_N
/* verilator lint_off UNUSEDSIGNAL */
    , output logic        SRAM_OE_N
/* verilator lint_off UNUSEDSIGNAL */

);
    localparam N_WORDS = (2**ADDR_W) / 4;
//////////////////////////////////////////////////////////////////////////
// AXI-HANDSHAKE to REQ/ACK-HANDSHAKE
//////////////////////////////////////////////////////////////////////////
    logic mem_req;
    logic mem_ack;
    logic vld_q;
    logic rdy_q;

    always_ff @( posedge i_clk) begin
        if(~i_rst_n) begin 
            vld_q <= 0;
            rdy_q <= 0;
        end
        else begin         
            vld_q <= i_VALID;
            rdy_q <= o_READY;
        end
    end

    always_comb begin
        mem_req = i_VALID & (~vld_q | rdy_q);
        o_READY = mem_ack;
    end

    generate
//////////////////////////////////////////////////////////////////////////
// FLOP-BASED memory
//////////////////////////////////////////////////////////////////////////
        if (MEM_TYPE == MEM_FLOP) begin: g_flop_mem
            logic [3:0][7:0] mem [0: N_WORDS-1];

            localparam N_STAGES = 9; // used for simulating access memory with latency
            if(N_STAGES == 0) begin: ack_no_latency
                assign mem_ack = 1'b1; // always ready to read/write
            end
            else begin: ack_latency
                logic [N_STAGES:1] mem_ack_reg;
                genvar l;
                for(l=0; l<N_STAGES; l++) begin: g_latency
                    if(l==0) begin: g_0_case
                        `PRIM_FF_EN_RST(mem_ack_reg[1], mem_req, 1'b1, i_rst_n, i_clk, '0)
                    end
                    else begin: g_esle_case
                        `PRIM_FF_EN_RST(mem_ack_reg[l+1], mem_ack_reg[l], 1'b1, i_rst_n, i_clk, '0)
                    end
                end
                assign mem_ack = mem_ack_reg[N_STAGES];
            end

            assign o_RDATA = mem[i_ADDR[ADDR_W-1:2]];
            always_ff@(posedge i_clk)	begin
                if(mem_req & i_WREN) begin
                    if(i_BMASK[0]) mem[i_ADDR[ADDR_W-1:2]][0] <= i_WDATA[8*0+:8];
                    if(i_BMASK[1]) mem[i_ADDR[ADDR_W-1:2]][1] <= i_WDATA[8*1+:8];
                    if(i_BMASK[2]) mem[i_ADDR[ADDR_W-1:2]][2] <= i_WDATA[8*2+:8];
                    if(i_BMASK[3]) mem[i_ADDR[ADDR_W-1:2]][3] <= i_WDATA[8*3+:8];
                end
            end

            assign SRAM_DQ = '0;
            always_comb begin
                SRAM_ADDR = '0;
                SRAM_OE_N = '0;
                SRAM_CE_N = '0;
                SRAM_WE_N = '0;
                SRAM_LB_N = '0;
                SRAM_UB_N = '0;
            end
        end
//////////////////////////////////////////////////////////////////////////
// SRAM-BASED memory
//////////////////////////////////////////////////////////////////////////
        else if(MEM_TYPE == MEM_SRAM) begin: g_sram_mem
            logic ctrl_wren;
            logic ctrl_rden;

            always_comb begin
                ctrl_wren = mem_req &  i_WREN;
                ctrl_rden = mem_req & ~i_WREN;
            end

            sram_ctrl sram(
              .i_ADDR   (i_ADDR[17:0]),     
              .i_WDATA  (i_WDATA     ),     
              .i_BMASK  (i_BMASK     ),     
              .i_WREN   (ctrl_wren   ),     
              .i_RDEN   (ctrl_rden   ),     
              .o_RDATA  (o_RDATA     ),     
              .o_ACK    (mem_ack     ),     

              .SRAM_ADDR(SRAM_ADDR),     
              .SRAM_DQ  (SRAM_DQ  ),     
              .SRAM_CE_N(SRAM_CE_N),     
              .SRAM_WE_N(SRAM_WE_N),     
              .SRAM_LB_N(SRAM_LB_N),     
              .SRAM_UB_N(SRAM_UB_N),     
              .SRAM_OE_N(SRAM_OE_N),     

              .i_clk    (i_clk    ), 
              .i_reset  (i_rst_n  )  
            );
        end
    endgenerate
    
endmodule
