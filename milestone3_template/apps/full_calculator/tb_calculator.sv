`timescale 1ns/1ps
module tb_calculator;
    logic clk=0, rstn=0;
    logic [17:0] sw=0;
    logic [3:0] key=4'hf;
    wire [31:0] green;
    wire [7:0][6:0] hex;
    always #5 clk=~clk;
    milestone3 #(.PROGRAMFILE("full_calculator.mem"),
                 .IMEM_ADDR_WIDTH(12), .DMEM_ADDR_WIDTH(10)) dut (
        .i_clk(clk), .i_rstn(rstn), .i_sw(sw), .i_key(key),
        .o_ledr(), .o_ledg(green), .o_ledb(),
        .o_hex0(hex[0]), .o_hex1(hex[1]), .o_hex2(hex[2]), .o_hex3(hex[3]),
        .o_hex4(hex[4]), .o_hex5(hex[5]), .o_hex6(hex[6]), .o_hex7(hex[7]),
        .i_gpio_in(32'b0), .o_gpio_out(), .o_gpio_dir(),
        .o_event_valid(), .o_event_data(), .o_print_valid(), .o_print_char(),
        .o_halt(), .o_db_valid()
    );
    task automatic settle;
        repeat(1600000) @(negedge clk);
    endtask
    task automatic press(input int bit_index);
        key[bit_index]=0;
        settle();
        key[bit_index]=1;
        settle();
    endtask
    task automatic enter_number(input int value);
        string digits;
        digits=$sformatf("%0d", value);
        for(int i=0;i<digits.len();i++) begin
            if(digits.getc(i)!=8'd45) begin
                sw=18'(digits.getc(i)-8'd48);
                sw[4]=(value<0);
                press(1);
            end
        end
        press(2);
    endtask
    task automatic start_calc(input int a, input int b, input int operation);
        enter_number(a);
        if(!green[1]) $fatal(1,"Did not enter B state");
        enter_number(b);
        if(!green[2]) $fatal(1,"Did not enter operation state");
        sw=18'(operation<<5);
        settle();
        sw[17]=1;
        settle();
        if(!green[3]) $fatal(1,"Did not enter result state");
    endtask
    task automatic restart_calc;
        sw=0;
        settle();
        if(!green[0] || green[7]) $fatal(1,"Restart failed");
    endtask
    task automatic expect_error(input int code);
        if(!green[7]) $fatal(1,"Expected error");
        if(code==1 && hex[0]!==~7'h06) $fatal(1,"Expected Err1");
        if(code==2 && hex[0]!==~7'h5b) $fatal(1,"Expected Err2");
    endtask
    initial begin
        repeat(4) @(negedge clk);
        rstn=1;
        settle();
        if(!green[0]) $fatal(1,"Boot failed");
        // Negative multiplication: -12 * 5 = -60.
        start_calc(-12,5,2);
        if(green[7] || hex[7]!==~7'h40 || hex[1]!==~7'h7d || hex[0]!==~7'h3f)
            $fatal(1,"-12*5 display failed green=%h HEX=%h",green,hex);
        restart_calc();
        // Signed division: -12 / 5 = -2 remainder -2.
        start_calc(-12,5,3);
        if(green[7] || hex[7]!==~7'h40 || hex[0]!==~7'h5b)
            $fatal(1,"Signed quotient failed");
        press(3);
        if(!green[5] || hex[7]!==~7'h40 || hex[0]!==~7'h5b)
            $fatal(1,"Signed remainder failed");
        restart_calc();
        start_calc(-12,5,0); // -7
        if(green[7] || hex[7]!==~7'h40 || hex[0]!==~7'h07)
            $fatal(1,"Signed addition failed");
        restart_calc();
        start_calc(12,5,1); // +7
        if(green[7] || hex[7]!==7'h7f || hex[0]!==~7'h07)
            $fatal(1,"Subtraction failed");
        restart_calc();
        start_calc(1,0,3);
        expect_error(1);
        restart_calc();
        start_calc(2147483647,1,0);
        expect_error(2);
        restart_calc();
        start_calc(-2147483648,1,3);
        if(green[7] || hex[7]!==~7'h40 || hex[0]!==~7'h7f)
            $fatal(1,"INT_MIN lower page failed");
        press(3);
        if(!green[4] || hex[2]!==~7'h5b || hex[1]!==~7'h06 || hex[0]!==~7'h66)
            $fatal(1,"INT_MIN upper page failed");
        restart_calc();
        $display("PASS RTL: boot, all four operations, signed remainder, errors, INT_MIN pages, restart");
        $finish;
    end
    initial begin
        #10000000000;
        $fatal(1,"Global timeout");
    end
endmodule
