// =============================================================================
// Module Name:   rv32i_single_cycle
// Project:       Milestone 3 - Simple MCU
// Description:   Single-cycle RV32I core with external instruction and load/store ports.
// =============================================================================

`timescale 1ns / 1ps
`include "mcu_config.svh"

module rv32i_single_cycle
    import rv32i_pkg::*;
#(
    parameter logic [31:0] RESET_PC = 32'h8000_0000
)(
    // Clock & Reset
    input  logic        i_clk,
    input  logic        i_rst_n,

    // Instruction Memory Interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_rdata,

    // Load/Store Bus Interface
`ifdef DMEM_USE_SRAM
    input  logic        i_dmem_ready,
    output logic        o_dmem_valid,
`endif
    output logic [31:0] o_dmem_addr,
    output logic [31:0] o_dmem_wdata,
    output logic [3:0]  o_dmem_bmsk,
    output logic        o_dmem_wren,
    input  logic [31:0] i_dmem_rdata,

    // Simulation & Debug Outputs
    output logic        o_insn_vld
);

    // =========================================================================
    // Internal Datapath and Control Signals
    // =========================================================================
    logic    [31:0] pc;
    logic    [31:0] inst;
    logic           decoded_valid;
    logic    [31:0] immediate;
    logic    [31:0] rs1_data;
    logic    [31:0] rs2_data;
    logic    [31:0] alu_operand_a;
    logic    [31:0] alu_operand_b;
    logic    [31:0] alu_result;
    logic    [31:0] load_data_raw;
    logic    [31:0] load_data;
    logic    [31:0] store_data;
    logic    [3:0]  store_strb;
    logic    [31:0] writeback_data;
    logic    [31:0] pc_next;
    logic    [31:0] pc_plus_four;
    logic    [31:0] pc_target;
    logic    [4:0]  rs1_addr;
    logic    [4:0]  rs2_addr;
    logic    [4:0]  rd_addr;
    logic           reg_wen;
    logic           is_br;
    logic           is_jp;
    logic           br_un;
    logic           st_mem;
    logic           br_eq;
    logic           br_lt;
    logic           branch_taken;
    logic           jalr;
    ImmSel_e        imm_sel;
    BSel_e          b_sel;
    ASel_e          a_sel;
    ALUSel_e        alu_sel;
    WBSel_e         wb_sel;

    // =========================================================================
    // External Memory Interface
    // =========================================================================
    assign o_imem_addr   = pc;
    assign inst          = i_imem_rdata;
    assign load_data_raw = i_dmem_rdata;
    assign o_dmem_addr   = alu_result;
    assign o_dmem_wdata  = store_data;
    assign o_dmem_bmsk   = store_strb;
`ifdef DMEM_USE_SRAM
    // Requests remain asserted while PC and register writeback wait for ACK.
    assign o_dmem_valid  = i_rst_n & decoded_valid & (st_mem | (wb_sel == WB_MEM));
    assign o_dmem_wren   = st_mem & i_rst_n & decoded_valid;
    assign o_insn_vld    = i_rst_n & decoded_valid & i_dmem_ready;
`else
    assign o_dmem_wren   = st_mem & o_insn_vld;
    assign o_insn_vld    = i_rst_n & decoded_valid;
`endif

    // =========================================================================
    // Instruction Decoder
    // =========================================================================
    control control_unit (
        .i_inst     (inst),
        .o_imm_sel  (imm_sel),
        .o_reg_wen  (reg_wen),
        .o_is_br    (is_br),
        .o_is_jp    (is_jp),
        .o_br_un    (br_un),
        .o_b_sel    (b_sel),
        .o_a_sel    (a_sel),
        .o_alu_sel  (alu_sel),
        .o_st_mem   (st_mem),
        .o_wb_sel   (wb_sel),
        .o_insn_vld (decoded_valid),
        .lsu_VALID  ()
    );

    // =========================================================================
    // Register File
    // =========================================================================
    assign rs1_addr = inst[19:15];
    assign rs2_addr = inst[24:20];
    assign rd_addr  = inst[11:7];

    regfile #(
        .BYPASS (0)
    ) regfile (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .i_rs1_addr (rs1_addr),
        .i_rs2_addr (rs2_addr),
        .i_rd_addr  (rd_addr),
        .i_rd_wen   (reg_wen & o_insn_vld),
        .i_rd_data  (writeback_data),
        .o_rs1_data (rs1_data),
        .o_rs2_data (rs2_data)
    );

    // =========================================================================
    // Immediate Generation
    // =========================================================================
    always_comb begin
        case (imm_sel)
            IMM_I: immediate   = {{21{inst[31]}}, inst[30:20]};
            IMM_S: immediate   = {{21{inst[31]}}, inst[30:25], inst[11:7]};
            IMM_B: immediate   = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            IMM_U: immediate   = {inst[31:12], 12'b0};
            IMM_J: immediate   = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            default: immediate = '0;
        endcase
    end

    // =========================================================================
    // ALU Operand Selection
    // =========================================================================
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

    // =========================================================================
    // ALU and Branch Comparator
    // =========================================================================
    alu alu (
        .i_operand_a (alu_operand_a),
        .i_operand_b (alu_operand_b),
        .i_alu_op    (alu_sel),
        .o_alu_res   (alu_result)
    );

    branch_comp branch_comp (
        .i_rs1_data (rs1_data),
        .i_rs2_data (rs2_data),
        .i_br_un    (br_un),
        .o_br_eq    (br_eq),
        .o_br_lt    (br_lt)
    );

    // =========================================================================
    // Program Counter Arithmetic
    // =========================================================================
    bit_adder #(
        .WIDTH (32)
    ) pc_increment (
        .i_a     (pc),
        .i_b     (32'd4),
        .i_carry (1'b0),
        .o_sum   (pc_plus_four),
        .o_carry ()
    );

    bit_adder #(
        .WIDTH (32)
    ) pc_offset (
        .i_a     (pc),
        .i_b     (immediate),
        .i_carry (1'b0),
        .o_sum   (pc_target),
        .o_carry ()
    );

    // =========================================================================
    // Branch and Jump Selection
    // =========================================================================
    always_comb begin
        branch_taken = 1'b0;
        case (inst[14:12])
            3'b000: branch_taken = br_eq;
            3'b001: branch_taken = ~br_eq;
            3'b100, 3'b110: branch_taken = br_lt;
            3'b101, 3'b111: branch_taken = ~br_lt;
            default: branch_taken = 1'b0;
        endcase

        jalr    = is_jp & (a_sel == A_REG);
        pc_next = pc_plus_four;
        if (is_br & branch_taken) begin
            pc_next = pc_target;
        end
        if (is_jp & (a_sel == A_PC)) begin
            pc_next = pc_target;
        end
        if (jalr) begin
            pc_next = {alu_result[31:1], 1'b0};
        end
    end

    // =========================================================================
    // Load/Store Data Handling
    // =========================================================================
    lsu_dat_handler lsu_dat_handler (
        .i_funct3   (inst[14:12]),
        .i_lsb_addr (alu_result[1:0]),
        .i_st_data  (rs2_data),
        .o_st_data  (store_data),
        .o_st_strb  (store_strb),
        .i_ld_data  (load_data_raw),
        .o_ld_data  (load_data)
    );

    // =========================================================================
    // Register Writeback Selection
    // =========================================================================
    always_comb begin
        case (wb_sel)
            WB_ALU: writeback_data  = alu_result;
            WB_MEM: writeback_data  = load_data;
            WB_PC:  writeback_data  = pc_plus_four;
            default: writeback_data = '0;
        endcase
    end

    // =========================================================================
    // Program Counter Register
    // =========================================================================
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pc <= RESET_PC;
`ifdef DMEM_USE_SRAM
        end else if (i_dmem_ready) begin
`else
        end else begin
`endif
            pc <= pc_next;
        end
    end
endmodule: rv32i_single_cycle
