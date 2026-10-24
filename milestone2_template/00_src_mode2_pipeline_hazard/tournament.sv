module tournament 
    import rv32i_pkg::*;
#(
    parameter PC_WIDTH     = 32, 
    parameter INST_WIDTH   = 32, 
    parameter PRED_STRATEGY = PRED_BOTH,

    parameter BTB_ADDR_W   = 9, // BTB: branch table buffer. Increase this will increase hit rate

    parameter EVAL_N_BIT_SCHEME = 3,

    parameter GLB_PHT_ADDR_W   = 8, // PHT: pattern history table. Increase this will increase accuracy 
    parameter GLB_N_BIT_SCHEME = 2,  // N-bit saturated counter

    parameter LOC_PHT_ADDR_W   = 8, // PHT: pattern history table. Increase this will increase accuracy 
    parameter LOC_N_BIT_SCHEME = 2  // N-bit saturated counter
) (
      input  logic i_clk
    , input  logic i_rst_n

    , input  logic [PC_WIDTH-1:0] i_pc
    , output logic                o_hit
    , output logic                o_taken
    , output logic [PC_WIDTH-1:0] o_next_pc
    , output logic                o_glb_taken
    , output logic                o_loc_taken

    // update BTB
    , input  logic                i_upd_btb_vld
    /* verilator lint_off UNUSEDSIGNAL */
    , input  logic [PC_WIDTH-1:0] i_upd_btb_pc
    /* verilator lint_off UNUSEDSIGNAL */
    , input  logic [PC_WIDTH-1:0] i_upd_btb_br_addr

    // update PHT
    , input  logic                i_upd_pht_vld  // update whenever a branch inst
    // update eval
    , input  logic                i_upd_eval_vld // update when hit at previous stage
    /* verilator lint_off UNUSEDSIGNAL */
    , input  logic [PC_WIDTH-1:0] i_upd_pht_pc
    /* verilator lint_off UNUSEDSIGNAL */
    , input  logic                i_upd_pht_taken 
    , input  logic                i_upd_pht_pred_glb_taken
    , input  logic                i_upd_pht_pred_loc_taken
);
    localparam PC_LOWER_UNUSED = $clog2(INST_WIDTH/8);
    localparam BTB_DEPHT = 2**BTB_ADDR_W;
    localparam TAG_WIDTH = PC_WIDTH - BTB_ADDR_W - PC_LOWER_UNUSED;

    typedef struct packed {
        logic [TAG_WIDTH-1:0]         tag; 
        logic [PC_WIDTH-1:0]          br_addr; 
        logic                         vld; 
    } BtbEntry_s;

//////////////////////////////////////////////////////////////////////////
// Branch table buffer
//////////////////////////////////////////////////////////////////////////   
    BtbEntry_s             btb  [BTB_DEPHT-1:0];
    BtbEntry_s             btb_entry;
    logic [BTB_ADDR_W-1:0] pc_btb_idx;
    logic [BTB_ADDR_W-1:0] pc_btb_upd_idx;
    logic [TAG_WIDTH-1:0]  pc_btb_tag;
    logic [TAG_WIDTH-1:0]  pc_btb_upd_tag;
    logic                  glb_predict_taken, loc_predict_taken;
    logic                  eval_sel_glb;

    assign pc_btb_idx = i_pc[PC_LOWER_UNUSED +: BTB_ADDR_W];
    assign pc_btb_tag = i_pc[PC_WIDTH-1      -: TAG_WIDTH];

    assign pc_btb_upd_idx = i_upd_btb_pc[PC_LOWER_UNUSED +: BTB_ADDR_W];
    assign pc_btb_upd_tag = i_upd_btb_pc[PC_WIDTH-1      -: TAG_WIDTH];
    always_ff @( posedge i_clk ) begin
       if(~i_rst_n) begin
        for(int i=0; i<BTB_DEPHT; i++) begin
            btb[i]  <= '0;
        end
       end 
       else begin
        if(i_upd_btb_vld) begin
            btb[pc_btb_upd_idx].tag     <= pc_btb_upd_tag;
            btb[pc_btb_upd_idx].br_addr <= i_upd_btb_br_addr;
            btb[pc_btb_upd_idx].vld     <= 1'b1;
        end
       end
    end

    always_comb begin
        // access branch table buffer entry
        btb_entry = btb[pc_btb_idx];
        // see if it is a hit
        o_hit     = (btb_entry.tag == pc_btb_tag) & btb_entry.vld;
        // select next pc based on hit and predict
        case (PRED_STRATEGY)
            PRED_BOTH: o_taken = o_hit & (eval_sel_glb ? glb_predict_taken : loc_predict_taken);
            PRED_LOC : o_taken = o_hit & loc_predict_taken;
            PRED_GLB : o_taken = o_hit & glb_predict_taken;
            PRED_NONE: o_taken = o_hit; // always taken
            default:   o_taken = 1'b0;
        endcase
        o_next_pc = (o_taken)? btb_entry.br_addr : PC_WIDTH'(i_pc + 4);
        o_glb_taken = o_hit & glb_predict_taken;
        o_loc_taken = o_hit & loc_predict_taken;
    end
//////////////////////////////////////////////////////////////////////////
// Evaluation
//////////////////////////////////////////////////////////////////////////   
    logic [EVAL_N_BIT_SCHEME-1:0] eval [BTB_DEPHT-1:0]; 
    logic [EVAL_N_BIT_SCHEME-1:0] eval_next, eval_write, eval_read; 
    logic [BTB_ADDR_W-1:0]        eval_idx_write, eval_idx_read;
    logic loc_correct, glb_correct;

    always_comb begin
        eval_idx_read = i_pc[PC_LOWER_UNUSED +: BTB_ADDR_W];
        eval_read     = eval[eval_idx_read];
        eval_sel_glb  = eval_read[EVAL_N_BIT_SCHEME-1]; // MSB = 1 -> select global predictor
    end

    assign eval_idx_write = i_upd_pht_pc[PC_LOWER_UNUSED +: BTB_ADDR_W];
    always_ff @( posedge i_clk ) begin
       if(~i_rst_n) begin
        for(int i=0; i<BTB_DEPHT; i++) begin
            eval[i]  <= '1;
        end
       end 
       else begin
        if(i_upd_eval_vld) begin
            eval[eval_idx_write] <= eval_next;
        end
       end
    end

    assign loc_correct = i_upd_pht_pred_loc_taken == i_upd_pht_taken;
    assign glb_correct = i_upd_pht_pred_glb_taken == i_upd_pht_taken;
    always_comb begin
        eval_write = eval[eval_idx_write];
        if     (glb_correct & ~loc_correct)
            eval_next =  (eval_write != '1)? eval_write +  EVAL_N_BIT_SCHEME'('d1)  : eval_write;
        else if(loc_correct & ~glb_correct)
            eval_next =  (eval_write != '0)? eval_write + {EVAL_N_BIT_SCHEME{1'b1}} : eval_write; // minus 1
        else
            eval_next = eval_write;
    end
//////////////////////////////////////////////////////////////////////////
// Global Predictor: GShare
//////////////////////////////////////////////////////////////////////////   
    localparam GLB_PHT_DEPHT = 2**GLB_PHT_ADDR_W;

    logic [GLB_PHT_ADDR_W-1:0]   ghr; // global history register
    logic [GLB_N_BIT_SCHEME-1:0] glb_pht [GLB_PHT_DEPHT-1:0];
    logic [GLB_N_BIT_SCHEME-1:0] glb_pht_entry_read;
    logic [GLB_N_BIT_SCHEME-1:0] glb_pht_entry_write, glb_pht_entry_next;
    logic [GLB_PHT_ADDR_W-1:0]   glb_pht_idx_read;
    logic [GLB_PHT_ADDR_W-1:0]   glb_pht_idx_write;

   // Global history register 
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
           ghr <= '0;
        end
        else begin
           if(i_upd_pht_vld)  begin
            ghr <= {ghr[GLB_PHT_ADDR_W-2:0], i_upd_pht_taken};
           end
        end
    end

    assign glb_pht_idx_read = ghr ^ i_pc[PC_LOWER_UNUSED +: GLB_PHT_ADDR_W];
    always_comb begin
        glb_pht_entry_read = glb_pht[glb_pht_idx_read];
        glb_predict_taken  = glb_pht_entry_read[GLB_N_BIT_SCHEME-1]; // just need to MSB to determine branch or not
    end

        
    assign glb_pht_idx_write = ghr ^ i_upd_pht_pc[PC_LOWER_UNUSED +: GLB_PHT_ADDR_W];
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            for(int i=0; i<GLB_PHT_DEPHT; i++) begin
                glb_pht[i] <= '0; 
            end
        end    
        else begin
           if(i_upd_pht_vld) begin
            glb_pht[glb_pht_idx_write] <= glb_pht_entry_next;
           end
        end
    end

    always_comb begin
        glb_pht_entry_write = glb_pht[glb_pht_idx_write];
        if(i_upd_pht_taken)
            glb_pht_entry_next =  (glb_pht_entry_write != '1)? glb_pht_entry_write +  GLB_N_BIT_SCHEME'('d1)  : glb_pht_entry_write;
        else
            glb_pht_entry_next =  (glb_pht_entry_write != '0)? glb_pht_entry_write + {GLB_N_BIT_SCHEME{1'b1}} : glb_pht_entry_write; // minus 1
    end

//////////////////////////////////////////////////////////////////////////
// Local Predictor: n-bit scheme
////////////////////////////////////////////////////////////////////////// 
    localparam LOC_PHT_DEPHT = 2**LOC_PHT_ADDR_W;

    logic [LOC_PHT_ADDR_W-1:0]   loc_pht_idx_read;
    logic [LOC_PHT_ADDR_W-1:0]   loc_pht_idx_write;
    logic [LOC_N_BIT_SCHEME-1:0] loc_pht [LOC_PHT_DEPHT-1:0];
    logic [LOC_N_BIT_SCHEME-1:0] loc_pht_entry_read;
    logic [LOC_N_BIT_SCHEME-1:0] loc_pht_entry_write;
    logic [LOC_N_BIT_SCHEME-1:0] loc_pht_entry_next;

    assign loc_pht_idx_read = i_pc[PC_LOWER_UNUSED +: LOC_PHT_ADDR_W];
    always_comb begin
        loc_pht_entry_read  = loc_pht[loc_pht_idx_read];
        loc_predict_taken   = loc_pht_entry_read[LOC_N_BIT_SCHEME-1]; // just need to MSB to determine branch or not
    end

    assign loc_pht_idx_write = i_upd_pht_pc[PC_LOWER_UNUSED +: LOC_PHT_ADDR_W];
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            for(int i=0; i<LOC_PHT_DEPHT; i++) begin
                loc_pht[i] <= '0; 
            end
        end    
        else begin
           if(i_upd_pht_vld) begin
            loc_pht[loc_pht_idx_write] <= loc_pht_entry_next;
           end
        end
    end   

    always_comb begin
        loc_pht_entry_write = loc_pht[loc_pht_idx_write];
        if(i_upd_pht_taken)
            loc_pht_entry_next =  (loc_pht_entry_write != '1)? loc_pht_entry_write +  LOC_N_BIT_SCHEME'('d1)  : loc_pht_entry_write;
        else
            loc_pht_entry_next =  (loc_pht_entry_write != '0)? loc_pht_entry_write + {LOC_N_BIT_SCHEME{1'b1}} : loc_pht_entry_write; // minus 1
    end

endmodule
