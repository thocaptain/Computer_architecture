`timescale 1ns/1ps

// Exercise the CPU/memory interfaces with 16-word lines and 8 direct-mapped slots.
// Addresses 0x000 and 0x200 conflict. Memory accepts one word every four cycles.
module tbench;
    logic clk;
    logic rst_n = 1'b0;
    logic [11:0] addr = '0;
    logic [31:0] wdata = '0;
    logic [3:0] bmask = '0;
    logic wren = 1'b0;
    logic valid = 1'b0;
    logic [31:0] rdata;
    logic ready;
    logic [11:0] mem_addr;
    logic [31:0] mem_wdata, mem_rdata;
    logic [3:0] mem_bmask;
    logic mem_wren, mem_valid, mem_ready;
    logic [31:0] memory [0:1023];
    int unsigned ticks;
    int unsigned reads;
    int unsigned writes;

    cache #(.TOTAL_ADDR_W(12), .OFFSET_ADDR_W(4), .IDX_ADDR_W(3)) dut (
        .i_clk(clk), .i_rst_n(rst_n),
        .i_ADDR(addr), .i_WDATA(wdata), .i_BMASK(bmask), .i_WREN(wren),
        .o_RDATA(rdata), .i_VALID(valid), .o_READY(ready),
        .o_mem_ADDR(mem_addr), .o_mem_WDATA(mem_wdata), .o_mem_BMASK(mem_bmask),
        .o_mem_WREN(mem_wren), .i_mem_RDATA(mem_rdata),
        .o_mem_VALID(mem_valid), .i_mem_READY(mem_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    assign mem_rdata = memory[mem_addr[11:2]];
    assign mem_ready = rst_n && mem_valid && (ticks[1:0] == 2'b11);

    always @(posedge clk) begin
        if (!rst_n) begin
            ticks <= 0;
            reads <= 0;
            writes <= 0;
        end else begin
            ticks <= ticks + 1;
            if (mem_valid && mem_ready) begin
                assert (mem_addr[1:0] == 0 && mem_bmask == 4'b1111)
                    else $fatal(1, "Unexpected line-transfer address or byte mask");
                if (mem_wren) begin
                    writes <= writes + 1;
                    memory[mem_addr[11:2]] <= mem_wdata;
                end else begin
                    reads <= reads + 1;
                end
            end
        end
    end

    task automatic access_cpu(input bit store, input logic [11:0] address,
                              input logic [31:0] data, input logic [3:0] mask,
                              input logic [31:0] expected);
        @(negedge clk);
        addr = address;
        wdata = data;
        bmask = mask;
        wren = store;
        valid = 1'b1;
        @(posedge clk);
        while (!ready) @(posedge clk);
        if (!store) begin
            assert (rdata == expected)
                else $fatal(1, "Read %h: got %h expected %h", address, rdata, expected);
        end
        @(negedge clk);
        valid = 1'b0;
    endtask

    task automatic traffic(input int unsigned expected_reads, expected_writes);
        assert (reads == expected_reads && writes == expected_writes)
            else $fatal(1, "Traffic: reads=%0d writes=%0d expected=%0d/%0d",
                        reads, writes, expected_reads, expected_writes);
    endtask

    initial begin
        for (int i = 0; i < 1024; i++) memory[i] = 32'hA5000000 | 32'(i);
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        access_cpu(0, 12'h000, 0, 0, 32'hA5000000); // cold miss
        traffic(16, 0);
        access_cpu(0, 12'h03C, 0, 0, 32'hA500000F); // another word in the same line
        traffic(16, 0);
        access_cpu(0, 12'h200, 0, 0, 32'hA5000080); // clean eviction: no writes
        traffic(32, 0);

        access_cpu(1, 12'h200, 32'hDEADBEEF, 4'b1111, 0);
        access_cpu(0, 12'h200, 0, 0, 32'hDEADBEEF); // dirty hit reads immediately
        traffic(32, 0);
        assert (memory[128] == 32'hA5000080)
            else $fatal(1, "Store must stay in cache until eviction");
        access_cpu(1, 12'h204, 32'h0000007A, 4'b0001, 0);
        access_cpu(1, 12'h204, 32'h00B60000, 4'b0100, 0);
        access_cpu(0, 12'h204, 0, 0, 32'hA5B6007A);

        access_cpu(0, 12'h000, 0, 0, 32'hA5000000); // dirty eviction
        traffic(48, 16);
        assert (memory[128] == 32'hDEADBEEF && memory[129] == 32'hA5B6007A)
            else $fatal(1, "Write-back lost full-word or byte stores");
        for (int i = 2; i < 16; i++) begin
            assert (memory[128+i] == (32'hA5000080 | 32'(i)))
                else $fatal(1, "Write-back corrupted untouched word %0d", i);
        end

        access_cpu(0, 12'h200, 0, 0, 32'hDEADBEEF); // reload stored data
        traffic(64, 16);
        access_cpu(0, 12'h000, 0, 0, 32'hA5000000); // refilled line is clean again
        traffic(80, 16);

        access_cpu(1, 12'h200, 32'h11223344, 4'b0011, 0); // store miss allocates
        access_cpu(0, 12'h200, 0, 0, 32'hDEAD3344);
        traffic(96, 16);
        access_cpu(0, 12'h000, 0, 0, 32'hA5000000);
        traffic(112, 32);
        assert (memory[128] == 32'hDEAD3344)
            else $fatal(1, "Store miss did not mark the allocated line dirty");

        access_cpu(1, 12'h000, 32'hFFFFFFFF, 4'b0000, 0); // no bytes changed
        access_cpu(0, 12'h200, 0, 0, 32'hDEAD3344);
        traffic(128, 32);

        $display("PASS cache dirty: cold/clean/dirty eviction, dirty hit, byte masks, store miss, refill clean; reads=%0d writes=%0d",
                 reads, writes);
        $finish;
    end

    initial begin
        repeat (5000) @(negedge clk);
        $fatal(1, "Cache request timed out");
    end
endmodule
