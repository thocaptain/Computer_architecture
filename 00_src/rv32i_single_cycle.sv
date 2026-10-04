module rv32i_single_cycle
    import rv32i_pkg::*;
#(
    parameter INST_MEM_ADDR_W = 10,
    parameter MEM_TYPE = MEM_FLOP,
    parameter CACHE = 0
)
(
      input  logic        i_clk
    , input  logic        i_rst_n
    , output logic [31:0] o_pc_debug
    , output logic        o_insn_vld
    , output logic [31:0] o_io_ledr
    , output logic [31:0] o_io_ledg
    , output logic [6:0]  o_io_hex0
    , output logic [6:0]  o_io_hex1
    , output logic [6:0]  o_io_hex2
    , output logic [6:0]  o_io_hex3
    , output logic [6:0]  o_io_hex4
    , output logic [6:0]  o_io_hex5
    , output logic [6:0]  o_io_hex6
    , output logic [6:0]  o_io_hex7
    , output logic [31:0] o_io_lcd
    , input  logic [31:0] i_io_sw
    , input  logic [3:0]  i_io_btn
    , output logic        o_lcd_vld
    , output logic [17:0] SRAM_ADDR
    , inout  wire  [15:0] SRAM_DQ
    , output logic        SRAM_CE_N
    , output logic        SRAM_WE_N
    , output logic        SRAM_LB_N
    , output logic        SRAM_UB_N
    , output logic        SRAM_OE_N
);

    logic [31:0] pc;
    logic [31:0] inst;
    logic [31:0] immediate;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;
    logic [31:0] load_data_raw;
    logic [31:0] load_data;
    logic [31:0] store_data;
    logic [3:0]  store_strb;
    logic [31:0] writeback_data;
    logic [31:0] pc_next;
    logic [4:0]  rs1_addr;
    logic [4:0]  rs2_addr;
    logic [4:0]  rd_addr;
    logic        reg_wen;
    logic        is_br;
    logic        is_jp;
    logic        br_un;
    logic        st_mem;
    logic        lsu_valid;
    logic        lsu_ready;
    logic        br_eq;
    logic        br_lt;
    logic        branch_taken;
    logic        jalr;
    ImmSel_e     imm_sel;
    BSel_e       b_sel;
    ASel_e       a_sel;
    ALUSel_e     alu_sel;
    WBSel_e      wb_sel;

    assign o_pc_debug = pc;

    inst_mem #(
        .ADDR_W(INST_MEM_ADDR_W)
    ) inst_mem (
        .i_addr(INST_MEM_ADDR_W'(pc)),
        .o_inst(inst)
    );

    control control_unit (
        .i_inst(inst),
        .o_imm_sel(imm_sel),
        .o_reg_wen(reg_wen),
        .o_is_br(is_br),
        .o_is_jp(is_jp),
        .o_br_un(br_un),
        .o_b_sel(b_sel),
        .o_a_sel(a_sel),
        .o_alu_sel(alu_sel),
        .o_st_mem(st_mem),
        .o_wb_sel(wb_sel),
        .o_insn_vld(o_insn_vld),
        .lsu_VALID(lsu_valid)
    );

    assign rs1_addr = inst[19:15];
    assign rs2_addr = inst[24:20];
    assign rd_addr  = inst[11:7];

    regfile #(
        .BYPASS(0)
    ) regfile (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_rs1_addr(rs1_addr),
        .i_rs2_addr(rs2_addr),
        .i_rd_addr(rd_addr),
        .i_rd_wen(reg_wen & (~lsu_valid | lsu_ready)),
        .i_rd_data(writeback_data),
        .o_rs1_data(rs1_data),
        .o_rs2_data(rs2_data)
    );

    always_comb begin
        case (imm_sel)
            IMM_I: immediate = {{21{inst[31]}}, inst[30:20]};
            IMM_S: immediate = {{21{inst[31]}}, inst[30:25], inst[11:7]};
            IMM_B: immediate = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            IMM_U: immediate = {inst[31:12], 12'b0};
            IMM_J: immediate = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            default: immediate = '0;
        endcase
    end

    always_comb begin
        case (a_sel)
            A_REG:   alu_operand_a = rs1_data;
            A_PC:    alu_operand_a = pc;
            A_ZERO:  alu_operand_a = '0;
            default: alu_operand_a = '0;
        endcase

        case (b_sel)
            B_REG:   alu_operand_b = rs2_data;
            B_IMM:   alu_operand_b = immediate;
            default: alu_operand_b = '0;
        endcase
    end

    alu alu (
        .i_operand_a(alu_operand_a),
        .i_operand_b(alu_operand_b),
        .i_alu_op(alu_sel),
        .o_alu_res(alu_result)
    );

    branch_comp branch_comp (
        .i_rs1_data(rs1_data),
        .i_rs2_data(rs2_data),
        .i_br_un(br_un),
        .o_br_eq(br_eq),
        .o_br_lt(br_lt)
    );

    always_comb begin
        branch_taken = 1'b0;
        case (inst[14:12])
            3'b000: branch_taken = br_eq;
            3'b001: branch_taken = ~br_eq;
            3'b100, 3'b110: branch_taken = br_lt;
            3'b101, 3'b111: branch_taken = ~br_lt;
            default: branch_taken = 1'b0;
        endcase

        jalr = is_jp & (a_sel == A_REG);
        pc_next = pc + 32'd4;
        if (is_br & branch_taken)
            pc_next = pc + immediate;
        if (is_jp & (a_sel == A_PC))
            pc_next = pc + immediate;
        if (jalr)
            pc_next = {alu_result[31:1], 1'b0};
    end

    lsu_dat_handler lsu_dat_handler (
        .i_funct3(inst[14:12]),
        .i_lsb_addr(alu_result[1:0]),
        .i_st_data(rs2_data),
        .o_st_data(store_data),
        .o_st_strb(store_strb),
        .i_ld_data(load_data_raw),
        .o_ld_data(load_data)
    );

    lsu #(
        .MEM_TYPE(MEM_TYPE),
        .CACHE(CACHE)
    ) lsu (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_lsu_addr(alu_result),
        .i_st_data(store_data),
        .i_st_strb(store_strb),
        .i_lsu_wren(st_mem),
        .o_ld_data(load_data_raw),
        .o_lcd_vld(o_lcd_vld),
        .i_VALID(lsu_valid),
        .o_READY(lsu_ready),
        .i_io_sw(i_io_sw),
        .i_io_btn(i_io_btn),
        .o_io_ledr(o_io_ledr),
        .o_io_ledg(o_io_ledg),
        .o_io_lcd(o_io_lcd),
        .o_io_hex0(o_io_hex0),
        .o_io_hex1(o_io_hex1),
        .o_io_hex2(o_io_hex2),
        .o_io_hex3(o_io_hex3),
        .o_io_hex4(o_io_hex4),
        .o_io_hex5(o_io_hex5),
        .o_io_hex6(o_io_hex6),
        .o_io_hex7(o_io_hex7),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_CE_N(SRAM_CE_N),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_LB_N(SRAM_LB_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_OE_N(SRAM_OE_N),
        .vld_data_mem()
    );

    always_comb begin
        case (wb_sel)
            WB_ALU: writeback_data = alu_result;
            WB_MEM: writeback_data = load_data;
            WB_PC:  writeback_data = pc + 32'd4;
            default: writeback_data = '0;
        endcase
    end

    always_ff @(posedge i_clk) begin
        if (!i_rst_n)
            pc <= '0;
        else if (!lsu_valid | lsu_ready)
            pc <= pc_next;
    end
endmodule