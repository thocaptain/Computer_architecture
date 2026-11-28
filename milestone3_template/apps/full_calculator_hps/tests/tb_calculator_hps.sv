`timescale 1ns / 1ps
module tb_calculator_hps #(
    parameter integer CASES = 1
);
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset_n = 0;
    reg [2:0] address = 0;
    reg write = 0;
    reg [31:0] writedata = 0;
    wire [31:0] readdata;
    wire waitrequest, irq;
    reg [31:0] vectors [0:CASES*6-1];

    hps_mcu #(.PROGRAMFILE("full_calculator_hps.mem")) dut (
        .clk(clk), .reset_n(reset_n),
        .avs_address(address), .avs_read(1'b1), .avs_write(write),
        .avs_writedata(writedata), .avs_byteenable(4'hf),
        .avs_readdata(readdata), .avs_waitrequest(waitrequest), .irq(irq),
        .i_sw(18'b0), .i_key(4'hf), .i_gpio_in(32'b0),
        .o_gpio_out(), .o_gpio_dir(), .o_ledr(), .o_ledg(), .o_ledb(), .o_hex()
    );
    task write_register(input [2:0] a, input [31:0] value);
        @(negedge clk); address=a; writedata=value; write=1;
        @(negedge clk); write=0;
    endtask
    task transfer(input [31:0] command, input [31:0] expected);
        integer cycles;
        @(negedge clk); address=1; #1;
        if (readdata !== 0) $fatal(1,"Mailbox not idle");
        write_register(2,command);
        write_register(4,1);
        address=1; #1;
        cycles=0;
        while ((readdata & 2)==0 && cycles<10000) begin
            @(negedge clk); cycles=cycles+1;
        end
        if (cycles==10000) $fatal(1,"Firmware response timeout: %h",command);
        address=3; #1;
        if (readdata !== expected)
            $fatal(1,"Command %h got %h expected %h",command,readdata,expected);
        write_register(4,2);
    endtask
    integer index;
    reg [31:0] a,b,operation,value,remainder,error;
    initial begin
        $readmemh("vectors.mem",vectors);
        repeat(4) @(negedge clk);
        reset_n=1;
        transfer(32'hca000000,32'h43414c31);
        transfer(32'h12345678,32'h80000001);
        transfer(32'hca110000,32'h80000003);
        transfer(32'hca010001,0);
        transfer(32'hca100000,32'h80000002);
        transfer(32'hca100004,32'h80000001);
        for (index=0; index<CASES; index=index+1) begin
            a=vectors[index*6]; b=vectors[index*6+1]; operation=vectors[index*6+2];
            value=vectors[index*6+3]; remainder=vectors[index*6+4]; error=vectors[index*6+5];
            transfer(32'hca000000,32'h43414c31);
            transfer(32'hca010000 | (a & 32'hffff),0);
            transfer(32'hca020000 | (a >> 16),0);
            transfer(32'hca030000 | (b & 32'hffff),0);
            transfer(32'hca040000 | (b >> 16),0);
            transfer(32'hca100000 | operation,error);
            transfer(32'hca110000,value);
            transfer(32'hca120000,remainder);
        end
        @(negedge clk); reset_n=0;
        repeat(4) @(negedge clk);
        reset_n=1;
        transfer(32'hca000000,32'h43414c31);
        transfer(32'hca110000,32'h80000003);
        $display("PASS: %0d complete HPS -> real RV32I calculator -> mailbox cases, protocol errors and reset",CASES);
        $finish;
    end
    initial begin #200000000; $fatal(1,"Global timeout"); end
endmodule
