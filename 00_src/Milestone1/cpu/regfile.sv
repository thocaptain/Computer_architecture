module regfile #(
    parameter BYPASS = 1
) (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [4:0]  i_rs1_addr,
    input  logic [4:0]  i_rs2_addr,
    input  logic [4:0]  i_rd_addr,
    input  logic        i_rd_wen,
    input  logic [31:0] i_rd_data,
    output logic [31:0] o_rs1_data,
    output logic [31:0] o_rs2_data
);
    logic [31:0] raw_rs1, raw_rs2;
    milestone1_regfile u_milestone1 (
        .i_clk(i_clk), .i_rstn(i_rst_n),
        .i_rs1_addr(i_rs1_addr), .i_rs2_addr(i_rs2_addr),
        .i_rd_addr(i_rd_addr), .i_rd_data(i_rd_data), .i_rd_wren(i_rd_wen),
        .o_rs1_data(raw_rs1), .o_rs2_data(raw_rs2)
    );
    // Preserve the existing pipeline's WB->ID bypass contract outside the lab RF.
    // The single-cycle core passes BYPASS=0 and uses the lab behavior directly.
    assign o_rs1_data = (BYPASS && i_rd_wen && (i_rd_addr != 0) &&
                        (i_rs1_addr == i_rd_addr)) ? i_rd_data : raw_rs1;
    assign o_rs2_data = (BYPASS && i_rd_wen && (i_rd_addr != 0) &&
                        (i_rs2_addr == i_rd_addr)) ? i_rd_data : raw_rs2;
endmodule
