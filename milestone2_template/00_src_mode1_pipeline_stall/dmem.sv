module dmem #(
    parameter logic [31:0] START_ADDR = 32'h8008_0000,
    parameter int unsigned ADDR_WIDTH = 16
) (
    input  logic        i_clk,
    input  logic [31:0] i_addr,
    input  logic [31:0] i_wdata,
    input  logic [ 3:0] i_bmsk,
    input  logic        i_wren,
    output logic [31:0] o_rdata
);
// Insert your code here.
    localparam N_WORDS = (2**ADDR_WIDTH) / 4;

    logic [3:0][7:0] mem [0:N_WORDS-1];

    assign o_rdata = mem[i_addr[ADDR_WIDTH-1:2]];

    always_ff @(posedge i_clk) begin
        if (i_wren) begin
            if (i_bmsk[0]) mem[i_addr[ADDR_WIDTH-1:2]][0] <= i_wdata[8*0+:8];
            if (i_bmsk[1]) mem[i_addr[ADDR_WIDTH-1:2]][1] <= i_wdata[8*1+:8];
            if (i_bmsk[2]) mem[i_addr[ADDR_WIDTH-1:2]][2] <= i_wdata[8*2+:8];
            if (i_bmsk[3]) mem[i_addr[ADDR_WIDTH-1:2]][3] <= i_wdata[8*3+:8];
        end
    end
endmodule
