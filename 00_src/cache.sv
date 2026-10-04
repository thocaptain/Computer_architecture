`include "rv32i.svh"

module cache #(
    parameter TOTAL_ADDR_W  = 18,
    parameter OFFSET_ADDR_W = 4, // 2^OFFSET_ADDR_W words in a cache line
    parameter IDX_ADDR_W    = 5  // 2^ IDX_ADDR_W line in a cache
) (
      input logic i_clk
    , input logic i_rst_n

/* verilator lint_off UNUSEDSIGNAL */
    , input  logic [TOTAL_ADDR_W-1:0] i_ADDR 
/* verilator lint_off UNUSEDSIGNAL */
    , input  logic [31:0]             i_WDATA
    , input  logic [ 3:0]             i_BMASK
    , input  logic                    i_WREN // 1: write, 0: read 
    , output logic [31:0]             o_RDATA
    // AXI handshake
    , input  logic                    i_VALID
    , output logic                    o_READY   

    // Memory interface
    , output logic [TOTAL_ADDR_W-1:0] o_mem_ADDR 
    , output logic [31:0]             o_mem_WDATA
    , output logic [ 3:0]             o_mem_BMASK
    , output logic                    o_mem_WREN // 1: write, 0: read 
    , input  logic [31:0]             i_mem_RDATA
    // AXI handshake
    , output logic                    o_mem_VALID
    , input  logic                    i_mem_READY   
);
//////////////////////////////////////////////////////////////////////////
// Declaration
//////////////////////////////////////////////////////////////////////////   
    localparam TAG_W            = TOTAL_ADDR_W - IDX_ADDR_W - OFFSET_ADDR_W - 2;
    localparam OFFSET_START     = 2;
    localparam IDX_START        = OFFSET_START + OFFSET_ADDR_W;
    localparam TAG_START        = IDX_START    + IDX_ADDR_W;
    localparam N_LINE_PER_CACHE = 2**IDX_ADDR_W;
    localparam N_WORD_PER_LINE  = 2**OFFSET_ADDR_W;
    localparam CACHE_DEPTH      = N_WORD_PER_LINE * N_LINE_PER_CACHE;
    localparam CACHE_ADDR_W     = 2 + IDX_ADDR_W + OFFSET_ADDR_W;

    typedef enum logic [1:0] {
        CACHE_IDLE       = 2'd0, 
        CACHE_WRITE_BACK = 2'd1, 
        CACHE_FETCH      = 2'd2 
    } CacheState_e;
    typedef struct packed {
        logic             vld;
        logic [TAG_W-1:0] tag;
    } CacheEntry_s;
    
    logic [3:0][7:0] cache_mem [0: CACHE_DEPTH-1];
    CacheState_e cache_state, cache_state_next;
    CacheEntry_s [N_LINE_PER_CACHE-1:0] cache_entry; 
    logic is_vld;
    logic is_hit;
    logic is_tag_match;
    logic mem_done;
    logic cache_addr_rst;
    logic cache_addr_inc;
    logic [CACHE_ADDR_W-1:0] cache_addr, cache_addr_next;

//////////////////////////////////////////////////////////////////////////
// CACHE MEM
//////////////////////////////////////////////////////////////////////////   
    always_ff @( posedge i_clk ) begin
        if((o_mem_VALID & i_mem_READY) & ~o_mem_WREN) begin
            cache_mem[cache_addr[CACHE_ADDR_W-1:2]] <= i_mem_RDATA;
        end
        else if((i_VALID & o_READY) & i_WREN) begin
            if(i_BMASK[0]) cache_mem[i_ADDR[CACHE_ADDR_W-1:2]][0] <= i_WDATA[8*0+:8];
            if(i_BMASK[1]) cache_mem[i_ADDR[CACHE_ADDR_W-1:2]][1] <= i_WDATA[8*1+:8];
            if(i_BMASK[2]) cache_mem[i_ADDR[CACHE_ADDR_W-1:2]][2] <= i_WDATA[8*2+:8];
            if(i_BMASK[3]) cache_mem[i_ADDR[CACHE_ADDR_W-1:2]][3] <= i_WDATA[8*3+:8];
        end
    end

    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            cache_entry <= '0;
        end
        else begin
            if(mem_done) begin
                if(cache_state==CACHE_FETCH) begin
                    cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].vld <= 1'b1; 
                    cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].tag <= i_ADDR[TAG_START +: TAG_W]; 
                end
                else if(cache_state==CACHE_WRITE_BACK) begin
                    cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].vld <= 1'b0; 
                    cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].tag <= '0; 
                end
            end
        end
    end

    always_comb begin
       o_RDATA = cache_mem[i_ADDR[CACHE_ADDR_W-1:2]]; 
       o_READY = (cache_state==CACHE_IDLE) & is_hit;
    end

//////////////////////////////////////////////////////////////////////////
// CACHE LOGIC
//////////////////////////////////////////////////////////////////////////   
    `PRIM_FF_RST(cache_addr , cache_addr_next , i_rst_n, i_clk, '0)
    `PRIM_FF_RST(cache_state, cache_state_next, i_rst_n, i_clk, CACHE_IDLE)

    always_comb begin
        case (cache_state)
            CACHE_IDLE: begin
                if(i_VALID) begin
                    if(is_hit)
                        cache_state_next = CACHE_IDLE;
                    else if(is_vld) // no hit
                        cache_state_next = CACHE_WRITE_BACK;
                    else // invalid
                        cache_state_next = CACHE_FETCH;
                end
                else begin
                    cache_state_next = cache_state;
                end
            end 
            CACHE_WRITE_BACK: begin
                if(mem_done) begin
                    cache_state_next = CACHE_FETCH;
                end
                else begin
                    cache_state_next = cache_state;
                end
            end
            CACHE_FETCH: begin
                if(mem_done) begin
                    cache_state_next = CACHE_IDLE;
                end
                else begin
                    cache_state_next = cache_state;
                end
            end
            default: begin
                cache_state_next = CACHE_IDLE;
            end
        endcase 
    end

    always_comb begin
        o_mem_VALID = (cache_state == CACHE_FETCH) || (cache_state == CACHE_WRITE_BACK);

        if(cache_state == CACHE_WRITE_BACK)
            o_mem_ADDR  = {cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].tag, cache_addr};
        else
            o_mem_ADDR  = {i_ADDR[TAG_START +: TAG_W], cache_addr};

        o_mem_BMASK = '1;
        o_mem_WDATA = cache_mem[cache_addr[OFFSET_START +: (OFFSET_ADDR_W+IDX_ADDR_W)]];
        o_mem_WREN  = cache_state == CACHE_WRITE_BACK;
    end

    // separate to another always_comb to prevent circular loop, STUPID Verilator
    always_comb begin
        is_vld       = cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].vld;
        is_tag_match = cache_entry[i_ADDR[IDX_START +: IDX_ADDR_W]].tag == i_ADDR[TAG_START +: TAG_W];
        is_hit       = is_vld & is_tag_match;

        mem_done       = (cache_addr[OFFSET_START +: OFFSET_ADDR_W] == OFFSET_ADDR_W'(N_WORD_PER_LINE-1)) 
                       & (o_mem_VALID & i_mem_READY);
        cache_addr_rst = cache_state != cache_state_next;
        cache_addr_inc = o_mem_VALID & i_mem_READY;
        cache_addr_next = (cache_addr_rst)? {i_ADDR[IDX_START +: IDX_ADDR_W], (OFFSET_ADDR_W+2)'(0)}
                        : (cache_addr_inc)? cache_addr+4 : cache_addr; 
    end
endmodule
