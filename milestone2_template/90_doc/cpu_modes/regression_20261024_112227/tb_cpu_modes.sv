
module tb_cpu_modes;
    logic clk = 0;
    logic rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] retire_pc, memory_pc;
    logic [31:0] sampled_addr, sampled_wdata, sampled_retire_pc, sampled_memory_pc;
    logic sampled_wren, sampled_valid;
    logic [31:0] reported_id = 0;
    logic [31:0] ending_pc = 0;
    logic report_seen = 0;
    integer expected, trace_file, retired = 0;
    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem data_memory (.i_clk(clk), .i_addr(addr), .i_wdata(wdata),
        .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));
`ifdef REFERENCE_SINGLE
    assign retire_pc = pc;
    assign memory_pc = pc;
`else
    assign retire_pc = dut.cpu.core.MEM_WB_dreg_q.pc;
    assign memory_pc = dut.cpu.core.EX_MEM_dreg_q.pc;
`endif
    initial begin
        if (!$value$plusargs("EXPECTED=%d", expected)) $fatal(1, "Missing expected result");
        trace_file = $fopen("retirement.trace", "w");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren)
                else $fatal(1, "Reset vector/valid/write incorrect");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 1000000; cycle++) begin
            #5;
            sampled_addr = addr;
            sampled_wdata = wdata;
            sampled_wren = wren;
            sampled_valid = valid;
            sampled_retire_pc = retire_pc;
            sampled_memory_pc = memory_pc;
            if (sampled_valid) begin
                assert (retire_pc[31] && retire_pc[1:0] == 0)
                    else $fatal(1, "Bad retired PC=%h", retire_pc);
                $fdisplay(trace_file, "%08h", retire_pc);
                retired++;
            end
            if (sampled_wren && sampled_addr == 32'h8008F000)
                reported_id = sampled_wdata;
            if (sampled_wren && sampled_addr == 32'h8008F010) begin
                assert (sampled_wdata == 32'h600D && reported_id == 32'(expected) && mask == 4'hF)
                    else $fatal(1, "Program FAIL: status=%h check/id=%h", sampled_wdata, reported_id);
                report_seen = 1;
                ending_pc = sampled_memory_pc;
            end
            clk = 1; #5;
            if (report_seen && sampled_valid && sampled_retire_pc == ending_pc) begin
                $fclose(trace_file);
                $display("PASS cycles=%0d retired=%0d total_cycles=%0d", cycle, retired, cycle+2);
                $finish;
            end
            clk = 0;
        end
        $fatal(1, "Timeout PC=%h", pc);
    end
endmodule
