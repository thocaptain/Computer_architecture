`timescale 1ns/1ps

// Run all_suit while checking the prediction policy and both recovery paths.
// Define TEST_ALWAYS_JUMP to select the taken-prediction top.
module tbench;
    logic clk;
    logic rst_n;
    logic [31:0] ledr, ledg;
    int taken_count;
    int not_taken_count;
    int hit_count;
    int cold_taken_count;
    int hit_not_taken_count;

`ifdef TEST_ALWAYS_JUMP
    localparam bit EXPECT_TAKEN = 1'b1;
    rv32i_always_jump
`else
    localparam bit EXPECT_TAKEN = 1'b0;
    rv32i_not_always_jump
`endif
    #(.CACHE(0)) dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_io_sw(32'b0), .i_io_btn(4'b0),
        .o_io_ledr(ledr), .o_io_ledg(ledg),
        .o_pc_debug(), .o_insn_vld(),
        .o_io_hex0(), .o_io_hex1(), .o_io_hex2(), .o_io_hex3(),
        .o_io_hex4(), .o_io_hex5(), .o_io_hex6(), .o_io_hex7(),
        .o_io_lcd(), .o_lcd_vld(), .SRAM_ADDR(), .SRAM_DQ(),
        .SRAM_CE_N(), .SRAM_WE_N(), .SRAM_LB_N(), .SRAM_UB_N(), .SRAM_OE_N()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            taken_count <= 0;
            not_taken_count <= 0;
            hit_count <= 0;
            cold_taken_count <= 0;
            hit_not_taken_count <= 0;
        end else begin
            assert (dut.core.is_pred_taken == (EXPECT_TAKEN && dut.core.is_pred_hit))
                else $fatal(1, "Incorrect static prediction at PC %h", dut.core.pc);
            if (dut.core.is_pred_taken) begin
                assert (dut.core.next_pred_pc == dut.core.pc +
                    {{20{dut.core.inst[31]}}, dut.core.inst[7], dut.core.inst[30:25],
                     dut.core.inst[11:8], 1'b0})
                    else $fatal(1, "Taken prediction must fetch the branch target");
            end else begin
                assert (dut.core.next_pred_pc == dut.core.pc + 32'd4)
                    else $fatal(1, "Not-taken prediction must fetch PC + 4");
            end
            if (dut.core.ID_EX_creg_q.is_br_inst && dut.core.EX_MEM_creg_en &&
                !dut.core.EX_MEM_flush) begin
                if (dut.core.EX_actual_taken)
                    taken_count <= taken_count + 1;
                else
                    not_taken_count <= not_taken_count + 1;
                if (dut.core.ID_EX_creg_q.is_pred_hit)
                    hit_count <= hit_count + 1;
                if (!dut.core.ID_EX_creg_q.is_pred_taken && dut.core.EX_actual_taken) begin
                    cold_taken_count <= cold_taken_count + 1;
                    assert (dut.core.EX_is_pred_wrong && dut.core.IF_ID_flush && dut.core.ID_EX_flush)
                        else $fatal(1, "Taken branch predicted not-taken must flush");
                end
                if (dut.core.ID_EX_creg_q.is_pred_taken && !dut.core.EX_actual_taken) begin
                    hit_not_taken_count <= hit_not_taken_count + 1;
                    assert (dut.core.EX_is_pred_wrong && dut.core.IF_ID_flush && dut.core.ID_EX_flush)
                        else $fatal(1, "Not-taken branch predicted taken must flush");
                end
            end
        end
    end

    initial begin
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        wait (ledg != 0);
        @(negedge clk);
        assert (ledg == 32'h600D && ledr == 32'h3FFF)
            else $fatal(1, "all_suit failed: LEDR=%h LEDG=%h", ledr, ledg);
        assert (taken_count > 0 && not_taken_count > 0 && cold_taken_count > 0)
            else $fatal(1, "Missing branch-direction or cold recovery coverage");
        if (EXPECT_TAKEN) begin
            assert (hit_count > 0 && hit_not_taken_count > 0)
                else $fatal(1, "Missing BTB-hit or taken-prediction recovery coverage");
        end
        $display("PASS static taken=%0b: taken=%0d not_taken=%0d hits=%0d cold_taken=%0d hit_not_taken=%0d",
            EXPECT_TAKEN, taken_count, not_taken_count, hit_count, cold_taken_count, hit_not_taken_count);
        $finish;
    end

    initial begin
        repeat (200000) @(negedge clk);
        $fatal(1, "Timeout waiting for all_suit result");
    end
endmodule
