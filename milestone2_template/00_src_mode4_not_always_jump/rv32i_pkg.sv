`ifndef  RV32IPKG_SV
`define RV32IPKG_SV
`timescale 1ns/1ps

package rv32i_pkg;
  /* verilator lint_off UNUSEDPARAM */
    localparam FUNCT3_WIDTH = 3;
  /* verilator lint_off UNUSEDPARAM */
    localparam FUNCT7_WIDTH = 7;
  /* verilator lint_off UNUSEDPARAM */
  /* verilator lint_off UNUSEDPARAM */
    localparam OPCODE_WIDTH = 7;
  /* verilator lint_off UNUSEDPARAM */
    localparam REGIDX_WIDTH = 5;
  /* verilator lint_off UNUSEDPARAM */
    localparam IMM_WIDTH    = 5;
  /* verilator lint_off UNUSEDPARAM */

    // Base addresses
    localparam DATA_BASE_ADDR = 32'h0000_2000;
    localparam DATA_LAST_ADDR = 32'h0000_4000;
    // localparam DATA_LAST_ADDR  = 32'h0000_2100; // FIXME: for synthesis with block RAM
    localparam TIMER_BASE_ADDR = 32'h0000_4000; // 4 timers
    localparam LEDR_BASE_ADDR  = 32'h0000_7000;
    localparam LEDG_BASE_ADDR  = 32'h0000_7010;
    localparam SEG7_BASE_ADDR  = 32'h0000_7020;
    localparam LCD_BASE_ADDR   = 32'h0000_7030;
    localparam SW_BASE_ADDR    = 32'h0000_7800;
    localparam BTN_BASE_ADDR   = 32'h0000_7810;

    localparam MEM_FLOP = 0;
    localparam MEM_SRAM = 1;

    localparam NOP_INST = 32'h00000013; // addi x0 x0, 0

    typedef enum logic[1:0] { 
        A_REG  = 2'd0,
        A_PC   = 2'd1,
        A_ZERO = 2'd2
    } ASel_e;
    localparam ASEL_W = $bits(ASel_e);

    typedef enum logic { 
        B_REG  = 1'd0,
        B_IMM  = 1'd1
    } BSel_e;
    localparam BSEL_W = $bits(BSel_e);

    typedef enum logic[3:0] { 
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

    typedef enum logic [1:0] { 
        PC_IF_PRED   = 2'd0,
        PC_ID_JAL = 2'd1,
        PC_EX_ALU = 2'd2,
        PC_EX_4   = 2'd3
    } PCSel_e;
  /* verilator lint_off UNUSEDPARAM */
    localparam PCSEL_W = $bits(PCSel_e);
  /* verilator lint_off UNUSEDPARAM */

    typedef enum logic [1:0] { 
        EX_FWD_NA     = 2'd0,
        EX_FWD_EX_MEM = 2'd1,
        EX_FWD_MEM_WB = 2'd2
    } EXFwdSel_e;
  /* verilator lint_off UNUSEDPARAM */
    localparam EXFWDSEL_W = $bits(EXFwdSel_e);
  /* verilator lint_off UNUSEDPARAM */

     typedef enum logic { 
        MEM_FWD_NA     = 1'd0,
        MEM_FWD_MEM_WB = 1'd1
     } MEMFwdSel_e;
  /* verilator lint_off UNUSEDPARAM */
    localparam MEMFWDSEL_W = $bits(MEMFwdSel_e);
  /* verilator lint_off UNUSEDPARAM */   

    typedef enum logic [1:0] { 
        PRED_NONE = 2'b00, // always taken
        PRED_LOC  = 2'b01, // use local prediction
        PRED_GLB  = 2'b10, // use global prediction
        PRED_BOTH = 2'b11  // use both prediction types
    } PreStrategy_e;

   //---------------------------
   // 7-SEG display control
   //---------------------------
   function [6:0] bcd_to_7seg;
      input [3:0] bcd;

      case(bcd)
         4'h0: bcd_to_7seg = 7'b1000000;
         4'h1: bcd_to_7seg = 7'b1111001;	
         4'h2: bcd_to_7seg = 7'b0100100; 	
         4'h3: bcd_to_7seg = 7'b0110000; 	
         4'h4: bcd_to_7seg = 7'b0011001; 	
         4'h5: bcd_to_7seg = 7'b0010010; 	
         4'h6: bcd_to_7seg = 7'b0000010; 	
         4'h7: bcd_to_7seg = 7'b1111000; 	
         4'h8: bcd_to_7seg = 7'b0000000; 	
         4'h9: bcd_to_7seg = 7'b0011000; 	
         4'ha: bcd_to_7seg = 7'b0001000;
         4'hb: bcd_to_7seg = 7'b0000011;
         4'hc: bcd_to_7seg = 7'b1000110;
         4'hd: bcd_to_7seg = 7'b0100001;
         4'he: bcd_to_7seg = 7'b0000110;
         4'hf: bcd_to_7seg = 7'b0001110;
         default: bcd_to_7seg = '0; // No benefit if adding this line, just to make sure it will not generate latch if not enough cases. Safety first :)
      endcase      
   endfunction // End 7-SEG display control

    // Struct
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
      logic    st_mem ;  
      logic    br_un  ; 
      BSel_e   b_sel  ; 
      ASel_e   a_sel  ; 
      ALUSel_e alu_sel;  
      WBSel_e  wb_sel ;  
      logic    is_pred_taken;
      logic    is_pred_hit;
      logic    is_glb_taken;
      logic    is_loc_taken;
      logic    is_inst_vld; // for evaluation
    } ID_EX_CReg_s;
    typedef struct packed {
      logic    reg_wen;   
      logic    lsu_VALID;
      // logic    is_pred_wrong;
      // logic    is_pred_taken;
      // logic    is_jalr_inst;
      logic    st_mem ;  
      WBSel_e  wb_sel ;  
      logic    is_inst_vld; // for evaluation
    } EX_MEM_CReg_s;
    typedef struct packed {
      logic    reg_wen;   
      WBSel_e  wb_sel ;  
      logic    is_inst_vld; // for evaluation
    } MEM_WB_CReg_s;


endpackage

`endif 
