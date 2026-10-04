`include "rv32i.svh"

module rv32i 
    import rv32i_pkg::*;
#(
    parameter INST_MEM_ADDR_W = 10, // FIXME: increase memsize 
    parameter MEM_TYPE = MEM_FLOP, // 0: flop-based, 1: sram-based
    parameter CACHE = 1,
    parameter ENABLE_FORWARDING = 1,
    parameter ENABLE_BRANCH_PREDICTION = 1
)
(
    // Global clock, acitve on the rising edge
      input  logic        i_clk
    // Global acitve reset
    , input  logic        i_rst_n
    // Debug program counter
    , output logic [31:0] o_pc_debug
    // Instruction valid
    , output logic        o_insn_vld
    // Output for driving red LEDs
    , output logic [31:0] o_io_ledr
    // Output for driving green LEDs
    , output logic [31:0] o_io_ledg
    // Output for driving 7-segment LED displays
    , output logic [6:0]  o_io_hex0
    , output logic [6:0]  o_io_hex1
    , output logic [6:0]  o_io_hex2
    , output logic [6:0]  o_io_hex3
    , output logic [6:0]  o_io_hex4
    , output logic [6:0]  o_io_hex5
    , output logic [6:0]  o_io_hex6
    , output logic [6:0]  o_io_hex7
    // Output for driving the LCD register
    , output logic [31:0] o_io_lcd
    // Input for switches
    , input  logic [31:0] i_io_sw
    // Input for buttons
    , input  logic [3:0]  i_io_btn

    // Write request to LCD: only for FPGA
    , output logic        o_lcd_vld
    // SRAM interface
    , output logic [17:0] SRAM_ADDR
    , inout  wire  [15:0] SRAM_DQ  
    , output logic        SRAM_CE_N
    , output logic        SRAM_WE_N
    , output logic        SRAM_LB_N
    , output logic        SRAM_UB_N
    , output logic        SRAM_OE_N
);
//////////////////////////////////////////////////////////////////////////
// Declaration
//////////////////////////////////////////////////////////////////////////
    // Instruction Fetch
    IF_ID_DReg_s IF_ID_dreg_d, IF_ID_dreg_q, IF_ID_dreg_rstval;
    IF_ID_CReg_s IF_ID_creg_d, IF_ID_creg_q;
    logic IF_ID_dreg_en, IF_ID_creg_en, IF_ID_flush;
    logic [REGIDX_WIDTH-1:0] ID_rs1_addr;
    logic [REGIDX_WIDTH-1:0] ID_rs2_addr;

    // Instruction Decode
    ID_EX_DReg_s ID_EX_dreg_d, ID_EX_dreg_q;
    ID_EX_CReg_s ID_EX_creg_d, ID_EX_creg_q;
    logic ID_EX_dreg_en, ID_EX_creg_en, ID_EX_flush;
    logic [31:0] ID_pc_imm;
    /* verilator lint_off UNUSEDSIGNAL */
    logic ID_is_btb_miss;
    /* verilator lint_on UNUSEDSIGNAL */
    logic ID_is_jal_inst;

    // Execution
    EX_MEM_DReg_s EX_MEM_dreg_d, EX_MEM_dreg_q;
    EX_MEM_CReg_s EX_MEM_creg_d, EX_MEM_creg_q;
    logic EX_MEM_dreg_en, EX_MEM_creg_en, EX_MEM_flush;
    logic [31:0] EX_alu_res;
    logic        EX_is_pred_wrong;
    logic        EX_is_jalr_inst;
    logic        EX_actual_taken;

    // Mem Access
    MEM_WB_DReg_s MEM_WB_dreg_d, MEM_WB_dreg_q;
    MEM_WB_CReg_s MEM_WB_creg_d, MEM_WB_creg_q;
    logic MEM_WB_dreg_en, MEM_WB_creg_en, MEM_WB_flush;

    // Write Back
    logic [31:0] wb_res;

//////////////////////////////////////////////////////////////////////////
// Hazard
//////////////////////////////////////////////////////////////////////////
logic       pc_en;
logic       EX_is_depend_load;
EXFwdSel_e  EX_fwd_rs1_sel;
EXFwdSel_e  EX_fwd_rs2_sel;
logic       lsu_READY;
logic       is_fwd_from_WB_to_EX;

hazard_ctrl hazard_ctrl(
  .i_is_pred_taken   (1'b0                   ),           
  .i_is_jal_inst     (ID_is_jal_inst         ),          
  .i_lsu_VALID       (EX_MEM_creg_q.lsu_VALID),        
  .i_lsu_READY       (lsu_READY              ),        
  .i_is_depend_load  (EX_is_depend_load      ),          
  .i_is_pred_wrong   (EX_is_pred_wrong       ),            
  .i_is_jalr_inst    (EX_is_jalr_inst        ),           
  .i_is_fwd_from_WB_to_EX(is_fwd_from_WB_to_EX),

  .o_pc_en           (pc_en         ), 

  .o_IF_ID_dreg_en   (IF_ID_dreg_en ),         
  .o_IF_ID_creg_en   (IF_ID_creg_en ),         
  .o_IF_ID_flush     (IF_ID_flush   ),       
                      
  .o_ID_EX_dreg_en   (ID_EX_dreg_en ),         
  .o_ID_EX_creg_en   (ID_EX_creg_en ),         
  .o_ID_EX_flush     (ID_EX_flush   ),       
                      
  .o_EX_MEM_dreg_en  (EX_MEM_dreg_en),          
  .o_EX_MEM_creg_en  (EX_MEM_creg_en),          
  .o_EX_MEM_flush    (EX_MEM_flush  ),        
                      
  .o_MEM_WB_dreg_en  (MEM_WB_dreg_en),          
  .o_MEM_WB_creg_en  (MEM_WB_creg_en),          
  .o_MEM_WB_flush    (MEM_WB_flush  )        
);

always_comb begin
    if (ENABLE_FORWARDING) begin
        if     (EX_MEM_creg_q.reg_wen & (|EX_MEM_dreg_q.rd_addr) & (ID_EX_dreg_q.rs1_addr == EX_MEM_dreg_q.rd_addr))
            EX_fwd_rs1_sel = EX_FWD_EX_MEM;
        else if(MEM_WB_creg_q.reg_wen & (|MEM_WB_dreg_q.rd_addr) & (ID_EX_dreg_q.rs1_addr == MEM_WB_dreg_q.rd_addr))
            EX_fwd_rs1_sel = EX_FWD_MEM_WB;
        else
            EX_fwd_rs1_sel = EX_FWD_NA;

        if     (EX_MEM_creg_q.reg_wen & (|EX_MEM_dreg_q.rd_addr) & (ID_EX_dreg_q.rs2_addr == EX_MEM_dreg_q.rd_addr))
            EX_fwd_rs2_sel = EX_FWD_EX_MEM;
        else if(MEM_WB_creg_q.reg_wen & (|MEM_WB_dreg_q.rd_addr) & (ID_EX_dreg_q.rs2_addr == MEM_WB_dreg_q.rd_addr))
            EX_fwd_rs2_sel = EX_FWD_MEM_WB;
        else
            EX_fwd_rs2_sel = EX_FWD_NA;

        is_fwd_from_WB_to_EX = (EX_fwd_rs2_sel == EX_FWD_MEM_WB) | (EX_fwd_rs1_sel == EX_FWD_MEM_WB);
        EX_is_depend_load = ID_EX_creg_q.lsu_VALID & ~ID_EX_creg_q.st_mem & (|ID_EX_dreg_q.rd_addr)
                          & ((ID_EX_dreg_q.rd_addr == ID_rs1_addr) | (ID_EX_dreg_q.rd_addr == ID_rs2_addr));
    end else begin
        EX_fwd_rs1_sel = EX_FWD_NA;
        EX_fwd_rs2_sel = EX_FWD_NA;
        is_fwd_from_WB_to_EX = 1'b0;
        EX_is_depend_load =
            (ID_EX_creg_q.reg_wen & (|ID_EX_dreg_q.rd_addr)
             & ((ID_EX_dreg_q.rd_addr == ID_rs1_addr) | (ID_EX_dreg_q.rd_addr == ID_rs2_addr))) |
            (EX_MEM_creg_q.reg_wen & (|EX_MEM_dreg_q.rd_addr)
             & ((EX_MEM_dreg_q.rd_addr == ID_rs1_addr) | (EX_MEM_dreg_q.rd_addr == ID_rs2_addr))) |
            (MEM_WB_creg_q.reg_wen & (|MEM_WB_dreg_q.rd_addr)
             & ((MEM_WB_dreg_q.rd_addr == ID_rs1_addr) | (MEM_WB_dreg_q.rd_addr == ID_rs2_addr)));
    end

    // if     (MEM_WB_creg_q.reg_wen & (|MEM_WB_dreg_q.rd_addr) & (EX_MEM_dreg_q.rs2_addr == MEM_WB_dreg_q.rd_addr))
    //     MEM_fwd_rs2_sel = MEM_FWD_MEM_WB;
    // else
    //     MEM_fwd_rs2_sel = MEM_FWD_NA;
    // MEM_lsu_fwd_st = MEM_fwd_rs2_sel == MEM_FWD_MEM_WB;

end


//////////////////////////////////////////////////////////////////////////
// Instruction Fetch (IF)
//////////////////////////////////////////////////////////////////////////
logic [31:0] pc;
logic [31:0] next_pred_pc;
logic [31:0] inst;
PCSel_e      pc_sel;
logic is_pred_hit;
logic is_pred_taken;
/* verilator lint_off UNUSEDSIGNAL */
logic upd_btb_vld;
logic upd_pht_vld;
logic upd_eval_vld;
/* verilator lint_on UNUSEDSIGNAL */
logic is_glb_taken, is_loc_taken;

assign o_pc_debug = pc;

always_ff @( posedge i_clk ) begin
    if(~i_rst_n) begin
        pc <= '0; 
    end 
    else begin
        if(pc_en) begin
            case (pc_sel)
                PC_IF_PRED: pc <= next_pred_pc;        // br, predict branch, if not a br inst -> no hit -> PC+4
                PC_ID_JAL : pc <= ID_pc_imm;           // jal, jump address
                PC_EX_ALU : pc <= EX_alu_res;          // jalr, actual branch
                PC_EX_4   : pc <= ID_EX_dreg_q.pc + 4; // jalr, actual branch
                default   : pc <= pc;
            endcase
        end
        else begin
            pc <= pc;
        end
    end
end

always_comb begin
    if(EX_is_jalr_inst) begin // highest priority
        pc_sel = PC_EX_ALU;
    end
    else if(EX_is_pred_wrong) begin
        pc_sel = (ID_EX_creg_q.is_pred_taken)? PC_EX_4 : PC_EX_ALU; 
    end
    else if(ID_is_jal_inst) begin
        pc_sel = PC_ID_JAL;
    end
    else begin
        pc_sel = PC_IF_PRED;
    end
end

inst_mem #(
    .ADDR_W(INST_MEM_ADDR_W)
) inst_mem (
    .i_addr(INST_MEM_ADDR_W'(pc)),
    .o_inst(inst                )
);

generate
if (ENABLE_BRANCH_PREDICTION) begin: g_branch_prediction
assign upd_btb_vld  = ID_is_btb_miss           & ID_EX_creg_en  & ~ID_EX_flush;
assign upd_eval_vld = ID_EX_creg_q.is_pred_hit & EX_MEM_creg_en & ~EX_MEM_flush;
assign upd_pht_vld  = ID_EX_creg_q.is_br_inst  & EX_MEM_creg_en & ~EX_MEM_flush;
tournament #(
    .PC_WIDTH    (32), 
    .INST_WIDTH  (32), 
    .PRED_STRATEGY(PRED_BOTH),
    .BTB_ADDR_W  (8 ), // BTB: branch table buffer. Increase this will increase hit rate
    .EVAL_N_BIT_SCHEME(3), // N-bit saturated counter. Increase this will increase hesitation when changing from global to local or vice versa
    .GLB_PHT_ADDR_W  (7 ), // PHT: pattern history table. Increase this will increase accuracy 
    .GLB_N_BIT_SCHEME(2 ), // N-bit saturated counter
    .LOC_PHT_ADDR_W  (8 ), // PHT: pattern history table. Increase this will increase accuracy 
    .LOC_N_BIT_SCHEME(2 )  // N-bit saturated counter
) branch_predictor (
    .i_clk            (i_clk           ), 
    .i_rst_n          (i_rst_n         ),   
                      
    .i_pc             (pc              ),
    .o_hit            (is_pred_hit     ), 
    .o_taken          (is_pred_taken   ),   
    .o_next_pc        (next_pred_pc    ),     
    .o_glb_taken      (is_glb_taken    ),
    .o_loc_taken      (is_loc_taken    ),
                      
    .i_upd_btb_vld    (upd_btb_vld     ),         
    .i_upd_btb_pc     (IF_ID_dreg_q.pc ),        
    .i_upd_btb_br_addr(ID_pc_imm       ),             
                      
    .i_upd_eval_vld   (upd_eval_vld    ),         
    .i_upd_pht_vld    (upd_pht_vld     ),         
    .i_upd_pht_pc     (ID_EX_dreg_q.pc ),        
    .i_upd_pht_taken  (EX_actual_taken ),
    .i_upd_pht_pred_glb_taken (ID_EX_creg_q.is_glb_taken),
    .i_upd_pht_pred_loc_taken (ID_EX_creg_q.is_loc_taken)
);
end else begin: g_static_not_taken
    assign upd_btb_vld = 1'b0;
    assign upd_eval_vld = 1'b0;
    assign upd_pht_vld = 1'b0;
    assign is_pred_hit = 1'b0;
    assign is_pred_taken = 1'b0;
    assign next_pred_pc = pc + 32'd4;
    assign is_glb_taken = 1'b0;
    assign is_loc_taken = 1'b0;
end
endgenerate

// IF/ID reg
always_comb begin
    IF_ID_dreg_d.pc   = pc; 
    IF_ID_dreg_d.inst = (IF_ID_flush)? NOP_INST : inst; 

    IF_ID_dreg_rstval = '0;
    IF_ID_dreg_rstval.inst = NOP_INST;

    IF_ID_creg_d.is_pred_taken = (IF_ID_flush)? '0: is_pred_taken;
    IF_ID_creg_d.is_pred_hit   = (IF_ID_flush)? '0: is_pred_hit;
    IF_ID_creg_d.is_glb_taken  = (IF_ID_flush)? '0: is_glb_taken;
    IF_ID_creg_d.is_loc_taken  = (IF_ID_flush)? '0: is_loc_taken;
end
`PRIM_FF_EN_RST(IF_ID_dreg_q, IF_ID_dreg_d, IF_ID_dreg_en, i_rst_n, i_clk, IF_ID_dreg_rstval)
`PRIM_FF_EN_RST(IF_ID_creg_q, IF_ID_creg_d, IF_ID_creg_en, i_rst_n, i_clk, '0)
//////////////////////////////////////////////////////////////////////////
// Instruction Decode (ID)
//////////////////////////////////////////////////////////////////////////
logic [REGIDX_WIDTH-1:0] rs1_addr;
logic [REGIDX_WIDTH-1:0] rs2_addr;
logic [REGIDX_WIDTH-1:0] rd_addr;
logic [31:0]             rs1_data;
logic [31:0]             rs2_data;

// control unit
ImmSel_e     imm_sel   ;  
logic        reg_wen   ;   
logic        is_br_inst;
logic        is_jp_inst;
logic        br_un     ; 
BSel_e       b_sel     ; 
ASel_e       a_sel     ; 
ALUSel_e     alu_sel   ;  
logic        st_mem    ;  
WBSel_e      wb_sel    ;  
logic        lsu_VALID ;
logic [31:0] imm;

control control(
    .i_inst     (IF_ID_dreg_q.inst),
    .o_imm_sel  (imm_sel          ),   
    .o_reg_wen  (reg_wen          ),   
    .o_is_br    (is_br_inst       ),
    .o_is_jp    (is_jp_inst       ),
    .o_br_un    (br_un            ), 
    .o_b_sel    (b_sel            ), 
    .o_a_sel    (a_sel            ), 
    .o_alu_sel  (alu_sel          ),   
    .o_st_mem   (st_mem           ),  
    .o_wb_sel   (wb_sel           ),  
    .o_insn_vld (o_insn_vld       ),
    .lsu_VALID  (lsu_VALID        ) 
);

assign rd_addr  = IF_ID_dreg_q.inst[11:7];
assign rs1_addr = IF_ID_dreg_q.inst[19:15];
assign rs2_addr = IF_ID_dreg_q.inst[24:20];
assign ID_rs1_addr = rs1_addr;
assign ID_rs2_addr = rs2_addr;

regfile regfile(
    .i_clk     (i_clk                 ),   
    .i_rst_n   (i_rst_n               ),   
              
    .i_rs1_addr(rs1_addr              ),    
    .i_rs2_addr(rs2_addr              ),    
    .i_rd_addr (MEM_WB_dreg_q.rd_addr ),   
    .i_rd_wen  (MEM_WB_creg_q.reg_wen ),
    .i_rd_data (wb_res                ),  
              
    .o_rs1_data(rs1_data              ),  
    .o_rs2_data(rs2_data              )   
);

always_comb begin
    case(imm_sel)
        IMM_I: imm = {{21{IF_ID_dreg_q.inst[31]}}, IF_ID_dreg_q.inst[30:20]};
        IMM_S: imm = {{21{IF_ID_dreg_q.inst[31]}}, IF_ID_dreg_q.inst[30:25], IF_ID_dreg_q.inst[11:7]};
        IMM_B: imm = {{20{IF_ID_dreg_q.inst[31]}}, IF_ID_dreg_q.inst[7], IF_ID_dreg_q.inst[30:25], IF_ID_dreg_q.inst[11:8], 1'b0};
        IMM_U: imm = {IF_ID_dreg_q.inst[31], IF_ID_dreg_q.inst[30:20], IF_ID_dreg_q.inst[19:12], {12{1'b0}}};
        IMM_J: imm = {{12{IF_ID_dreg_q.inst[31]}}, IF_ID_dreg_q.inst[19:12], IF_ID_dreg_q.inst[20], IF_ID_dreg_q.inst[30:25], IF_ID_dreg_q.inst[24:21], 1'b0};
        default: imm = '0;
    endcase
end

always_comb begin
    ID_pc_imm      = IF_ID_dreg_q.pc + imm;
    ID_is_btb_miss = is_br_inst & ~IF_ID_creg_q.is_pred_hit; // Miss when it is a branch inst but hasnt exist in BTB
    ID_is_jal_inst = is_jp_inst & (a_sel == A_PC); 
end

// ID/EX reg
always_comb begin
    ID_EX_dreg_d.pc       = IF_ID_dreg_q.pc; 
    ID_EX_dreg_d.inst     = IF_ID_dreg_q.inst; 
    ID_EX_dreg_d.rs1_data = rs1_data; 
    ID_EX_dreg_d.rs2_data = rs2_data; 
    ID_EX_dreg_d.rs1_addr = rs1_addr; 
    ID_EX_dreg_d.rs2_addr = rs2_addr; 
    ID_EX_dreg_d.rd_addr  = rd_addr; 
    ID_EX_dreg_d.imm      = imm; 

    ID_EX_creg_d.reg_wen       = (ID_EX_flush)? 1'b0         : reg_wen;
    ID_EX_creg_d.lsu_VALID     = (ID_EX_flush)? 1'b0         : lsu_VALID;
    ID_EX_creg_d.is_br_inst    = (ID_EX_flush)? 1'b0         : is_br_inst;
    ID_EX_creg_d.is_jp_inst    = (ID_EX_flush)? 1'b0         : is_jp_inst;
    ID_EX_creg_d.is_pred_taken = (ID_EX_flush)? '0           : IF_ID_creg_q.is_pred_taken;
    ID_EX_creg_d.is_pred_hit   = (ID_EX_flush)? '0           : IF_ID_creg_q.is_pred_hit;
    ID_EX_creg_d.is_glb_taken  = (ID_EX_flush)? '0           : IF_ID_creg_q.is_glb_taken;
    ID_EX_creg_d.is_loc_taken  = (ID_EX_flush)? '0           : IF_ID_creg_q.is_loc_taken;
    ID_EX_creg_d.st_mem        = (ID_EX_flush)? '0           : st_mem ;
    ID_EX_creg_d.br_un         = (ID_EX_flush)? '0           : br_un  ;
    ID_EX_creg_d.b_sel         = (ID_EX_flush)? BSel_e'(0)   : b_sel  ;
    ID_EX_creg_d.a_sel         = (ID_EX_flush)? ASel_e'(0)   : a_sel  ;
    ID_EX_creg_d.alu_sel       = (ID_EX_flush)? ALUSel_e'(0) : alu_sel;
    ID_EX_creg_d.wb_sel        = (ID_EX_flush)? WBSel_e'(0)  : wb_sel ;
    ID_EX_creg_d.is_inst_vld   = (ID_EX_flush)? 1'b0         : o_insn_vld;
end
`PRIM_FF_EN_RST(ID_EX_dreg_q, ID_EX_dreg_d, ID_EX_dreg_en, i_rst_n, i_clk, '0)
`PRIM_FF_EN_RST(ID_EX_creg_q, ID_EX_creg_d, ID_EX_creg_en, i_rst_n, i_clk, '0)
//////////////////////////////////////////////////////////////////////////
// Execution (EX)
//////////////////////////////////////////////////////////////////////////
logic [31:0] a_operand;
logic [31:0] b_operand;
logic        br_eq;
logic        br_lt;
logic [31:0] alu_res;
logic [31:0] EX_fwd_rs1_data;
logic [31:0] EX_fwd_rs2_data;

always_comb begin
    case (EX_fwd_rs1_sel)
        EX_FWD_EX_MEM: EX_fwd_rs1_data = EX_MEM_dreg_q.alu_res;
        EX_FWD_MEM_WB: EX_fwd_rs1_data = wb_res;
        EX_FWD_NA    : EX_fwd_rs1_data = ID_EX_dreg_q.rs1_data;
        default      : EX_fwd_rs1_data = '0; 
    endcase
    case (EX_fwd_rs2_sel)
        EX_FWD_EX_MEM: EX_fwd_rs2_data = EX_MEM_dreg_q.alu_res;
        EX_FWD_MEM_WB: EX_fwd_rs2_data = wb_res;
        EX_FWD_NA    : EX_fwd_rs2_data = ID_EX_dreg_q.rs2_data;
        default      : EX_fwd_rs2_data = '0; 
    endcase

    case (ID_EX_creg_q.a_sel)
        A_REG:   a_operand = EX_fwd_rs1_data;
        A_PC:    a_operand = ID_EX_dreg_q.pc;
        A_ZERO:  a_operand = '0;
        default: a_operand = '0;
    endcase

    case (ID_EX_creg_q.b_sel)
        B_REG  : b_operand = EX_fwd_rs2_data;
        B_IMM  : b_operand = ID_EX_dreg_q.imm;
        default: b_operand = '0;
    endcase
end

alu alu(
    .i_operand_a  (a_operand           ),   
    .i_operand_b  (b_operand           ),   
    .i_alu_op     (ID_EX_creg_q.alu_sel),
    .o_alu_res    (alu_res             )  
);
assign EX_alu_res = alu_res;

branch_comp branch_comp(
    .i_rs1_data(EX_fwd_rs1_data    ), 
    .i_rs2_data(EX_fwd_rs2_data    ), 
    .i_br_un   (ID_EX_creg_q.br_un), 
    .o_br_eq   (br_eq             ),
    .o_br_lt   (br_lt             )   
);

always_comb begin
    if(ID_EX_dreg_q.inst[14]) begin
        EX_actual_taken  = ID_EX_dreg_q.inst[12] ^ br_lt;
    end
    else begin
        EX_actual_taken  = ID_EX_dreg_q.inst[12] ^ br_eq;
    end
    EX_is_pred_wrong = (ID_EX_creg_q.is_br_inst)? EX_actual_taken ^ ID_EX_creg_q.is_pred_taken : 1'b0;
    EX_is_jalr_inst = ID_EX_creg_q.is_jp_inst & (ID_EX_creg_q.a_sel == A_REG);
end

// EX/MEM reg
always_comb begin
    EX_MEM_dreg_d.pc       = ID_EX_dreg_q.pc;
    EX_MEM_dreg_d.inst     = ID_EX_dreg_q.inst; 
    EX_MEM_dreg_d.rd_addr  = ID_EX_dreg_q.rd_addr; 
    EX_MEM_dreg_d.rs2_data = EX_fwd_rs2_data; 
    EX_MEM_dreg_d.rs2_addr = ID_EX_dreg_q.rs2_addr; 
    EX_MEM_dreg_d.alu_res  = alu_res; 

    EX_MEM_creg_d.reg_wen         = (EX_MEM_flush)? 1'b0        : ID_EX_creg_q.reg_wen;
    EX_MEM_creg_d.lsu_VALID       = (EX_MEM_flush)? 1'b0        : ID_EX_creg_q.lsu_VALID;
    // EX_MEM_creg_d.is_jalr_inst    = (EX_MEM_flush)? 1'b0        : EX_is_jalr_inst;
    // EX_MEM_creg_d.is_pred_wrong   = (EX_MEM_flush)? 1'b0        : EX_is_pred_wrong;
    // EX_MEM_creg_d.is_pred_taken = (EX_MEM_flush)? 1'b0        : ID_EX_creg_q.is_pred_taken;
    EX_MEM_creg_d.st_mem          = (EX_MEM_flush)? 1'b0        : ID_EX_creg_q.st_mem;
    EX_MEM_creg_d.wb_sel          = (EX_MEM_flush)? WBSel_e'(0) : ID_EX_creg_q.wb_sel;
    EX_MEM_creg_d.is_inst_vld     = (EX_MEM_flush)? 1'b0        : ID_EX_creg_q.is_inst_vld;
end
`PRIM_FF_EN_RST(EX_MEM_dreg_q, EX_MEM_dreg_d, EX_MEM_dreg_en,i_rst_n, i_clk, '0)
`PRIM_FF_EN_RST(EX_MEM_creg_q, EX_MEM_creg_d, EX_MEM_creg_en,i_rst_n, i_clk, '0)

//////////////////////////////////////////////////////////////////////////
// Memory Access (MEM)
//////////////////////////////////////////////////////////////////////////
logic [3:0]  st_strb;
logic [31:0] ld_data_raw;
logic [31:0] st_data;
logic [31:0] ld_data;
// logic [31:0] MEM_fwd_rs2_data;
logic vld_data_mem;

// assign MEM_fwd_rs2_data = (MEM_fwd_rs2_sel == MEM_FWD_MEM_WB)? wb_res : EX_MEM_dreg_q.rs2_data;

lsu_dat_handler lsu_dat_handler(
   .i_funct3  (EX_MEM_dreg_q.inst[14:12] ), 
   .i_lsb_addr(EX_MEM_dreg_q.alu_res[1:0]),

//    .i_st_data (MEM_fwd_rs2_data          ),  
   .i_st_data (EX_MEM_dreg_q.rs2_data    ),  
   .o_st_data (st_data                   ),  
   .o_st_strb (st_strb                   ),  

   .i_ld_data (ld_data_raw               ),  
   .o_ld_data (ld_data                   )  
);

lsu #(
    .MEM_TYPE(MEM_TYPE),
    .CACHE   (CACHE   )
) lsu (
    .i_clk     (i_clk  ),   
    .i_rst_n   (i_rst_n),    

    .i_lsu_addr(EX_MEM_dreg_q.alu_res  ),  
    .i_st_data (st_data                ), 
    .i_st_strb (st_strb                ),
    .i_lsu_wren(EX_MEM_creg_q.st_mem   ), 
    .o_ld_data (ld_data_raw            ),
    .o_lcd_vld (o_lcd_vld              ),
    .i_VALID   (EX_MEM_creg_q.lsu_VALID),
    .o_READY   (lsu_READY              ),

    .o_io_ledr (o_io_ledr              ),
    .o_io_ledg (o_io_ledg              ),
    .o_io_hex0 (o_io_hex0              ),
    .o_io_hex1 (o_io_hex1              ),
    .o_io_hex2 (o_io_hex2              ),
    .o_io_hex3 (o_io_hex3              ),
    .o_io_hex4 (o_io_hex4              ),
    .o_io_hex5 (o_io_hex5              ),
    .o_io_hex6 (o_io_hex6              ),
    .o_io_hex7 (o_io_hex7              ),
    .o_io_lcd  (o_io_lcd               ),  
    .i_io_sw   (i_io_sw                ),  
    .i_io_btn  (i_io_btn               ),   

    .SRAM_ADDR (SRAM_ADDR              ),      
    .SRAM_DQ   (SRAM_DQ                ),      
    .SRAM_CE_N (SRAM_CE_N              ),      
    .SRAM_WE_N (SRAM_WE_N              ),      
    .SRAM_LB_N (SRAM_LB_N              ),      
    .SRAM_UB_N (SRAM_UB_N              ),      
    .SRAM_OE_N (SRAM_OE_N              ),

    .vld_data_mem (vld_data_mem) // for evaluation  
);



// MEM/WB reg
always_comb begin
    MEM_WB_dreg_d.pc       = EX_MEM_dreg_q.pc;
    MEM_WB_dreg_d.inst     = EX_MEM_dreg_q.inst; 
    MEM_WB_dreg_d.rd_addr  = EX_MEM_dreg_q.rd_addr; 
    MEM_WB_dreg_d.ld_data  = ld_data; 
    MEM_WB_dreg_d.alu_res  = EX_MEM_dreg_q.alu_res; 

    MEM_WB_creg_d.reg_wen     = (MEM_WB_flush)? 1'b0        : EX_MEM_creg_q.reg_wen;
    MEM_WB_creg_d.wb_sel      = (MEM_WB_flush)? WBSel_e'(0) : EX_MEM_creg_q.wb_sel ;
    MEM_WB_creg_d.is_inst_vld = (MEM_WB_flush)? 1'b0        : EX_MEM_creg_q.is_inst_vld;
end
`PRIM_FF_EN_RST(MEM_WB_dreg_q, MEM_WB_dreg_d, MEM_WB_dreg_en,i_rst_n, i_clk, '0)
`PRIM_FF_EN_RST(MEM_WB_creg_q, MEM_WB_creg_d, MEM_WB_creg_en,i_rst_n, i_clk, '0)
//////////////////////////////////////////////////////////////////////////
// Write Back (WB)
//////////////////////////////////////////////////////////////////////////


always_comb begin 
    case (MEM_WB_creg_q.wb_sel)
        WB_PC:   wb_res = 32'(MEM_WB_dreg_q.pc + 32'('d4)); 
        WB_ALU:  wb_res = MEM_WB_dreg_q.alu_res;
        WB_MEM:  wb_res = MEM_WB_dreg_q.ld_data;
        default: wb_res = '0;
    endcase 
end

//////////////////////////////////////////////////////////////////////////
// Evaluation
//////////////////////////////////////////////////////////////////////////

evaluation #(
    .BR_THRSH_EVAL  (1000),
    .IPC_THRSH_EVAL (1000),
    .MEM_PEN_THRSH_EVAL (100)
) evaluation (
    .i_clk               (i_clk  ),       
    .i_rst_n             (i_rst_n), 
                          
    .i_is_br_inst        (ID_EX_creg_q.is_br_inst),     
    .i_is_br_pred_correct(~EX_is_pred_wrong      ),
    /* verilator lint_off PINCONNECTEMPTY */
    .o_br_correct_eval   (),   
    /* verilator lint_off PINCONNECTEMPTY */
                          
    .i_is_inst_vld       (MEM_WB_creg_q.is_inst_vld), // If flush exists at a stage, vld = 0 -> NOP will be counted as invalid 
    .i_is_inst_done      (MEM_WB_creg_en           ),    
    /* verilator lint_off PINCONNECTEMPTY */
    .o_ipc_eval          (),     
    /* verilator lint_off PINCONNECTEMPTY */

    .i_lsu_valid (EX_MEM_creg_q.lsu_VALID & vld_data_mem),
    .i_lsu_ready (lsu_READY),
    /* verilator lint_off PINCONNECTEMPTY */
    .o_mem_pen   ()
    /* verilator lint_off PINCONNECTEMPTY */
);

endmodule
