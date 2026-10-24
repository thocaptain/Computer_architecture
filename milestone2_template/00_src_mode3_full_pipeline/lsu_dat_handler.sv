module lsu_dat_handler 
    import rv32i_pkg::*;
(
      input  logic [FUNCT3_WIDTH-1:0] i_funct3
   ,  input  logic [1:0]              i_lsb_addr // just need two LSBs to evaluate

    , input  logic [31:0]             i_st_data
    , output logic [31:0]             o_st_data
    , output logic [3:0]              o_st_strb

    , input  logic [31:0]             i_ld_data
    , output logic [31:0]             o_ld_data
);
    logic [3:0] byte_sign;

    logic is_unsigned;

    always_comb begin
        is_unsigned =  i_funct3[2];

        byte_sign[0] = (is_unsigned)? 1'b0 : i_ld_data[7];
        byte_sign[1] = (is_unsigned)? 1'b0 : i_ld_data[15];
        byte_sign[2] = (is_unsigned)? 1'b0 : i_ld_data[23];
        byte_sign[3] = (is_unsigned)? 1'b0 : i_ld_data[31];
    end

    always_comb begin
        case (i_funct3[1:0])
            2'b10: begin // word
                o_st_data = i_st_data;
                o_st_strb = 4'b1111;
                o_ld_data = i_ld_data;
            end
            2'b01: begin // half
                case (i_lsb_addr[1])
                    1'b0: begin 
                        o_st_strb = 4'b0011;
                        o_st_data = {16'b0, i_st_data[15:0]};
                        o_ld_data = {{16{byte_sign[1]}},i_ld_data[15:0]};
                    end
                    1'b1: begin
                        o_st_strb = 4'b1100;
                        o_st_data = {i_st_data[15:0], 16'b0};
                        o_ld_data = {{16{byte_sign[3]}},i_ld_data[31:16]};
                    end
                    default: begin
                        o_st_strb = '0;
                        o_st_data = '0;
                        o_ld_data = '0;
                    end
                endcase
            end
            2'b00: begin // byte
                case (i_lsb_addr)
                    2'b00: begin
                        o_st_strb = 4'b0001; 
                        o_st_data = {24'b0, i_st_data[7:0]};
                        o_ld_data = {{24{byte_sign[0]}},i_ld_data[7:0]};
                    end
                    2'b01: begin
                        o_st_strb = 4'b0010;
                        o_st_data = {16'b0, i_st_data[7:0], 8'b0};
                        o_ld_data = {{24{byte_sign[1]}},i_ld_data[15:8]};
                    end
                    2'b10: begin
                        o_st_strb = 4'b0100;
                        o_st_data = {8'b0, i_st_data[7:0], 16'b0};
                        o_ld_data = {{24{byte_sign[2]}},i_ld_data[23:16]};
                    end
                    2'b11: begin
                        o_st_strb = 4'b1000;
                        o_st_data = {i_st_data[7:0], 24'b0};
                        o_ld_data = {{24{byte_sign[3]}},i_ld_data[31:24]};
                    end
                    default: begin 
                        o_st_strb = '0;
                        o_st_data = '0;
                        o_ld_data = '0;
                    end
                endcase
            end
            default: begin
                o_st_strb = '0;
                o_st_data = '0;
                o_ld_data = '0;
            end
        endcase
    end
    
endmodule
