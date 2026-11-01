`timescale 1ns/1ps
// Five mux stages. Reverse bits to share the right-shift network with SLL.
module shifter (
    input  logic [31:0] i_data,
    input  logic [4:0]  i_shamt,
    input  logic [1:0]  i_mode,
    output logic [31:0] o_data
);
    logic [31:0] input_data;
    logic [31:0] shifted;
    logic fill_bit;
    assign fill_bit = (i_mode == 2'b10) & i_data[31];
    for (genvar bit_idx = 0; bit_idx < 32; bit_idx++) begin : g_reverse
        assign input_data[bit_idx] = (i_mode == 2'b01) ? i_data[31-bit_idx] : i_data[bit_idx];
        assign shifted[bit_idx] = (i_mode == 2'b01) ? g_stage[4].result[31-bit_idx] : g_stage[4].result[bit_idx];
    end
    for (genvar stage_idx = 0; stage_idx < 5; stage_idx++) begin : g_stage
        logic [31:0] source_data, result;
        if (stage_idx == 0) begin : g_first
            assign source_data = input_data;
        end else begin : g_next
            assign source_data = g_stage[stage_idx-1].result;
        end
        for (genvar bit_idx = 0; bit_idx < 32; bit_idx++) begin : g_mux
            if ((bit_idx + 2**stage_idx) < 32) begin : g_data
                assign result[bit_idx] = i_shamt[stage_idx] ?
                    source_data[bit_idx + 2**stage_idx] : source_data[bit_idx];
            end else begin : g_fill
                assign result[bit_idx] = i_shamt[stage_idx] ? fill_bit : source_data[bit_idx];
            end
        end
    end
    assign o_data = (i_mode == 2'b11) ? 32'b0 : shifted;
endmodule
