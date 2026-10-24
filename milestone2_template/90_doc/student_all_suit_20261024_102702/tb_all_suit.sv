
module tb_all_suit;
    logic clk = 0;
    logic rstn = 0;
    logic [31:0] pc, instruction, addr, wdata, rdata;
    logic [3:0] mask;
    logic wren, valid;
    logic [31:0] sampled_addr, sampled_wdata;
    logic [3:0] sampled_mask;
    logic sampled_wren, sampled_valid;
    logic [31:0] ledr = 0;
    logic [31:0] ledg = 0;
    logic [31:0] report_addr;
    logic [31:0] data_base;
    logic [31:0] stack_top;
    integer retired = 0;
    integer memory_accesses = 0;
    integer stores = 0;

    singlecycle dut (.i_clk(clk), .i_rstn(rstn), .o_imem_addr(pc),
        .i_imem_rdata(instruction), .o_dmem_addr(addr), .o_dmem_wdata(wdata),
        .o_dmem_bmsk(mask), .o_dmem_wren(wren), .i_dmem_rdata(rdata), .o_db_valid(valid));
    imem #(.PROGRAMFILE("program.mem")) instructions
        (.i_clk(clk), .i_addr(pc), .o_data(instruction));
    dmem data_memory (.i_clk(clk), .i_addr(addr), .i_wdata(wdata),
        .i_bmsk(mask), .i_wren(wren), .o_rdata(rdata));

    initial begin
        if (!$value$plusargs("REPORT=%h", report_addr)
            || !$value$plusargs("DATA_BASE=%h", data_base)
            || !$value$plusargs("STACK_TOP=%h", stack_top))
            $fatal(1, "Missing test parameters");
        repeat (2) begin
            #5; clk = 1; #5;
            assert (pc == 32'h80000000 && !valid && !wren)
                else $fatal(1, "Invalid PC/valid/write during reset");
            clk = 0;
        end
        rstn = 1;
        for (int cycle = 1; cycle <= 1000000; cycle++) begin
            #5;
            sampled_addr = addr;
            sampled_wdata = wdata;
            sampled_mask = mask;
            sampled_wren = wren;
            sampled_valid = valid;
            assert (sampled_valid) else $fatal(1, "Invalid instruction at PC=%h", pc);
            assert (pc[31] && pc[1:0] == 0) else $fatal(1, "Bad instruction PC=%h", pc);
            if (instruction[6:0] == 7'h03 || instruction[6:0] == 7'h23) begin
                memory_accesses++;
                // The high-map runs must keep every memory access in DMEM.
                if (data_base[31])
                    assert (addr >= data_base && addr < stack_top)
                        else $fatal(1, "Out-of-map data access: %h", addr);
            end
            clk = 1;
            #5;
            if (sampled_valid) retired++;
            if (sampled_wren) begin
                stores++;
                if (sampled_addr == report_addr) begin
                    assert (sampled_mask == 4'hF) else $fatal(1, "Partial LEDR report");
                    ledr = sampled_wdata;
                end
                if (sampled_addr == report_addr + 16) begin
                    assert (sampled_mask == 4'hF) else $fatal(1, "Partial LEDG report");
                    ledg = sampled_wdata;
                    assert (ledr == 32'h3FFF && ledg == 32'h600D)
                        else $fatal(1, "all_suit FAIL: LEDR=%h LEDG=%h PC=%h", ledr, ledg, pc);
                    assert (retired == cycle) else $fatal(1, "IPC differs from one");
                    $display("ALL_SUIT PASS checks=14/14 cycles=%0d instructions=%0d reset_cycles=2 total_cycles=%0d IPC=1.000000 LEDR=0x%08h LEDG=0x%08h memory_accesses=%0d stores=%0d", cycle, retired, cycle+2, ledr, ledg, memory_accesses, stores);
                    $finish;
                end
            end
            clk = 0;
        end
        $fatal(1, "all_suit timeout: PC=%h LEDR=%h LEDG=%h", pc, ledr, ledg);
    end
endmodule
