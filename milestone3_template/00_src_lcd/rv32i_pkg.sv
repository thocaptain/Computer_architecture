// =============================================================================
// Package Name:  rv32i_pkg
// Project:       Milestone 3 - Simple MCU
// Description:   Shared RV32I constants, control types and inherited pipeline types.
// =============================================================================

`ifndef RV32IPKG_SV
`define RV32IPKG_SV
`timescale 1ns / 1ps

package rv32i_pkg;
    // =========================================================================
    // Instruction and Register Widths
    // =========================================================================

    localparam FUNCT3_WIDTH = 3;
    localparam FUNCT7_WIDTH = 7;
    localparam OPCODE_WIDTH = 7;
    localparam REGIDX_WIDTH = 5;
    localparam IMM_WIDTH    = 5;

    localparam NOP_INST = 32'h00000013; // addi x0 x0, 0

    // =========================================================================
    // Datapath Control Types
    // =========================================================================
    typedef enum logic [1:0] {
        A_REG  = 2'd0,
        A_PC   = 2'd1,
        A_ZERO = 2'd2
    } ASel_e;
    localparam ASEL_W = $bits(ASel_e);

    typedef enum logic {
        B_REG = 1'd0,
        B_IMM = 1'd1
    } BSel_e;
    localparam BSEL_W = $bits(BSel_e);

    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_XOR  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_AND  = 4'd4,
        ALU_SLL  = 4'd5,
        ALU_SRL  = 4'd6,
        ALU_SRA  = 4'd7,
        ALU_SLT  = 4'd8,
        ALU_SLTU = 4'd9
    } ALUSel_e;
    localparam ALUSEL_W = $bits(ALUSel_e);

    typedef enum logic [1:0] {
        WB_ALU = 2'd0,
        WB_MEM = 2'd1,
        WB_PC  = 2'd2
    } WBSel_e;
    localparam WBSEL_W = $bits(WBSel_e);

    typedef enum logic [2:0] {
        IMM_I = 3'd0,
        IMM_S = 3'd1,
        IMM_B = 3'd2,
        IMM_J = 3'd3,
        IMM_U = 3'd4
    } ImmSel_e;
    localparam IMMSEL_W = $bits(ImmSel_e);

    // =========================================================================
    // Inherited Pipeline and Prediction Types
    // =========================================================================
    typedef enum logic [1:0] {
        PC_IF_PRED = 2'd0,
        PC_ID_JAL  = 2'd1,
        PC_EX_ALU  = 2'd2,
        PC_EX_4    = 2'd3
    } PCSel_e;

    localparam PCSEL_W = $bits(PCSel_e);

    typedef enum logic [1:0] {
        EX_FWD_NA     = 2'd0,
        EX_FWD_EX_MEM = 2'd1,
        EX_FWD_MEM_WB = 2'd2
    } EXFwdSel_e;

    localparam EXFWDSEL_W = $bits(EXFwdSel_e);

    typedef enum logic {
        MEM_FWD_NA     = 1'd0,
        MEM_FWD_MEM_WB = 1'd1
    } MEMFwdSel_e;

    localparam MEMFWDSEL_W = $bits(MEMFwdSel_e);

    typedef enum logic [1:0] {
        PRED_NONE = 2'b00, // always taken
        PRED_LOC  = 2'b01, // use local prediction
        PRED_GLB  = 2'b10, // use global prediction
        PRED_BOTH = 2'b11  // use both prediction types
    } PreStrategy_e;


    // =========================================================================
    // Inherited Pipeline Register Types
    // =========================================================================
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] inst;
    } IF_ID_DReg_s;

    typedef struct packed {
        logic [31:0]             pc;
        logic [31:0]             inst;
        logic [31:0]             rs1_data;
        logic [31:0]             rs2_data;
        logic [REGIDX_WIDTH-1:0] rs1_addr;
        logic [REGIDX_WIDTH-1:0] rs2_addr;
        logic [REGIDX_WIDTH-1:0] rd_addr;
        logic [31:0]             imm;
    } ID_EX_DReg_s;

    typedef struct packed {
        logic [31:0]             pc;
        logic [31:0]             inst;
        logic [31:0]             alu_res;
        logic [31:0]             rs2_data;
        logic [REGIDX_WIDTH-1:0] rd_addr;
        logic [REGIDX_WIDTH-1:0] rs2_addr;
    } EX_MEM_DReg_s;

    typedef struct packed {
        logic [31:0]              pc;
        logic [31:0]              inst;
        logic [31:0]              ld_data;
        logic [31:0]              alu_res;
        logic [REGIDX_WIDTH-1:0]  rd_addr;
    } MEM_WB_DReg_s;

    typedef struct packed {
        logic is_pred_taken;
        logic is_pred_hit;
        logic is_glb_taken;
        logic is_loc_taken;
    } IF_ID_CReg_s;

    typedef struct packed {
        logic    reg_wen;
        logic    lsu_VALID;
        logic    is_br_inst;
        logic    is_jp_inst;
        logic    st_mem;
        logic    br_un;
        BSel_e   b_sel;
        ASel_e   a_sel;
        ALUSel_e alu_sel;
        WBSel_e  wb_sel;
        logic    is_pred_taken;
        logic    is_pred_hit;
        logic    is_glb_taken;
        logic    is_loc_taken;
        logic    is_inst_vld; // for evaluation
    } ID_EX_CReg_s;

    typedef struct packed {
        logic   reg_wen;
        logic   lsu_VALID;
        // logic is_pred_wrong;
        // logic is_pred_taken;
        // logic is_jalr_inst;
        logic   st_mem;
        WBSel_e wb_sel;
        logic   is_inst_vld; // for evaluation
    } EX_MEM_CReg_s;

    typedef struct packed {
        logic   reg_wen;
        WBSel_e wb_sel;
        logic   is_inst_vld; // for evaluation
    } MEM_WB_CReg_s;

endpackage: rv32i_pkg

`endif
