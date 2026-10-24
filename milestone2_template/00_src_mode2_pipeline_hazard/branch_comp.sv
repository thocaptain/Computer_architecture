module branch_comp (
      input logic [31:0] i_rs1_data
    , input logic [31:0] i_rs2_data
    , input logic        i_br_un 

    , output logic       o_br_eq
    , output logic       o_br_lt
);

logic [32:0] sign_rs1; // extra sign bit
logic [32:0] sign_rs2; // extra sign bit
logic [32:0] usign_rs1; // extra sign bit
logic [32:0] usign_rs2; // extra sign bit
logic [32:0] negative_usign_rs2; // extra sign bit
logic [32:0] negative_sign_rs2; // extra sign bit
/* verilator lint_off UNUSEDSIGNAL */
logic [32:0] sub_usign; // extra sign bit
logic [32:0] sub_sign; // extra sign bit
/* verilator lint_off UNUSEDSIGNAL */

always_comb begin
    usign_rs1    = {1'b0, i_rs1_data};
    usign_rs2    = {1'b0, i_rs2_data};

    sign_rs1     = {i_rs1_data[31], i_rs1_data};
    sign_rs2     = {i_rs2_data[31], i_rs2_data};

    negative_usign_rs2 = 33'((~usign_rs2) + 33'b1); // extra sign bit
    negative_sign_rs2   = 33'((~sign_rs2) + 33'b1); // extra sign bit

    sub_usign = 33'(usign_rs1 + negative_usign_rs2);
    sub_sign  = 33'(sign_rs1  + negative_sign_rs2);

    o_br_eq = i_rs1_data == i_rs2_data;
    o_br_lt = (i_br_un)? sub_usign[32] : sub_sign[32];
end

endmodule
