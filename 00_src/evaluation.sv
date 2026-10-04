module evaluation 
#(
      parameter BR_THRSH_EVAL      = 1000 // Branch instructions before evaluation
    , parameter IPC_THRSH_EVAL     = 1000 // Cycles before evaluation 
    , parameter MEM_PEN_THRSH_EVAL = 100  // Cycles before evaluation 

    , localparam BR_CNT_W      = $clog2(BR_THRSH_EVAL+1)
    , localparam IPC_CNT_W     = $clog2(IPC_THRSH_EVAL+1)
    , localparam MEM_PEN_CNT_W = $clog2(MEM_PEN_THRSH_EVAL+1)
)
(
     input  logic                 i_clk
    ,input  logic                 i_rst_n

    ,input  logic                 i_is_br_inst
    ,input  logic                 i_is_br_pred_correct
    // (Correct predictions) per (BR_THRSH_EVAL number of branch instructions)
    ,output logic [BR_CNT_W-1:0]  o_br_correct_eval 

    ,input  logic                 i_is_inst_vld  // all valid instructions except NOP
    ,input  logic                 i_is_inst_done 
    // (valid instructions) per (IPC_THRSH_EVAL number of cycles)
    ,output logic [IPC_CNT_W-1:0] o_ipc_eval 

    ,input  logic                     i_lsu_valid
    ,input  logic                     i_lsu_ready
    // (completed mem accesses) per (MEM_PEN_THRSH_EVAL number of cycles while lsu_valid asserted)
    ,output logic [MEM_PEN_CNT_W-1:0] o_mem_pen
);
//////////////////////////////////////////////////////////////////////////
// Branch prediction evaluation
//////////////////////////////////////////////////////////////////////////
    logic [BR_CNT_W-1:0] br_correct_cnt;
    logic [BR_CNT_W-1:0] br_inst_cnt;
    logic [BR_CNT_W-1:0] br_correct_cnt_next;

    assign br_correct_cnt_next = (i_is_br_pred_correct)? br_correct_cnt+1 : br_correct_cnt;
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            o_br_correct_eval <= '0;
            br_inst_cnt       <= '0;
            br_correct_cnt    <= '0;
        end        
        else begin
            if(i_is_br_inst) begin
                if(br_inst_cnt==BR_THRSH_EVAL-1) begin
                    o_br_correct_eval <= br_correct_cnt_next;
                    br_inst_cnt       <= '0;
                    br_correct_cnt    <= '0;
                    `ifdef DV
                        $display("Branch Prediction Scoreboard: @%05d n_correct=%10d, n_br_inst=%10d", $time, br_correct_cnt_next, BR_THRSH_EVAL);
                    `endif
                end
                else begin
                    o_br_correct_eval <= o_br_correct_eval;
                    br_inst_cnt       <= br_inst_cnt+1;
                    br_correct_cnt    <= br_correct_cnt_next;
                end
            end
        end
    end
    
//////////////////////////////////////////////////////////////////////////
// IPC: Instructions per cycle
//////////////////////////////////////////////////////////////////////////
    logic [IPC_CNT_W-1:0] ipc_cycle_cnt;
    logic [IPC_CNT_W-1:0] inst_cnt;
    logic [IPC_CNT_W-1:0] inst_cnt_next;

    assign inst_cnt_next = (i_is_inst_vld & i_is_inst_done)? inst_cnt+1 : inst_cnt;
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            o_ipc_eval     <= '0;
            ipc_cycle_cnt  <= '0;
            inst_cnt       <= '0;
        end
        else begin
            if(ipc_cycle_cnt==IPC_THRSH_EVAL-1) begin
                o_ipc_eval     <= inst_cnt_next;
                ipc_cycle_cnt  <= '0;
                inst_cnt       <= '0;
                `ifdef DV
                    $display("IPC: @%05d instrucions=%10d, n_cycles=%10d", $time, inst_cnt_next, IPC_THRSH_EVAL);
                `endif
            end
            else begin
                o_ipc_eval     <= o_ipc_eval;
                ipc_cycle_cnt  <= ipc_cycle_cnt + 1;
                inst_cnt       <= inst_cnt_next;
            end
        end
    end

//////////////////////////////////////////////////////////////////////////
// MEM access penalty
//////////////////////////////////////////////////////////////////////////

    logic [MEM_PEN_CNT_W-1:0] mem_pen_cycle_cnt;
    logic [MEM_PEN_CNT_W-1:0] mem_pen_access;
    logic [MEM_PEN_CNT_W-1:0] mem_pen_next;

    assign mem_pen_next = (i_lsu_ready)? mem_pen_access+1 : mem_pen_access;
    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            o_mem_pen         <= '0;
            mem_pen_cycle_cnt <= '0;
            mem_pen_access    <= '0;
        end
        else begin
            if(i_lsu_valid) begin
                if(mem_pen_cycle_cnt==MEM_PEN_THRSH_EVAL-1) begin
                    o_mem_pen         <= mem_pen_next;
                    mem_pen_cycle_cnt <= '0;
                    mem_pen_access    <= '0;
                    `ifdef DV
                        $display("MEM Penalty: @%05d completed accesses=%10d, n_cycles=%10d", $time, mem_pen_next, MEM_PEN_THRSH_EVAL);
                    `endif
                end
                else begin
                    o_mem_pen         <= o_mem_pen;
                    mem_pen_cycle_cnt <= mem_pen_cycle_cnt+1;
                    mem_pen_access    <= mem_pen_next;
                end
            end
        end
    end

endmodule
