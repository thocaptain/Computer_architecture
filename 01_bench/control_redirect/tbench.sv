module tbench;
    logic i_is_pred_taken;
    logic i_is_jal_inst;
    logic i_lsu_VALID;
    logic i_lsu_READY;
    logic i_is_depend_load;
    logic i_is_pred_wrong;
    logic i_is_jalr_inst;
    logic i_is_fwd_from_WB_to_EX;
    logic o_pc_en;
    logic o_IF_ID_dreg_en, o_IF_ID_creg_en, o_IF_ID_flush;
    logic o_ID_EX_dreg_en, o_ID_EX_creg_en, o_ID_EX_flush;
    logic o_EX_MEM_dreg_en, o_EX_MEM_creg_en, o_EX_MEM_flush;
    logic o_MEM_WB_dreg_en, o_MEM_WB_creg_en, o_MEM_WB_flush;
    int checks = 0;

    hazard_ctrl dut (.*);

    task automatic clear_inputs;
        i_is_pred_taken = 0;
        i_is_jal_inst = 0;
        i_lsu_VALID = 0;
        i_lsu_READY = 1;
        i_is_depend_load = 0;
        i_is_pred_wrong = 0;
        i_is_jalr_inst = 0;
        i_is_fwd_from_WB_to_EX = 0;
    endtask

    task automatic check_state(input logic [4:0] expected_en,
                               input logic [3:0] expected_flush,
                               input string description);
        #1;
        assert ({o_pc_en, o_IF_ID_dreg_en, o_ID_EX_dreg_en,
                 o_EX_MEM_dreg_en, o_MEM_WB_dreg_en} == expected_en)
            else $fatal(1, "%s: incorrect PC/data-stage enables", description);
        assert ({o_IF_ID_creg_en, o_ID_EX_creg_en,
                 o_EX_MEM_creg_en, o_MEM_WB_creg_en} == expected_en[3:0])
            else $fatal(1, "%s: incorrect control-stage enables", description);
        assert ({o_IF_ID_flush, o_ID_EX_flush,
                 o_EX_MEM_flush, o_MEM_WB_flush} == expected_flush)
            else $fatal(1, "%s: incorrect flushes", description);
        checks++;
    endtask

    initial begin
        clear_inputs();
        check_state(5'b11111, 4'b0000, "ordinary progress");
        i_is_depend_load = 1;
        check_state(5'b00111, 4'b0100, "RAW waits in ID and inserts EX bubble");

        // Test branch recovery and JALR independently, with and without an
        // older memory transaction. A younger ID dependency cannot block
        // recovery; an older waiting MEM access must still hold it.
        for (int redirect = 0; redirect < 2; redirect++) begin
            clear_inputs();
            i_is_pred_wrong = (redirect == 0);
            i_is_jalr_inst = (redirect == 1);
            i_is_depend_load = 1;
            check_state(5'b11111, 4'b1100, "EX redirect discards dependent ID instruction");
            i_lsu_VALID = 1;
            check_state(5'b11111, 4'b1100, "completed older MEM permits redirect");
            i_lsu_READY = 0;
            check_state(5'b00001, 4'b1101, "older pending MEM holds EX redirect");
            i_is_fwd_from_WB_to_EX = 1;
            check_state(5'b00000, 4'b1101, "preserve WB forwarding while MEM waits");
            i_lsu_READY = 1;
            check_state(5'b11111, 4'b1100, "MEM completion releases redirect");
            i_is_depend_load = 0;
            check_state(5'b11111, 4'b1100, "redirect also works without RAW hazard");
        end
        $display("PASS control redirect: %0d scenarios", checks);
        $finish;
    end
endmodule
