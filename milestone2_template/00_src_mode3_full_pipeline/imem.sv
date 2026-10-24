module imem #(
    parameter logic [31:0] START_ADDR  = 32'h8000_0000,
    parameter int unsigned ADDR_WIDTH  = 19,
    parameter string       PROGRAMFILE = ""
) (
    input  logic        i_clk,
    input  logic [31:0] i_addr,
    output logic [31:0] o_data
);
// Insert your code here.
    localparam N_WORDS = (2**ADDR_WIDTH) / 4;

    logic [31:0] mem [0:N_WORDS-1];

    assign o_data = mem[i_addr[ADDR_WIDTH-1:2]];

    // Init mem
    initial begin
        $readmemh(PROGRAMFILE, mem);
    end
endmodule
