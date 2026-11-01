`timescale 1ns/1ps
module tbench;
    import cpu_pkg::*;
    logic clk = 0;
    initial forever #5 clk = ~clk;
    logic [31:0] a, b, sum, alu_data, shifted;
    logic sub, unsigned_mode, cout, eq, lt, gt;
    logic [3:0] alu_op;
    logic [4:0] shamt;
    logic [1:0] shift_mode;
    adder u_adder (.i_a(a), .i_b(b), .i_sub(sub), .i_unsigned(unsigned_mode), .o_sum(sum), .o_cout(cout));
    magnitude_comparator u_comparator (
        .i_a(a), .i_b(b), .i_unsigned(unsigned_mode), .o_eq(eq), .o_lt(lt), .o_gt(gt)
    );
    shifter u_shifter (.i_data(a), .i_shamt(shamt), .i_mode(shift_mode), .o_data(shifted));
    alu u_alu (.i_op_a(a), .i_op_b(b), .i_alu_op(alu_op), .o_alu_data(alu_data));

    logic rstn, rd_wren;
    logic [4:0] rs1, rs2, rd;
    logic [31:0] rd_data, rs1_data, rs2_data;
    regfile u_regfile (
        .i_clk(clk), .i_rstn(rstn), .i_rs1_addr(rs1), .i_rs2_addr(rs2),
        .i_rd_addr(rd), .i_rd_data(rd_data), .i_rd_wren(rd_wren),
        .o_rs1_data(rs1_data), .o_rs2_data(rs2_data)
    );
    localparam logic [31:0] BASE = 32'h0000_2040;
    localparam int MEM_BYTES = 64;
    logic [31:0] addr, wdata, async_data, sync_data;
    logic [3:0] mask;
    logic wren, rden;
    data_mem_async #(.START_ADDR(BASE), .ADDR_WIDTH(6)) u_async (
        .i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask), .i_wren(wren), .o_rdata(async_data)
    );
    data_mem_sync #(.START_ADDR(BASE), .ADDR_WIDTH(6)) u_sync (
        .i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask),
        .i_wren(wren), .i_rden(rden), .o_rdata(sync_data)
    );
    logic [31:0] tiny_async, tiny_sync;
    data_mem_async #(.START_ADDR(32'hffff_fffc), .ADDR_WIDTH(2)) u_tiny_async (
        .i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask), .i_wren(wren), .o_rdata(tiny_async)
    );
    data_mem_sync #(.START_ADDR(32'hffff_fffc), .ADDR_WIDTH(2)) u_tiny_sync (
        .i_clk(clk), .i_addr(addr), .i_wdata(wdata), .i_bmsk(mask),
        .i_wren(wren), .i_rden(rden), .o_rdata(tiny_sync)
    );
    int checks = 0;
    int pairs = 0;
    logic [31:0] rng = 32'h1bad_f00d;
    logic [31:0] model [0:15];
    logic [31:0] expected_sync;

    function automatic logic [31:0] random_word();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction
    task automatic check32(input string label_text, input logic [31:0] actual, expected);
        checks++;
        if (actual !== expected)
            $fatal(1, "%s: actual=%08h expected=%08h at %0t", label_text, actual, expected, $time);
    endtask
    task automatic check_pair(input logic [31:0] av, bv);
        logic [32:0] ext_a, ext_b, arithmetic_ref;
        logic [31:0] expected;
        logic expected_cout, expected_lt;
        a = av;
        b = bv;
        pairs++;
        for (int un = 0; un < 2; un++) begin
            unsigned_mode = 1'(un);
            for (int subtract = 0; subtract < 2; subtract++) begin
                sub = 1'(subtract);
                ext_a = unsigned_mode ? {1'b0, av} : {av[31], av};
                ext_b = unsigned_mode ? {1'b0, bv} : {bv[31], bv};
                arithmetic_ref = sub ? ext_a - ext_b : ext_a + ext_b;
                expected_cout = unsigned_mode && sub ? (av >= bv) : arithmetic_ref[32];
                #1;
                check32("adder sum", sum, arithmetic_ref[31:0]);
                check32("adder carry/status", {31'b0, cout}, {31'b0, expected_cout});
                expected_lt = unsigned_mode ? (av < bv) : ($signed(av) < $signed(bv));
                check32("comparator equality", {31'b0, eq}, {31'b0, (av == bv)});
                check32("comparator less", {31'b0, lt}, {31'b0, expected_lt});
                check32("comparator greater", {31'b0, gt}, {31'b0, !(expected_lt || (av == bv))});
                check32("comparator one-hot", {29'b0, eq, lt, gt},
                        (av == bv) ? 32'd4 : (expected_lt ? 32'd2 : 32'd1));
            end
        end
        for (int op = 0; op < 16; op++) begin
            alu_op = 4'(op);
            case (op)
                0: expected = av + bv;
                1: expected = av - bv;
                2: expected = av ^ bv;
                3: expected = av | bv;
                4: expected = av & bv;
                5: expected = av << bv[4:0];
                6: expected = av >> bv[4:0];
                7: expected = $signed(av) >>> bv[4:0];
                8: expected = {31'b0, ($signed(av) < $signed(bv))};
                9: expected = {31'b0, (av < bv)};
                default: expected = 0;
            endcase
            #1;
            check32("ALU", alu_data, expected);
        end
    endtask
    task automatic check_shifts(input logic [31:0] value);
        logic [31:0] expected;
        a = value;
        for (int mode = 0; mode < 4; mode++) begin
            shift_mode = 2'(mode);
            for (int amount = 0; amount < 32; amount++) begin
                shamt = 5'(amount);
                case (mode)
                    0: expected = value >> amount;
                    1: expected = value << amount;
                    2: expected = $signed(value) >>> amount;
                    default: expected = 0;
                endcase
                #1;
                check32("shifter", shifted, expected);
            end
        end
    endtask
    task automatic test_regfile();
        @(negedge clk);
        rstn = 1;
        #1;
        rstn = 0;
        #1;
        for (int idx = 0; idx < 32; idx++) begin
            rs1 = 5'(idx);
            rs2 = 5'(31-idx);
            #1;
            check32("register reset port 1", rs1_data, 0);
            check32("register reset port 2", rs2_data, 0);
        end
        @(negedge clk);
        rstn = 1;
        for (int idx = 0; idx < 32; idx++) begin
            rd = 5'(idx);
            rs1 = 5'(idx);
            rs2 = 5'(idx);
            rd_data = 32'hcafe_0000 | 32'(idx);
            rd_wren = 1;
            #1;
            check32("no write forwarding", rs1_data, 0);
            @(posedge clk);
            #1;
            check32("register write port 1", rs1_data, idx == 0 ? 0 : rd_data);
            check32("register write port 2", rs2_data, idx == 0 ? 0 : rd_data);
            @(negedge clk);
        end
        rd_wren = 0;
        rd = 5'd7;
        rd_data = 32'hdead_beef;
        @(posedge clk);
        #1;
        for (int idx = 0; idx < 32; idx++) begin
            rs1 = 5'(idx);
            rs2 = 5'(31-idx);
            #1;
            check32("read port 1 / write disabled", rs1_data, idx == 0 ? 0 : (32'hcafe_0000 | 32'(idx)));
            check32("read port 2", rs2_data, idx == 31 ? 0 : (32'hcafe_0000 | 32'(31-idx)));
        end
        @(negedge clk);
        #1;
        rstn = 0;
        #1;
        check32("asynchronous reset port 1", rs1_data, 0);
        check32("asynchronous reset port 2", rs2_data, 0);
        for (int idx = 0; idx < 32; idx++) begin
            rs1 = 5'(idx);
            #1;
            check32("all registers reset", rs1_data, 0);
        end
        rstn = 1;
        $display("PASS register file");
    endtask
    task automatic memory_access(input logic [31:0] address, value,
                                 input logic [3:0] byte_mask, input logic wr, ren);
        logic valid_addr;
        logic [31:0] old_word, new_word, previous_sync;
        logic [3:0] index;
        @(negedge clk);
        previous_sync = expected_sync;
        addr = address;
        wdata = value;
        mask = byte_mask;
        wren = wr;
        rden = ren;
        valid_addr = (address >= BASE) && (address < BASE + MEM_BYTES);
        index = 4'((address - BASE) / 4);
        old_word = valid_addr ? model[index] : 0;
        new_word = old_word;
        if (wr && valid_addr) begin
            for (int lane = 0; lane < 4; lane++) begin
                if (byte_mask[lane]) new_word[8*lane +: 8] = value[8*lane +: 8];
            end
        end
        #1;
        check32("async read before edge", async_data, old_word);
        check32("sync read unchanged before edge", sync_data, previous_sync);
        @(posedge clk);
        if (wr && valid_addr) model[index] = new_word;
        if (ren) expected_sync = old_word;
        #1;
        check32("async read after edge", async_data, new_word);
        check32("sync registered read / hold / read-before-write", sync_data, expected_sync);
    endtask
    task automatic test_memories();
        logic [31:0] random_address, random_data;
        logic [5:0] flags;
        // Initialize via real writes: initial contents are unspecified by the lab.
        @(negedge clk);
        addr = BASE - 4;
        rden = 1;
        @(posedge clk);
        #1;
        expected_sync = 0;
        check32("sync invalid read", sync_data, 0);
        for (int idx = 0; idx < 16; idx++) begin
            @(negedge clk);
            addr = BASE + 32'(idx*4);
            wdata = 32'h1234_ab00 | 32'(idx);
            mask = 4'hf;
            wren = 1;
            rden = 0;
            @(posedge clk);
            #1;
            model[idx] = wdata;
        end
        for (int bm = 0; bm < 16; bm++) begin
            for (int low = 0; low < 4; low++) begin
                memory_access(BASE + 32'(low), 32'hdead_beef ^ 32'(bm), 4'(bm), 1, 1);
            end
        end
        memory_access(BASE + 63, 32'h0102_0304, 4'hf, 1, 1);
        memory_access(BASE - 1, 32'hffff_ffff, 4'hf, 1, 1);
        memory_access(BASE + 64, 32'hffff_ffff, 4'hf, 1, 1);
        memory_access(BASE + 128, 32'hffff_ffff, 4'hf, 1, 0);
        memory_access(0, 32'hffff_ffff, 4'hf, 1, 1);
        memory_access(32'hffff_ffff, 32'h0102_0304, 4'hf, 0, 1);
        for (int idx = 0; idx < 16; idx++) memory_access(BASE + 32'(idx*4), 0, 0, 0, 1);
        for (int sample = 0; sample < 512; sample++) begin
            flags = 6'(random_word());
            random_address = BASE + (random_word() % 80);
            random_data = random_word();
            memory_access(random_address, random_data, flags[3:0], flags[4], flags[5]);
        end
        for (int idx = 0; idx < 16; idx++) memory_access(BASE + 32'(idx*4), 0, 0, 0, 1);
        @(negedge clk);
        addr = 32'hffff_ffff;
        wdata = 32'h89ab_cdef;
        mask = 4'hf;
        wren = 1;
        rden = 0;
        @(posedge clk);
        #1;
        check32("minimum-size async memory", tiny_async, wdata);
        @(negedge clk);
        wren = 0;
        rden = 1;
        @(posedge clk);
        #1;
        check32("minimum-size sync memory", tiny_sync, wdata);
        @(negedge clk);
        addr = 0;
        wren = 1;
        wdata = 0;
        @(posedge clk);
        #1;
        check32("top boundary no wrap async", tiny_async, 0);
        check32("top boundary no wrap sync", tiny_sync, 0);
        @(negedge clk);
        addr = 32'hffff_fffc;
        wren = 0;
        @(posedge clk);
        #1;
        check32("top boundary write ignored async", tiny_async, 32'h89ab_cdef);
        check32("top boundary write ignored sync", tiny_sync, 32'h89ab_cdef);
        $display("PASS asynchronous and synchronous memories");
    endtask
    initial begin : run_tests
        int vector_file, scanned;
        logic [31:0] av, bv;
        a = 0; b = 0; sub = 0; unsigned_mode = 0; alu_op = 0;
        shamt = 0; shift_mode = 0;
        rstn = 1; rd_wren = 0; rs1 = 0; rs2 = 0; rd = 0; rd_data = 0;
        addr = 0; wdata = 0; mask = 0; wren = 0; rden = 0;
        if ($test$plusargs("wave")) begin
            $dumpfile("../02_test/Milestone1/wave.vcd");
            $dumpvars(0, tbench);
        end
        vector_file = $fopen("../02_test/Milestone1/datapath_vectors.txt", "r");
        if (vector_file == 0) $fatal(1, "Run from 10_sim: cannot open Milestone1 vectors");
        while (!$feof(vector_file)) begin
            scanned = $fscanf(vector_file, "%h %h", av, bv);
            if (scanned == 2) begin
                check_pair(av, bv);
                check_shifts(av);
            end else if (!$feof(vector_file)) $fatal(1, "Malformed datapath vector");
        end
        $fclose(vector_file);
        for (int sample = 0; sample < 1024; sample++) begin
            av = random_word();
            bv = random_word();
            check_pair(av, bv);
        end
        $display("PASS adder, comparator, shifter and ALU (%0d operand pairs)", pairs);
        test_regfile();
        test_memories();
        $display("MILESTONE1 PASS: %0d checks", checks);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Milestone1 timeout");
    end
endmodule
