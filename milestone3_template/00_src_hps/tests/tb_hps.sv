`timescale 1ns/1ps
module tb_hps;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset_n = 0;
    reg [2:0] address = 0;
    reg rd = 1, wr = 0;
    reg [31:0] data = 0;
    reg [3:0] mask = 15;
    wire [31:0] result;
    wire waitrequest, irq;
    reg [2:0] ca = 0;
    reg cw = 0;
    reg [31:0] cd = 0;
    reg [3:0] cm = 15;
    wire [31:0] cr;
    hps_mailbox unit_dut (
        .clk(clk), .reset_n(reset_n), .avs_address(address), .avs_read(rd),
        .avs_write(wr), .avs_writedata(data), .avs_byteenable(mask),
        .avs_readdata(result), .avs_waitrequest(waitrequest),
        .cpu_address(ca), .cpu_wren(cw), .cpu_wdata(cd),
        .cpu_byteenable(cm), .cpu_rdata(cr), .irq(irq)
    );
    reg [2:0] ma = 0;
    reg mw = 0;
    reg [31:0] md = 0;
    reg [3:0] mm = 15;
    wire [31:0] mr;
    wire mi, m_wait;
    hps_mcu #(.PROGRAMFILE("hps_mailbox.mem")) system_dut (
        .clk(clk), .reset_n(reset_n), .avs_address(ma), .avs_read(1'b1),
        .avs_write(mw), .avs_writedata(md), .avs_byteenable(mm),
        .avs_readdata(mr), .avs_waitrequest(m_wait), .irq(mi),
        .i_sw(18'b0), .i_key(4'hf), .i_gpio_in(32'b0),
        .o_gpio_out(), .o_gpio_dir(), .o_ledr(), .o_ledg(), .o_ledb(), .o_hex()
    );
    task host_write(input [2:0] a, input [31:0] d, input [3:0] b);
        @(negedge clk); address=a; data=d; mask=b; wr=1;
        @(negedge clk); wr=0;
    endtask
    task cpu_write(input [2:0] a, input [31:0] d, input [3:0] b);
        @(negedge clk); ca=a; cd=d; cm=b; cw=1;
        @(negedge clk); cw=0;
    endtask
    task check_reg(input [2:0] a, input [31:0] expected);
        @(negedge clk); address=a; #1;
        if (result !== expected) $fatal(1,"register %0d: got %h expected %h",a,result,expected);
    endtask
    task mwrite(input [2:0] a, input [31:0] d);
        @(negedge clk); ma=a; md=d; mw=1;
        @(negedge clk); mw=0;
    endtask
    task transaction(input [31:0] command, input [31:0] expected);
        integer cycles;
        mwrite(2,command); mwrite(4,1);
        ma=1;
        cycles=0;
        while ((mr & 2)==0 && cycles<250) begin
            @(negedge clk); cycles=cycles+1;
        end
        if (cycles==250) $fatal(1,"CPU mailbox timeout");
        ma=3; #1;
        if (mr !== expected) $fatal(1,"CPU returned %h expected %h",mr,expected);
        mwrite(4,2); ma=1; #1;
        if (mr !== 0) $fatal(1,"CPU mailbox did not return idle");
    endtask
    initial begin
        #2; reset_n=0;
        repeat(3) @(negedge clk);
        reset_n=1;
        check_reg(0,32'h48505331);
        check_reg(1,0);
        host_write(2,32'h11223344,15);
        host_write(2,32'haabbccdd,5);
        check_reg(2,32'h11bb33dd);
        host_write(4,1,0); check_reg(1,0); // masked doorbell ignored
        host_write(4,1,1); check_reg(1,1);
        host_write(2,32'hdeadbeef,15);
        host_write(4,1,1); // busy start and command overwrite ignored
        check_reg(2,32'h11bb33dd);
        cpu_write(3,32'hdeadbeef,15);
        cpu_write(3,32'h00000055,1);
        check_reg(3,32'hdeadbe55);
        host_write(5,1,1);
        if (irq) $fatal(1,"IRQ raised before CPU completion");
        cpu_write(4,1,1); check_reg(1,2);
        if (!irq) $fatal(1,"Missing response IRQ");
        // Response remains stable until host ACK; CPU cannot overwrite it.
        cpu_write(3,0,15); host_write(2,0,15);
        check_reg(3,32'hdeadbe55);
        host_write(4,1,1); check_reg(1,2);
        host_write(4,2,1); check_reg(1,0);
        if (irq) $fatal(1,"IRQ did not clear on ACK");
        check_reg(6,0); check_reg(7,0);
        transaction(41,42);
        transaction(32'hffffffff,0);
        transaction(123456,123457);
        @(negedge clk); reset_n=0;
        @(negedge clk); reset_n=1;
        check_reg(1,0); check_reg(2,0); check_reg(3,0);
        transaction(0,1);
        $display("PASS: byte enables, ownership, busy rejection, IRQ, reset and real RV32I round trips");
        $finish;
    end
    initial begin #50000; $fatal(1,"Global test timeout"); end
endmodule
