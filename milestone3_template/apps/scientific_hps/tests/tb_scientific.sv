`timescale 1ns / 1ps
module tb_scientific #(parameter integer CASES=1);
    reg clk=0;
    always #5 clk=~clk;
    reg reset_n=0;
    reg [2:0] address=0;
    reg write=0;
    reg [31:0] writedata=0;
    wire [31:0] readdata;
    wire waitrequest,irq;
    reg [31:0] vectors [0:CASES*6-1];
    hps_mcu #(.PROGRAMFILE("scientific_hps.mem")) dut (
        .clk(clk), .reset_n(reset_n), .avs_address(address), .avs_read(1'b1),
        .avs_write(write), .avs_writedata(writedata), .avs_byteenable(4'hf),
        .avs_readdata(readdata), .avs_waitrequest(waitrequest), .irq(irq),
        .i_sw(18'b0), .i_key(4'hf), .i_gpio_in(32'b0),
        .o_gpio_out(), .o_gpio_dir(), .o_ledr(), .o_ledg(), .o_ledb(), .o_hex()
    );
    integer max_difference=0;
    task write_register(input [2:0] a,input [31:0] value);
        @(negedge clk); address=a; writedata=value; write=1;
        @(negedge clk); write=0;
    endtask
    task transfer(input [31:0] command,input [31:0] expected,input integer tolerance);
        integer cycles;
        longint signed difference;
        @(negedge clk); address=1; #1;
        if (readdata!==0) $fatal(1,"Mailbox busy");
        write_register(2,command); write_register(4,1);
        address=1; #1; cycles=0;
        while ((readdata&2)==0 && cycles<200000) begin @(negedge clk); cycles=cycles+1; end
        if (cycles==200000) $fatal(1,"CPU timeout: %h",command);
        address=3; #1;
        difference=longint'($signed(readdata))-longint'($signed(expected));
        if (difference<0) difference=-difference;
        if (tolerance==0 && readdata!==expected)
            $fatal(1,"Command %h returned %h expected %h",command,readdata,expected);
        if (tolerance>0) begin
            if (difference>tolerance)
                $fatal(1,"Numeric mismatch: command=%h actual=%0d expected=%0d diff=%0d",command,$signed(readdata),$signed(expected),difference);
            if (difference>max_difference) max_difference=integer'(difference);
        end
        write_register(4,2);
    endtask
    integer index;
    reg [31:0] argument,operation,value,error,operand_b,remainder;
    initial begin
        $readmemh("vectors.mem",vectors);
        repeat(4) @(negedge clk); reset_n=1;
        transfer(32'h53430000,32'h53434932,0);
        transfer(32'h53510000,32'h80000003,0);
        transfer(32'h53500000,32'h80000002,0);
        transfer(32'h53500007,32'h80000001,0);
        for (index=0;index<CASES;index=index+1) begin
            argument=vectors[index*6]; operation=vectors[index*6+1];
            value=vectors[index*6+2]; error=vectors[index*6+3];
            operand_b=vectors[index*6+4]; remainder=vectors[index*6+5];
            transfer(32'h53430000,32'h53434932,0);
            transfer(32'h53410000|(argument&32'hffff),0,0);
            transfer(32'h53420000|(argument>>16),0,0);
            if (operation>=3) begin
                transfer(32'h53500000|operation,32'h80000002,0);
                transfer(32'h53440000|(operand_b&32'hffff),0,0);
                transfer(32'h53450000|(operand_b>>16),0,0);
            end
            transfer(32'h53500000|operation,error,0);
            transfer(32'h53510000,value,error==0 && operation<3 ? 1 : 0);
            transfer(32'h53520000,remainder,0);
        end
        @(negedge clk); reset_n=0;
        repeat(4) @(negedge clk); reset_n=1;
        transfer(32'h53430000,32'h53434932,0);
        transfer(32'h53510000,32'h80000003,0);
        $display("PASS: %0d combined scientific/arithmetic real-RV32I mailbox cases; maximum error=%0d thousandths",CASES,max_difference);
        $finish;
    end
    initial begin #2000000000; $fatal(1,"Global timeout"); end
endmodule
