module btn_debounce 
#(
      parameter STABLE_TIME_MS = 5 // unit: milisecond
    , parameter CLK_PERIOD_NS = 20 // unit: nanosecond
)
(
      input  logic i_clk
    , input  logic i_rst_n

    , input  logic i_btn
    , output logic o_btn
);
    localparam STABLE_CYCLE = (10**6 * STABLE_TIME_MS) / CLK_PERIOD_NS;
    // localparam STABLE_CYCLE = 5; // ACTIVATE this for SIM
    localparam CNT_WIDTH    = $clog2(STABLE_CYCLE+1); // plus one to be able to count to STABLE_CYCLE

    typedef enum logic { 
        STABLE_0 = 1'b0, // must be equal to physical state
        STABLE_1 = 1'b1
    } BtnState_e;

    BtnState_e            btn_state;
    BtnState_e            btn_state_next;
    logic                 btn_state_vld;
    logic                 cnt_rst;
    logic [CNT_WIDTH-1:0] cnt_val;

    assign cnt_rst    = btn_state != btn_state_next;
    assign btn_state_vld = cnt_val == CNT_WIDTH'(STABLE_CYCLE);

    always_ff @( posedge i_clk ) begin: btn_state_ff
        if(~i_rst_n) begin  
            btn_state <= BtnState_e'(i_btn);
        end
        else begin 
            btn_state <= btn_state_next;
        end
    end

    always_comb begin
        case (btn_state)
            STABLE_0: begin
               if(i_btn) begin
                btn_state_next = STABLE_1;
               end 
               else begin
                btn_state_next = btn_state;
               end
            end 
            STABLE_1: begin
               if(~i_btn) begin
                btn_state_next = STABLE_0;
               end 
               else begin
                btn_state_next = btn_state;
               end
            end 
            default: begin
                btn_state_next = STABLE_0;
            end 
        endcase 
    end

    always_ff @( posedge i_clk ) begin: cnt_ff
        if(~i_rst_n | cnt_rst | btn_state_vld) begin  
            cnt_val <= '0;
        end
        else begin 
            cnt_val <= CNT_WIDTH'(cnt_val + 1);
        end
    end

    always_ff @( posedge i_clk ) begin: o_btn_ff
        if(~i_rst_n) begin  
            o_btn <= i_btn;
        end
        else begin 
            o_btn <= (btn_state_vld)? 1'(btn_state) : o_btn;
        end
    end
endmodule
