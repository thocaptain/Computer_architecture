module scoreboard_br_pred (
      input logic i_clk
    , input logic i_rst_n

    , input logic i_is_br
    , input logic i_is_correct
);
    logic [31:0] br_cnt, correct_cnt;

    always_ff @( posedge i_clk ) begin
        if(~i_rst_n) begin
            br_cnt      <= '0;
            correct_cnt <= '0;
        end
        else begin
            br_cnt      <= (i_is_br) ?                br_cnt + 1     : br_cnt;
            correct_cnt <= (i_is_correct & i_is_br) ? correct_cnt + 1: correct_cnt;
        end
        if(br_cnt%50 == '0)
            $display("Branch Prediction Scoreboard: @%05d n_br_inst=%10d, n_correct=%10d", $time, br_cnt, correct_cnt);
    end

endmodule
