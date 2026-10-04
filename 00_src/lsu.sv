module lsu 
   import rv32i_pkg::*;
#(
   parameter MEM_TYPE = MEM_FLOP, // 0: flop-based, 1: sram-based
   parameter CACHE    = 1 
)
(
   // System
     input  logic        i_clk
   , input  logic        i_rst_n
     // CPU side
/*   verilator lint_off UNUSEDSIGNAL */
   , input  logic [31:0] i_lsu_addr
   // , output logic        o_data_vld
/*   verilator lint_off UNUSEDSIGNAL */
   , input  logic [31:0] i_st_data
   , input  logic [3:0]  i_st_strb  // Byte strobe (used for byte/halfword/word writes)
   , input  logic        i_lsu_wren // 1 if writing
   , output logic [31:0] o_ld_data
   , output logic        o_lcd_vld
     // AXI handshake
   , input  logic        i_VALID
   , output logic        o_READY
     // Peripherals
   , input  logic [31:0] i_io_sw
   , input  logic [3:0]  i_io_btn
   , output logic [31:0] o_io_ledr
   , output logic [31:0] o_io_ledg
   , output logic [31:0] o_io_lcd
   , output logic [6:0]  o_io_hex0    // 7-bit output for HEX0
   , output logic [6:0]  o_io_hex1    // 7-bit output for HEX1
   , output logic [6:0]  o_io_hex2    // 7-bit output for HEX2
   , output logic [6:0]  o_io_hex3    // 7-bit output for HEX3
   , output logic [6:0]  o_io_hex4    // 7-bit output for HEX4
   , output logic [6:0]  o_io_hex5    // 7-bit output for HEX5
   , output logic [6:0]  o_io_hex6    // 7-bit output for HEX6
   , output logic [6:0]  o_io_hex7     // 7-bit output for HEX7
     // SRAM
   , output logic [17:0] SRAM_ADDR
   , inout  wire  [15:0] SRAM_DQ  
   , output logic        SRAM_CE_N
   , output logic        SRAM_WE_N
   , output logic        SRAM_LB_N
   , output logic        SRAM_UB_N
   , output logic        SRAM_OE_N
   // for evaluation
   , output logic        vld_data_mem
);
   
   // Internal signals
   logic [31:0] byte_mask;
   logic [31:0] ledr_reg;
   logic [31:0] ledg_reg;
   logic [31:0] seg7_0to3_reg;
   logic [31:0] seg7_4to7_reg;
   logic [31:0] lcd_reg;
   logic [31:0] data_mem_val;
   logic        rdy_data_mem;
   logic        vld_ledr;
   logic        vld_ledg;
   logic        vld_seg7;
   logic        vld_lcd ;
   logic        vld_sw  ;
   logic        vld_btn ;
   logic        vld_timer;



   always_comb begin
      // Generate a byte-wise mask for 32-bit data 
      byte_mask = {{8{i_st_strb[3]}}, {8{i_st_strb[2]}}, {8{i_st_strb[1]}}, {8{i_st_strb[0]}}};

      vld_data_mem  = i_VALID && (i_lsu_addr[15:13] == DATA_BASE_ADDR [15:13]) && (~|i_lsu_addr[31:16]);
      vld_ledr      = i_VALID && (i_lsu_addr[15:2]  == LEDR_BASE_ADDR [15:2] ) && (~|i_lsu_addr[31:16]);
      vld_ledg      = i_VALID && (i_lsu_addr[15:2]  == LEDG_BASE_ADDR [15:2] ) && (~|i_lsu_addr[31:16]);
      vld_seg7      = i_VALID && (i_lsu_addr[15:3]  == SEG7_BASE_ADDR [15:3] ) && (~|i_lsu_addr[31:16]);
      vld_lcd       = i_VALID && (i_lsu_addr[15:2]  == LCD_BASE_ADDR  [15:2] ) && (~|i_lsu_addr[31:16]);
      vld_sw        = i_VALID && (i_lsu_addr[15:2]  == SW_BASE_ADDR   [15:2] ) && (~|i_lsu_addr[31:16]);
      vld_btn       = i_VALID && (i_lsu_addr[15:2]  == BTN_BASE_ADDR  [15:2] ) && (~|i_lsu_addr[31:16]);
      vld_timer     = i_VALID && (i_lsu_addr[15:4]  == TIMER_BASE_ADDR[15:4] ) && (~|i_lsu_addr[31:16]);
   end

//////////////////////////////////////////////////////////////////////////
// INPUT LOGIC
//////////////////////////////////////////////////////////////////////////
   localparam TOTAL_BYTES    = DATA_LAST_ADDR - DATA_BASE_ADDR;
   localparam DAT_MEM_ADDR_W = $clog2(TOTAL_BYTES);
   // localparam DAT_MEM_ADDR_W = $clog2(256); // FIXME: for running on FPGA
   //---------------------------
   // Data memory 
   //---------------------------

   logic [17:0]   mem_ADDR ;  
   logic [31:0]   mem_WDATA;   
   logic [ 3:0]   mem_BMASK;   
   logic          mem_WREN ;  
   logic [31:0]   mem_RDATA;  
   logic          mem_VALID;   
   logic          mem_READY;   

   generate
      if(CACHE) begin: g_cache
         cache #(
            .OFFSET_ADDR_W(4),
            .IDX_ADDR_W   (3) 
         ) cache (
            .i_clk      (i_clk       ), 
            .i_rst_n    (i_rst_n     ),   
                         
            .i_ADDR     ({(18-DAT_MEM_ADDR_W)'(0), i_lsu_addr[DAT_MEM_ADDR_W-1:0]}),   
            .i_WDATA    (i_st_data   ),   
            .i_BMASK    (i_st_strb   ),   
            .i_WREN     (i_lsu_wren  ),    
            .o_RDATA    (data_mem_val),   
            .i_VALID    (vld_data_mem),   
            .o_READY    (rdy_data_mem),      
                         
            .o_mem_ADDR (mem_ADDR ),       
            .o_mem_WDATA(mem_WDATA),       
            .o_mem_BMASK(mem_BMASK),       
            .o_mem_WREN (mem_WREN ),        
            .i_mem_RDATA(mem_RDATA),       
            .o_mem_VALID(mem_VALID),       
            .i_mem_READY(mem_READY)          
         );
      end
      else begin: g_no_cache
         always_comb begin
            mem_ADDR  = {(18-DAT_MEM_ADDR_W)'(0), i_lsu_addr[DAT_MEM_ADDR_W-1:0]};           
            mem_WDATA = i_st_data   ;
            mem_BMASK = i_st_strb   ;
            mem_WREN  = i_lsu_wren  ;
            mem_VALID = vld_data_mem;

            rdy_data_mem = mem_READY;
            data_mem_val = mem_RDATA;
         end 
      end
   endgenerate


   data_mem #(
      .MEM_TYPE(MEM_TYPE),
      .ADDR_W(DAT_MEM_ADDR_W)
   ) data_mem (
      .i_clk    (i_clk      ),  
      .i_rst_n  (i_rst_n    ),    
      .i_ADDR   (mem_ADDR ),    
      .i_WDATA  (mem_WDATA),    
      .i_BMASK  (mem_BMASK),    
      .i_WREN   (mem_WREN ),   
      .o_RDATA  (mem_RDATA),    
      .i_VALID  (mem_VALID),    
      .o_READY  (mem_READY),     

      .SRAM_ADDR(SRAM_ADDR),      
      .SRAM_DQ  (SRAM_DQ  ),      
      .SRAM_CE_N(SRAM_CE_N),      
      .SRAM_WE_N(SRAM_WE_N),      
      .SRAM_LB_N(SRAM_LB_N),      
      .SRAM_UB_N(SRAM_UB_N),      
      .SRAM_OE_N(SRAM_OE_N)      
   );

   //---------------------------
   // Timers
   //---------------------------
   logic [31:0] timer [0:3];
   generate
      genvar i;
      for (i = 0; i < 4; i++) begin: g_timer
         always_ff @( posedge i_clk ) begin
            if(~i_rst_n) begin
               timer[i] <= '0;
            end
            else begin 
               if (i_lsu_wren && vld_timer && (i_lsu_addr[3:2]==i)) begin
                  timer[i] <= (timer[i] & ~byte_mask) | (i_st_data & byte_mask);
               end
               else begin
                  timer[i] <= timer[i] + 1;
               end
            end
         end 
      end
   endgenerate

   //---------------------------
   // LEDR 
   //---------------------------
   always_ff @( posedge i_clk ) begin
      if(!i_rst_n) begin
         ledr_reg <= 0;
      end
      else begin
         if (i_lsu_wren && vld_ledr) begin
            ledr_reg <= (ledr_reg & ~byte_mask) | (i_st_data & byte_mask);
         end
      end
   end

   //---------------------------
   // LEDG 
   //---------------------------
   always_ff @( posedge i_clk ) begin
      if(!i_rst_n) begin
         ledg_reg <= 0;
      end
      else begin
         if (i_lsu_wren && vld_ledg) begin
            ledg_reg <= (ledg_reg & ~byte_mask) | (i_st_data & byte_mask);
         end
      end
   end

   //---------------------------
   // 7-SEGMENT LEDs 
   //---------------------------
   always_ff @( posedge i_clk ) begin
      if(!i_rst_n) begin
         seg7_0to3_reg <= 0;
         seg7_4to7_reg <= 0;
      end
      else begin
         if (i_lsu_wren && vld_seg7) begin
            if (i_lsu_addr[2]) begin
               seg7_4to7_reg <= (seg7_4to7_reg & ~byte_mask) | (i_st_data & byte_mask);
            end
            else begin
               seg7_0to3_reg <= (seg7_0to3_reg & ~byte_mask) | (i_st_data & byte_mask);
            end
         end
      end
   end

   //---------------------------
   // LCD 
   //---------------------------
   always_ff @( posedge i_clk ) begin
      if (!i_rst_n) begin
         lcd_reg <= 0;
      end
      else begin
         if (i_lsu_wren && vld_lcd) begin
            lcd_reg <= (lcd_reg & ~byte_mask) | (i_st_data & byte_mask);
         end
      end
   end

//////////////////////////////////////////////////////////////////////////
// OUTPUT LOGIC
//////////////////////////////////////////////////////////////////////////
   always_comb begin: MMIO_rd
      o_ld_data  = '0;
      o_READY    = 1'b0;
      // o_data_vld = 1'b0; // currently, it is not used, remove to have higher performance

      // if-else could be inferred to priority mux -> high latency
      if (vld_ledr) begin
         o_ld_data  = ledr_reg;
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_ledg) begin
         o_ld_data  = ledg_reg;
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_seg7) begin
         if (i_lsu_addr[2]) begin
            o_ld_data = seg7_4to7_reg;
         end
         else begin
            o_ld_data = seg7_0to3_reg;
         end
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_lcd) begin
         o_ld_data  = lcd_reg;
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_sw) begin
         o_ld_data  = i_io_sw;
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_data_mem) begin
         o_ld_data  = data_mem_val;
         o_READY    = rdy_data_mem;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_btn) begin
         o_ld_data  = {28'd0, i_io_btn};
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
      if (vld_timer) begin
         o_ld_data  = timer[i_lsu_addr[3:2]];
         o_READY    = 1'b1;
         // o_data_vld = 1'b1; // currently, it is not used, remove to have higher performance
      end
   end

   assign o_lcd_vld = i_lsu_wren & vld_lcd; // for lcd_ctrl to auto-drive LCD_EN


   always_comb begin : peripherals_output
      // LEDG/LEDR output
      o_io_ledg = ledg_reg;
      o_io_ledr = ledr_reg;

      // 7-segment display
      o_io_hex0 = seg7_0to3_reg[8*0 +: 7];
      o_io_hex1 = seg7_0to3_reg[8*1 +: 7];
      o_io_hex2 = seg7_0to3_reg[8*2 +: 7];
      o_io_hex3 = seg7_0to3_reg[8*3 +: 7];
      o_io_hex4 = seg7_4to7_reg[8*0 +: 7];
      o_io_hex5 = seg7_4to7_reg[8*1 +: 7];
      o_io_hex6 = seg7_4to7_reg[8*2 +: 7];
      o_io_hex7 = seg7_4to7_reg[8*3 +: 7];

      // LCD display
      o_io_lcd = lcd_reg;
   end
endmodule
