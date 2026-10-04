module lcd_ctrl 
#(
      parameter T_PERIOD_NS = 20 // clock period   

    , parameter T_AS_NS   = 80    // 40  <= T_AS
    , parameter T_PW_NS   = 460   // 230 <= T_PW
    , parameter T_CYCE_NS = 1000  // 500 <= T_CYCE
    // , parameter T_AH_NS  = 20    // 10  <= T_AH
    // , parameter T_DSW_NS = 160   // 80  <= T_DSW
    // , parameter T_H_NS   = 20    // 10  <= T_H
)
(
      input  logic        i_clk
    , input  logic        i_rst_n

    , input  logic        i_vld
    , output logic        o_rdy

    , input  logic [7:0]  i_LCD_DATA
    , input  logic        i_LCD_RW
    , input  logic        i_LCD_RS
    , input  logic        i_LCD_ON

    , output logic [7:0]  o_LCD_DATA
    , output logic        o_LCD_RW  
    , output logic        o_LCD_EN   
    , output logic        o_LCD_RS   
    , output logic        o_LCD_ON   
);

    localparam C_AS_NS   = T_AS_NS   / T_PERIOD_NS;
    localparam C_PW_NS   = T_PW_NS   / T_PERIOD_NS;
    localparam C_CYCE_NS = T_CYCE_NS / T_PERIOD_NS;
    localparam CNT_W = $clog2(C_AS_NS+C_CYCE_NS+1)+1;

    logic [CNT_W-1:0] cnt;

    always_ff @( posedge i_clk ) begin
        if (~i_rst_n) begin
            o_LCD_DATA <= '0; 
            o_LCD_RW   <= '0;  
            o_LCD_EN   <= '0;  
            o_LCD_RS   <= '0;  
            o_LCD_ON   <= '0;   
            o_rdy      <= 1'b1;
            cnt        <= '0;  
        end   
        else begin
            o_LCD_DATA <= i_LCD_DATA; 
            o_LCD_RW   <= i_LCD_RW;  
            o_LCD_EN   <= (~o_LCD_EN && (cnt == CNT_W'(C_AS_NS)))? 1'b1 : (o_LCD_EN && (cnt == CNT_W'(C_AS_NS+C_PW_NS)))? 1'b0 : o_LCD_EN;  
            o_LCD_RS   <= i_LCD_RS;  
            o_LCD_ON   <= i_LCD_ON;   
            o_rdy      <= (i_vld & o_rdy)? 1'b0 : (cnt == CNT_W'(C_AS_NS+C_CYCE_NS))? 1'b1 : o_rdy;
            cnt        <= (~o_rdy)? cnt+1 : '0;  
        end
    end

endmodule
