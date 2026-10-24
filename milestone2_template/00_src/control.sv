module control 
    import rv32i_pkg::*;
(
    /* verilator lint_off UNUSEDSIGNAL */
      input  logic [31:0] i_inst
    /* verilator lint_off UNUSEDSIGNAL */

    , output ImmSel_e     o_imm_sel
    , output logic        o_reg_wen
    , output logic        o_is_br
    , output logic        o_is_jp
    , output logic        o_br_un
    , output BSel_e       o_b_sel
    , output ASel_e       o_a_sel
    , output ALUSel_e     o_alu_sel
    , output logic        o_st_mem
    , output WBSel_e      o_wb_sel
    , output logic        o_insn_vld

    , output logic        lsu_VALID
);
localparam OUT_W =  {IMMSEL_W+1+1+1+1+BSEL_W+ASEL_W+ALUSEL_W+1+WBSEL_W};
logic [OUT_W-1:0] out_ctrl;

always_comb begin
    (* parallel_case *) casez({i_inst[30],i_inst[14:12],i_inst[6:2]})
        9'b000001100: begin // add
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b100001100: begin // sub
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SUB ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b010001100: begin // xor
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_XOR ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b011001100: begin // or
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_OR  ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b011101100: begin // and
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_AND ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b000101100: begin // sll
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SLL ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b010101100: begin // srl
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SRL ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b110101100: begin // sra
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SRA ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b001001100: begin // slt
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SLT ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b001101100: begin // sltu
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_REG   ,A_REG   ,ALU_SLTU,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?00000100: begin // addi
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?10000100: begin // xori
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_XOR ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?11000100: begin // ori
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_OR  ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?11100100: begin // andi
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_AND ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b000100100: begin // slli
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_SLL ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b010100100: begin // srli
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_SRL ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b110100100: begin // srai
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_SRA ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?01000100: begin // slti
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_SLT ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?01100100: begin // sltiu
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_SLTU,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?00000000: begin // lb
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_MEM  };
            o_insn_vld = 1'b1;
        end
        9'b?00100000: begin // lh
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_MEM  };
            o_insn_vld = 1'b1;
        end
        9'b?01000000: begin // lw
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_MEM  };
            o_insn_vld = 1'b1;
        end
        9'b?10000000: begin // lbu
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_MEM  };
            o_insn_vld = 1'b1;
        end
        9'b?10100000: begin // lhu
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_MEM  };
            o_insn_vld = 1'b1;
        end
        9'b?00001000: begin // sb
            out_ctrl = {IMM_S   ,1'b0    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b1    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?00101000: begin // sh
            out_ctrl = {IMM_S   ,1'b0    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b1    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?01001000: begin // sw
            out_ctrl = {IMM_S   ,1'b0    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b1    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?00011000: begin // beq
            out_ctrl = {IMM_B   ,1'b0    ,1'b0    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?00111000: begin // bne
            out_ctrl = {IMM_B   ,1'b0    ,1'b0    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?10011000: begin // blt
            out_ctrl = {IMM_B   ,1'b0    ,1'b0    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?10111000: begin // bge
            out_ctrl = {IMM_B   ,1'b0    ,1'b0    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?11011000: begin // bltu
            out_ctrl = {IMM_B   ,1'b0    ,1'b1    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b?11111000: begin // bgeu
            out_ctrl = {IMM_B   ,1'b0    ,1'b1    ,1'b1    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b????11011: begin // jal
            out_ctrl = {IMM_J   ,1'b1    ,1'b0    ,1'b0    ,1'b1    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_PC   };
            o_insn_vld = 1'b1;
        end
        9'b?00011001: begin // jalr
            out_ctrl = {IMM_I   ,1'b1    ,1'b0    ,1'b0    ,1'b1    ,B_IMM   ,A_REG   ,ALU_ADD ,1'b0    ,WB_PC   };
            o_insn_vld = 1'b1;
        end
        9'b????01101: begin // lui
            out_ctrl = {IMM_U   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_ZERO  ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        9'b????00101: begin // auipc
            out_ctrl = {IMM_U   ,1'b1    ,1'b0    ,1'b0    ,1'b0    ,B_IMM   ,A_PC    ,ALU_ADD ,1'b0    ,WB_ALU  };
            o_insn_vld = 1'b1;
        end
        default: begin // invalid command
            out_ctrl='0;
            o_insn_vld = 1'b0;
        end
    endcase
    {o_imm_sel,o_reg_wen,o_br_un,o_is_br,o_is_jp,o_b_sel,o_a_sel,o_alu_sel,o_st_mem,o_wb_sel} = out_ctrl;

end

// Need to split to another always_comb because of this: https://github.com/lowRISC/opentitan/pull/6639
always_comb begin
    lsu_VALID = o_st_mem || (o_wb_sel == WB_MEM); // LSU request
end

endmodule
