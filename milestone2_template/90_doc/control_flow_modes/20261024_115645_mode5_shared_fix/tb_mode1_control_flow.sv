
module tb_mode1_control_flow;
    logic clk = 0, rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] reported_case = 0;
    logic sampled_write;
    logic [31:0] sampled_addr, sampled_data;
    integer expected;
    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.ADDR_WIDTH(26), .PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem #(.START_ADDR(32'h84000000)) data_memory
        (.i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));
    initial begin : run_test
        if (!$value$plusargs("EXPECTED=%d", expected)) $fatal(1, "Missing expected count");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren) else $fatal(1, "Bad reset");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 10000000; cycle++) begin
            #5;
            sampled_write = wren;
            sampled_addr = addr;
            sampled_data = wdata;
            if (sampled_write && sampled_addr == 32'h8400F000) reported_case = sampled_data;
            if ((dut.cpu.core.EX_is_pred_wrong || dut.cpu.core.EX_is_jalr_inst)
                && dut.cpu.core.EX_is_depend_load)
                $display("REDIRECT_AND_ID_STALL cycle=%0d pc=%h EX_pc=%h EX_inst=%h ID_pc=%h ID_inst=%h pc_en=%b",
                    cycle, pc, dut.cpu.core.ID_EX_dreg_q.pc, dut.cpu.core.ID_EX_dreg_q.inst,
                    dut.cpu.core.IF_ID_dreg_q.pc, dut.cpu.core.IF_ID_dreg_q.inst, dut.cpu.core.pc_en);
            clk = 1; #5;
            if (sampled_write && sampled_addr == 32'h8400F010) begin
                if (sampled_data != 32'h600D || reported_case != 32'(expected)) begin
                    $display("RESULT FAIL first_case=%0d status=%h cycles=%0d", reported_case, sampled_data, cycle);
                    $finish;
                    disable run_test;
                end
                $display("RESULT PASS cases=%0d cycles=%0d", reported_case, cycle);
                $finish;
                disable run_test;
            end
            clk = 0;
        end
        $display("RESULT TIMEOUT first_case=%0d pc=%h", reported_case, pc);
        $finish;
    end
endmodule
