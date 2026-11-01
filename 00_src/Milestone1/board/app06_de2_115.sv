// DE2-115 physical wrapper. CPU clock = 50 MHz / 10 = 5 MHz.
module app06_de2_115
    import rv32i_pkg::*;
#(parameter integer DEBOUNCE_CYCLES = 50000)(
    input logic CLOCK_50,
    input logic [17:0] SW,
    input logic [3:0] KEY,
    output wire [17:0] LEDR,
    output wire [8:0] LEDG,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
    output logic [7:0] LCD_DATA,
    output logic LCD_EN, LCD_RS,
    output wire LCD_RW, LCD_ON
);
    logic [2:0] divide_count = 0;
    logic cpu_clk = 0;
    // Free running: the CPU must continue receiving edges during reset.
    always_ff @(posedge CLOCK_50) begin
        if (divide_count == 4) begin
            divide_count <= 0;
            cpu_clk <= ~cpu_clk;
        end else divide_count <= divide_count + 1'b1;
    end
    logic [3:0] reset_sync = 0;
    always_ff @(posedge cpu_clk or negedge KEY[3]) begin
        if (!KEY[3]) reset_sync <= 0;
        else reset_sync <= {reset_sync[2:0], 1'b1};
    end
    wire rst_n = reset_sync[3];
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
    logic [20:0] input_meta, input_sync;
    logic [20:0] stable_inputs;
    logic [31:0] debounce_count [0:20];
    always_ff @(posedge cpu_clk) begin
        if (!rst_n) begin
            input_meta <= 0;
            input_sync <= 0;
            stable_inputs <= 0;
            for (integer i=0; i<21; i=i+1) debounce_count[i] <= 0;
        end else begin
            input_meta <= {~KEY[2:0], SW};
            input_sync <= input_meta;
            for (integer i=0; i<21; i=i+1) begin
                if (input_sync[i] == stable_inputs[i]) debounce_count[i] <= 0;
                else if (debounce_count[i] == DEBOUNCE_CYCLES-1) begin
                    stable_inputs[i] <= input_sync[i];
                    debounce_count[i] <= 0;
                end else debounce_count[i] <= debounce_count[i] + 1'b1;
            end
        end
    end
    wire [31:0] ledr_word, ledg_word, lcd_word;
    wire [6:0] digit [0:7];
    wire lcd_valid;
    wire [31:0] pc_debug;
    TOP_SINGLE_CYCLE #(.INST_MEM_ADDR_W(13), .MEM_TYPE(MEM_FLOP), .CACHE(0)) cpu (
        .i_clk(cpu_clk), .i_rst_n(rst_n), .o_pc_debug(pc_debug), .o_insn_vld(),
        .i_io_sw({14'b0,stable_inputs[17:0]}), .i_io_btn({1'b0,stable_inputs[20:18]}),
        .o_io_ledr(ledr_word), .o_io_ledg(ledg_word),
        .o_io_hex0(digit[0]), .o_io_hex1(digit[1]), .o_io_hex2(digit[2]), .o_io_hex3(digit[3]),
        .o_io_hex4(digit[4]), .o_io_hex5(digit[5]), .o_io_hex6(digit[6]), .o_io_hex7(digit[7]),
        .o_io_lcd(lcd_word), .o_lcd_vld(lcd_valid),
        .SRAM_ADDR(), .SRAM_DQ(), .SRAM_CE_N(), .SRAM_WE_N(),
        .SRAM_LB_N(), .SRAM_UB_N(), .SRAM_OE_N()
    );
    assign LEDR = ledr_word[17:0];
    assign LEDG = ledg_word[8:0];
    function automatic logic [6:0] decode_hex(input logic [3:0] value);
        // Legacy package omits segment d for 9. Correct it in this wrapper.
        decode_hex = (value == 4'h9) ? 7'h10 : bcd_to_7seg(value);
    endfunction
    assign HEX0 = decode_hex(digit[0][3:0]);
    assign HEX1 = decode_hex(digit[1][3:0]);
    assign HEX2 = decode_hex(digit[2][3:0]);
    assign HEX3 = decode_hex(digit[3][3:0]);
    assign HEX4 = decode_hex(digit[4][3:0]);
    assign HEX5 = decode_hex(digit[5][3:0]);
    assign HEX6 = decode_hex(digit[6][3:0]);
    assign HEX7 = decode_hex(digit[7][3:0]);

    // LSU updates lcd_word on the lcd_valid edge. Delay valid by one cycle.
    // 200 ns setup, 600 ns EN high, then data held until the next transaction.
    logic lcd_pending;
    logic [2:0] lcd_phase;
    assign LCD_RW = 1'b0; // firmware is write-only; no bus turnaround
    assign LCD_ON = rst_n;
    always_ff @(posedge cpu_clk) begin
        if (!rst_n) begin
            lcd_pending <= 0;
            lcd_phase <= 0;
            LCD_DATA <= 0;
            LCD_RS <= 0;
            LCD_EN <= 0;
        end else begin
            lcd_pending <= lcd_valid;
            if (lcd_phase == 0) begin
                if (lcd_pending) begin
                    LCD_DATA <= lcd_word[7:0];
                    LCD_RS <= lcd_word[9];
                    lcd_phase <= 1;
                end
            end else begin
                lcd_phase <= (lcd_phase == 5) ? 3'd0 : lcd_phase + 1'b1;
                if (lcd_phase == 1) LCD_EN <= 1;
                if (lcd_phase == 4) LCD_EN <= 0;
            end
        end
    end
endmodule
