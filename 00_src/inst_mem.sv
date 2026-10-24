`include "rv32i.svh"

module inst_mem #(
    parameter ADDR_W = 32
)(
    /* verilator lint_off UNUSEDSIGNAL */
      input  logic [ADDR_W-1:0] i_addr
    /* verilator lint_off UNUSEDSIGNAL */
    , output logic [31:0]       o_inst
);
    localparam N_WORDS = (2**ADDR_W) / 4;

    logic [31:0] mem [0:N_WORDS-1];
    
    assign o_inst = mem[i_addr[ADDR_W-1:2]];


    // Init mem
    initial begin
`ifdef DV
        string program_path;
        integer program_file;
        if (!$value$plusargs("PROG=%s", program_path))
            program_path = `INST_MEM_PATH;
        program_file = $fopen(program_path, "r");
        if (program_file == 0)
            $fatal(1, "Cannot open instruction ROM: %s", program_path);
        $fclose(program_file);
        $readmemh(program_path, mem);
`else
        $readmemh(`INST_MEM_PATH, mem);
`endif
    end
endmodule
