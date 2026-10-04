module hazard_ctrl 
  import rv32i_pkg::*;
(
    input  logic i_is_pred_taken
  , input  logic i_is_jal_inst
  , input  logic i_lsu_VALID
  , input  logic i_lsu_READY
  , input  logic i_is_depend_load
  , input  logic i_is_pred_wrong
  , input  logic i_is_jalr_inst
  , input  logic i_is_fwd_from_WB_to_EX

  // hazard controls
  , output logic o_pc_en

  , output logic o_IF_ID_dreg_en
  , output logic o_IF_ID_creg_en
  , output logic o_IF_ID_flush

  , output logic o_ID_EX_dreg_en
  , output logic o_ID_EX_creg_en
  , output logic o_ID_EX_flush

  , output logic o_EX_MEM_dreg_en
  , output logic o_EX_MEM_creg_en
  , output logic o_EX_MEM_flush

  , output logic o_MEM_WB_dreg_en
  , output logic o_MEM_WB_creg_en
  , output logic o_MEM_WB_flush
);

// predict that need to branch at ID

logic [4:0] is_pred_taken_EN;
logic [4:0] is_pred_taken_FLUSH;

always_comb begin
  if(i_is_pred_taken) begin
    //                       PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_pred_taken_EN    = {1'b1 ,1'b1  ,1'b1  ,1'b1  ,1'b1}; 
    is_pred_taken_FLUSH = {1'b0 ,1'b1  ,1'b0  ,1'b0  ,1'b0}; 
  end
  else begin
    //                      
    is_pred_taken_EN    = '1; 
    is_pred_taken_FLUSH = '0; 
  end
end

// jump instruction at ID

logic [4:0] is_jal_inst_EN;
logic [4:0] is_jal_inst_FLUSH;

always_comb begin
  if(i_is_jal_inst) begin
    //                   PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_jal_inst_EN    = {1'b1 ,1'b1  ,1'b1  ,1'b1  ,1'b1}; 
    is_jal_inst_FLUSH = {1'b0 ,1'b1  ,1'b0  ,1'b0  ,1'b0}; 
  end
  else begin
    is_jal_inst_EN    = '1; 
    is_jal_inst_FLUSH = '0; 
  end
end

// request LSU at MEM

logic [4:0] is_lsu_VALID_EN;
logic [4:0] is_lsu_VALID_FLUSH;

always_comb begin
  if(i_lsu_VALID & ~i_lsu_READY) begin
    //                    PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_lsu_VALID_EN    = {1'b0 ,1'b0  ,1'b0  ,1'b0  ,1'b1}; 
    is_lsu_VALID_FLUSH = {1'b0 ,1'b0  ,1'b0  ,1'b0  ,1'b1}; 
  end
  else begin
    is_lsu_VALID_EN    = '1; 
    is_lsu_VALID_FLUSH = '0; 
  end
end

// Load followed by instruction depend on read result

logic [4:0] is_depend_load_EN;
logic [4:0] is_depend_load_FLUSH;

always_comb begin
  if(i_is_depend_load) begin
    //                      PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_depend_load_EN    = {1'b0 ,1'b0  ,1'b1  ,1'b1  ,1'b1}; 
    is_depend_load_FLUSH = {1'b0 ,1'b0  ,1'b1  ,1'b0  ,1'b0}; 
  end
  else begin
    is_depend_load_EN    = '1; 
    is_depend_load_FLUSH = '0; 
  end
end

// branch prediction wrong

logic [4:0] is_pred_wrong_EN;
logic [4:0] is_pred_wrong_FLUSH;

always_comb begin
  if(i_is_pred_wrong) begin
    //                     PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_pred_wrong_EN    = {1'b1 ,1'b1  ,1'b1  ,1'b1  ,1'b1}; 
    is_pred_wrong_FLUSH = {1'b0 ,1'b1  ,1'b1  ,1'b0  ,1'b0}; 
  end
  else begin
    is_pred_wrong_EN    = '1; 
    is_pred_wrong_FLUSH = '0; 
  end
end

// JALR

logic [4:0] is_jalr_inst_EN;
logic [4:0] is_jalr_inst_FLUSH;

always_comb begin
  if(i_is_jalr_inst) begin
    //                    PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    is_jalr_inst_EN    = {1'b1 ,1'b1  ,1'b1  ,1'b1  ,1'b1}; 
    is_jalr_inst_FLUSH = {1'b0 ,1'b1  ,1'b1  ,1'b0  ,1'b0}; 
  end
  else begin
    is_jalr_inst_EN    = '1; 
    is_jalr_inst_FLUSH = '0; 
  end
end


// Combine all
logic [4:0] raw_combine_EN;
logic [4:0] raw_combine_FLUSH;

always_comb begin
  raw_combine_EN = ( is_pred_taken_EN 
                   & is_jal_inst_EN
                   & is_lsu_VALID_EN
                   & is_depend_load_EN
                   & is_pred_wrong_EN
                   & is_jalr_inst_EN 
                   );
  raw_combine_FLUSH = ( is_pred_taken_FLUSH 
                      | is_jal_inst_FLUSH
                      | is_lsu_VALID_FLUSH
                      | is_depend_load_FLUSH
                      | is_pred_wrong_FLUSH
                      | is_jalr_inst_FLUSH 
                      );
end


// WB forward to EX, could not proceed WB -> hold all
logic [4:0] combine_EN;
logic [4:0] combine_FLUSH;
logic hold_all;

assign combine_FLUSH = raw_combine_FLUSH;
                // ~ ID_EX_EN         & MEM_WB_EN
assign hold_all = (~raw_combine_EN[2] & raw_combine_EN[0])
                & (i_is_fwd_from_WB_to_EX);
always_comb begin
  if(hold_all) begin
    //            PC   ,IF/ID ,ID/EX ,EX/ME ,ME/WB
    combine_EN = {1'b0 ,1'b0  ,1'b0  ,1'b0  ,1'b0}; 
  end
  else begin
    combine_EN = raw_combine_EN; 
  end
end

/* verilator lint_off UNUSEDSIGNAL */
logic dump_c, dump_pc;
/* verilator lint_off UNUSEDSIGNAL */
always_comb begin
  {dump_c , o_IF_ID_creg_en, o_ID_EX_creg_en, o_EX_MEM_creg_en, o_MEM_WB_creg_en} = combine_EN;
  {o_pc_en, o_IF_ID_dreg_en, o_ID_EX_dreg_en, o_EX_MEM_dreg_en, o_MEM_WB_dreg_en} = combine_EN;
  {dump_pc, o_IF_ID_flush  , o_ID_EX_flush  , o_EX_MEM_flush  , o_MEM_WB_flush  } = combine_FLUSH;
end
endmodule

