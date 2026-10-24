// Mode 4: not_always_jump. External memory; no cache or board I/O wrapper.
module rv32i_not_always_jump
    import rv32i_pkg::*;
#(
    parameter logic [31:0] RESET_PC = 32'h8000_0000
)
(
    input  logic        i_clk,
    input  logic        i_rst_n,
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_rdata,
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [3:0]  o_dmem_bmsk,
    output logic        o_dmem_wren,
    input  logic [31:0] i_dmem_rdata,
    output logic        o_insn_vld
);
    rv32i #(
        .RESET_PC(RESET_PC),
        .ENABLE_FORWARDING(1),
        .ENABLE_BRANCH_PREDICTION(0),
        .BRANCH_PRED_STRATEGY(PRED_BOTH)
    ) core (.*);
endmodule
