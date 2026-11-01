// Harvard instruction ROM. Firmware literals are immediate instructions.
module inst_mem #(parameter ADDR_W = 13)(
    input logic [ADDR_W-1:0] i_addr,
    output wire [31:0] o_inst
);
    logic [31:0] mem [0:(2**(ADDR_W-2))-1];
    assign o_inst = mem[i_addr[ADDR_W-1:2]];
    initial $readmemh("app06.mem", mem);
endmodule
