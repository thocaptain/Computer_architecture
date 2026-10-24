module singlecycle (
    input  logic        i_clk,
    input  logic        i_rstn,
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_rdata,
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [3:0]  o_dmem_bmsk,
    output logic        o_dmem_wren,
    input  logic [31:0] i_dmem_rdata,
    output logic        o_db_valid
);
    rv32i_single_cycle #(
        .RESET_PC(32'h8000_0000)
    ) cpu (
        .i_clk(i_clk),
        .i_rst_n(i_rstn),
        .o_imem_addr(o_imem_addr),
        .i_imem_rdata(i_imem_rdata),
        .o_dmem_addr(o_dmem_addr),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_bmsk(o_dmem_bmsk),
        .o_dmem_wren(o_dmem_wren),
        .i_dmem_rdata(i_dmem_rdata),
        .o_insn_vld(o_db_valid)
    );
endmodule
