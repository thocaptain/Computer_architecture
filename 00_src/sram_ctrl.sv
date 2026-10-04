/**************************************************************************
 * Copyright 2024 Hai Cao
 * All Rights Reserved.
 *
 * Licensed under the MIT License.
 * See LICENSE file for license details.
 **************************************************************************/
/*
 * Module: sram_IS61WV25616_controller_32b_3lr
 *
 * This module implements a simple controller for IS61WV25616 SRAM. It is
 * designed to accommodate 32-bit data operations.
 * The write operation always has a latency of 2 cycles.
 * The read operation has a latency of 3 cycles
 *
 * Author: Hai Cao - cxhai.sdh221@hcmut.edu.vn
 */

module sram_ctrl (
  input  logic [17:0]   i_ADDR   ,
  input  logic [31:0]   i_WDATA  ,
  input  logic [ 3:0]   i_BMASK  ,
  input  logic          i_WREN   ,
  input  logic          i_RDEN   ,
  output logic [31:0]   o_RDATA  ,
  output logic          o_ACK    ,

  output logic [17:0]   SRAM_ADDR,
  inout  wire  [15:0]   SRAM_DQ  ,
  output logic          SRAM_CE_N,
  output logic          SRAM_WE_N,
  output logic          SRAM_OE_N,
  output logic          SRAM_LB_N,
  output logic          SRAM_UB_N,

  input logic i_clk,
  input logic i_reset
);

  typedef enum logic [2:0] {
      StIdle
    , StWrite
    , StWriteAck
    , StRead0
    , StRead1
    , StReadAck
  } sram_state_e;

  sram_state_e sram_state_d;
  sram_state_e sram_state_q;

  logic [17:0] addr_d;
  logic [17:0] addr_q;
  logic [31:0] wdata_d;
  logic [31:0] wdata_q;
  logic [31:0] rdata_d;
  logic [31:0] rdata_q;
  logic [ 3:0] bmask_d;
  logic [ 3:0] bmask_q;

  logic [15:0] DIN;
  logic [15:0] DOUT;

  always_comb begin : proc_detect_state
    case (sram_state_q)
      StIdle, StWriteAck, StReadAck: begin
        if (i_WREN ~^ i_RDEN) begin
          sram_state_d = StIdle;
          addr_d       = addr_q;
          wdata_d      = wdata_q;
          rdata_d      = rdata_q;
          bmask_d      = bmask_q;
        end
        else begin
          sram_state_d = i_WREN ? StWrite : StRead0;
          addr_d       = i_ADDR & 18'h3FFFE;
          wdata_d      = i_WREN ? i_WDATA : wdata_q;
          rdata_d      = rdata_q;
          bmask_d      = i_BMASK;
        end
      end
      StWrite: begin
        sram_state_d = StWriteAck;
        addr_d       = addr_q | 18'h1;
        wdata_d      = wdata_q >> 16;
        rdata_d      = rdata_q;
        bmask_d      = bmask_q;
      end
      StRead0: begin
        sram_state_d = StRead1;
        addr_d       = addr_q | 18'h1;
        wdata_d      = wdata_q;
        rdata_d      = {rdata_q[31:16], DIN};
        bmask_d      = bmask_q;
      end
      StRead1: begin
        sram_state_d = StReadAck;
        addr_d       = addr_q;
        wdata_d      = wdata_q;
        rdata_d      = {DIN, rdata_q[15:0]};
        bmask_d      = bmask_q;
      end
      default: begin
        sram_state_d = StIdle;
        addr_d       = '0;
        wdata_d      = '0;
        rdata_d      = '0;
        bmask_d      = '0;
      end
    endcase
  end

  always_ff @(posedge i_clk) begin
    if (!i_reset) begin
      sram_state_q <= StIdle;
    end
    else begin
      sram_state_q <= sram_state_d;
    end
  end

  always_ff @(posedge i_clk) begin
    if (!i_reset) begin
      addr_q  <= '0;
      wdata_q <= '0;
      rdata_q <= '0;
      bmask_q <= 4'b0000;
    end
    else begin
      addr_q  <= addr_d;
      wdata_q <= wdata_d;
      rdata_q <= rdata_d;
      bmask_q <= bmask_d;
    end
  end

  always_comb begin : proc_output_to_sram
    SRAM_ADDR = addr_q;
    case (sram_state_q)
      StWrite: begin
        DOUT      = wdata_q[15:0];
        SRAM_WE_N = 1'b0;
        SRAM_OE_N = 1'b1;
        SRAM_CE_N = 1'b0;
        {SRAM_UB_N, SRAM_LB_N} = ~bmask_q[1:0];
      end
      StWriteAck: begin
        DOUT      = wdata_q[15:0];
        SRAM_WE_N = 1'b0;
        SRAM_OE_N = 1'b1;
        SRAM_CE_N = 1'b0;
        {SRAM_UB_N, SRAM_LB_N} = ~bmask_q[3:2];
      end
      StRead0: begin
        DOUT      = 'z;
        SRAM_WE_N = 1'b1;
        SRAM_OE_N = 1'b0;
        SRAM_CE_N = 1'b0;
        {SRAM_UB_N, SRAM_LB_N} = ~bmask_q[1:0];
      end
      StRead1: begin
        DOUT      = 'z;
        SRAM_WE_N = 1'b1;
        SRAM_OE_N = 1'b0;
        SRAM_CE_N = 1'b0;
        {SRAM_UB_N, SRAM_LB_N} = ~bmask_q[3:2];
      end
      StReadAck: begin
        DOUT      = 'z;
        SRAM_WE_N = 1'b1;
        SRAM_OE_N = 1'b1;
        SRAM_CE_N = 1'b1;
        {SRAM_UB_N, SRAM_LB_N} = 2'b11;
      end
      default: begin
        DOUT      = 'z;
        SRAM_WE_N = 1'b1;
        SRAM_OE_N = 1'b1;
        SRAM_CE_N = 1'b1;
        {SRAM_UB_N, SRAM_LB_N} = 2'b11;
      end
    endcase
  end

  assign  SRAM_DQ = DOUT;
  assign  DIN = SRAM_DQ;

  always_comb begin : proc_output_to_lsu
    o_RDATA = rdata_q;
    o_ACK  = (sram_state_q == StWriteAck) || (sram_state_q == StReadAck);
  end

endmodule
