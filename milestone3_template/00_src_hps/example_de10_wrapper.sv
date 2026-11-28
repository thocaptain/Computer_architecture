
//=======================================================
//  DE10 board wrapper for the Milestone 3 MCU (no LCD)
//=======================================================

module example_de10_wrapper(

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,
	input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// Seg7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	output		     [6:0]		HEX4,
	output		     [6:0]		HEX5,

	//////////// SDRAM //////////
	output		    [12:0]		DRAM_ADDR,
	output		     [1:0]		DRAM_BA,
	output		          		DRAM_CAS_N,
	output		          		DRAM_CKE,
	output		          		DRAM_CLK,
	output		          		DRAM_CS_N,
	inout 		    [15:0]		DRAM_DQ,
	output		          		DRAM_LDQM,
	output		          		DRAM_RAS_N,
	output		          		DRAM_UDQM,
	output		          		DRAM_WE_N
);



//=======================================================
//  REG/WIRE declarations
//=======================================================




//=======================================================
//  Structural coding
//=======================================================

// MCU virtual I/O uses the original Milestone 3 memory map and programs.
// SW9 -> virtual SW17 (RUN); SW8 -> virtual SW16 (input decimal page).
// Physical SW[6:0] retains its original software role.
wire [17:0] mcu_switches = {SW[9], SW[8], 7'b0, SW[8:0]};
wire [17:0] mcu_red;
wire [7:0]  mcu_green;
wire [6:0] mcu_hex0, mcu_hex1, mcu_hex2, mcu_hex3;
wire [6:0] mcu_hex4, mcu_hex5, mcu_hex6, mcu_hex7;

example_de2_wrapper #(
    .CLOCK_DIV_LOG2 (1),
    .IMEM_ADDR_WIDTH(12),
    .DMEM_ADDR_WIDTH(10)
) mcu_board (
    .CLOCK_50(CLOCK_50),
    .KEY(KEY),
    .SW(mcu_switches),
    .LEDR(mcu_red),
    .LEDG(mcu_green),
    .HEX0(mcu_hex0), .HEX1(mcu_hex1),
    .HEX2(mcu_hex2), .HEX3(mcu_hex3),
    .HEX4(mcu_hex4), .HEX5(mcu_hex5),
    .HEX6(mcu_hex6), .HEX7(mcu_hex7),
    .GPIO()
);

// DE10 has no green LED bank in this project. Show MCU status on LEDR[7:0].
assign LEDR[7:0] = mcu_green;
assign LEDR[8]   = SW[4];
assign LEDR[9]   = SW[9];

// Six physical HEX displays expose two windows of eight virtual HEX registers.
// SW7=0: virtual HEX5..HEX0. SW7=1: virtual HEX7..HEX2 (includes sign).
// This window is independent of the software decimal page selected by KEY3.
assign HEX0 = SW[7] ? mcu_hex2 : mcu_hex0;
assign HEX1 = SW[7] ? mcu_hex3 : mcu_hex1;
assign HEX2 = SW[7] ? mcu_hex4 : mcu_hex2;
assign HEX3 = SW[7] ? mcu_hex5 : mcu_hex3;
assign HEX4 = SW[7] ? mcu_hex6 : mcu_hex4;
assign HEX5 = SW[7] ? mcu_hex7 : mcu_hex5;

// This build uses internal MCU memories; SDRAM is not connected to the CPU.
assign DRAM_ADDR  = 13'b0;
assign DRAM_BA    = 2'b0;
assign DRAM_CAS_N = 1'b1;
assign DRAM_CKE   = 1'b0;
assign DRAM_CLK   = 1'b0;
assign DRAM_CS_N  = 1'b1;
assign DRAM_DQ    = 16'bz;
assign DRAM_LDQM  = 1'b1;
assign DRAM_RAS_N = 1'b1;
assign DRAM_UDQM  = 1'b1;
assign DRAM_WE_N  = 1'b1;


endmodule
