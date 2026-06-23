// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//********************************************************************************
// $Id$
//
// Function: Verilog testbench for SweRVolf
// Comments:
// Alex Grinshpun.
// Test instantiates full RVPGANEXYS FPGA
// Provided AS IS without WARRANTIES of any kind nor explicit neither implied
//********************************************************************************
`include "common_defines.vh" //Alex Grinshpun
`default_nettype none
module rvfpgasim_fpga
  #(parameter bootrom_file  = "")
`ifdef VERILATOR
  (

`ifdef ViDBo
   input wire [15:0] i_sw,
   output reg [15:0] o_led,
   input wire [4:0]  i_pb,
   output reg [7:0]   AN,
   output reg         CA, CB, CC, CD, CE, CF, CG,
   output wire [7:0]  Enables_Reg,
   output wire [31:0] Digits_Reg,
   output wire        tf_push,
   output wire [7:0]  wb_m2s_uart_dat_output,
   output wire        LED_B,
   output wire        LED_G,
   output wire        LED_R,
`endif

`ifdef Pipeline
   output logic [31:0]        ifu_fetch_data_f,
   output logic [31:0]        q2,q1,q0,
   output logic [31:0]        i0_inst_d,
   output logic [31:0]        i0_inst_x,
   output logic [31:0]        i0_inst_r,
   output logic [31:0]        i0_inst_wb_in,
   output logic [31:0]        i0_inst_wb,

   output logic [4:0]  dec_i0_rs1_d,
   output logic [4:0]  dec_i0_rs2_d,
   output logic  [31:0] gpr_i0_rs1_d,
   output logic  [31:0] gpr_i0_rs2_d,

   output logic [31:0]                i0_rs1_d,  i0_rs2_d,
   output logic [31:0]                muldiv_rs1_d,

   output logic [31:0] exu_i0_result_x,
   output logic               [31:0]    result,
   output logic                       mul_valid_x,

   output logic [4:0]  dec_i0_waddr_r,
   output logic        dec_i0_wen_r,
   output logic [31:0] dec_i0_wdata_r,

   output logic [31:0]        rs1_d,
   output logic [11:0]        offset_d,
   output logic [31:0]        full_addr_d,

   output logic [31:0]                i0_rs1_bypass_data_d,
   output logic [31:0]                i0_rs2_bypass_data_d,
   output logic [31:0]               lsu_result_m,
   output logic [4:0]                dec_nonblock_load_waddr,
   output logic                      dec_nonblock_load_wen,
   output logic [31:0]               lsu_nonblock_load_data,
   output logic [31:0] exu_div_result,
   output logic        exu_div_wren,
   output logic [4:0]  div_waddr_wb,
   output logic                       i0_rs1_bypass_en_d,
   output logic                       i0_rs2_bypass_en_d,
   output logic                       dec_i0_rs1_en_d,
   output logic                       dec_i0_rs2_en_d,
   output logic alu_instd,
   output logic lsu_instd,
   output logic mul_instd,
   output logic i0_x_data_en,
   output logic alu_instx,
   output logic mul_instx,
   output logic Bypass0_exu_i0_result_x,
   output logic Bypass0_lsu_nonblock_load_data,
   output logic Bypass1_exu_i0_result_x,
   output logic Bypass1_lsu_nonblock_load_data,
   output logic                         actual_taken,
   output logic                         any_branch,
`endif

`ifdef Pipeline
   output logic [2:0] instr_control,
`endif

   input wire clk,
   input wire 	      rstn,
   input wire  i_j_tck,
   input wire  i_j_tms,
   input wire  i_j_tdi,
   input reg  i_j_trst_n,
   output wire o_j_tdo,
   output wire o_uart_tx,
   output wire o_gpio
   )
`endif
  ;

   localparam RAM_SIZE     = 32'h10000;

`ifndef VERILATOR
	reg		[15:0]	i_sw; //Alex Grinshpun
	wire	[15:0]	o_led;
	wire	[7:0]	AN;
	wire			CA;
	wire			CB;
	wire			CC;
	wire			CD;
	wire			CE;
	wire			CF;
	wire			CG;
	wire			i_uart_rx;
	wire			o_uart_tx;
	wire			o_flash_cs_n;
	wire			o_flash_mosi;
	wire			i_flash_miso;

	wire	[4:0]   i_pb;
	wire			LED16_B;
	wire			LED16_G;
	wire			LED16_R;
	wire			o_accel_cs_n;
	wire			o_accel_mosi;
	wire			i_accel_miso;
	wire			accel_sclk;
	

    
	reg		clk = 1'b0;
	reg		rstn;
	wire	o_gpio;
	wire	i_j_tck ;//= 1'b0; //Alex Grinshpun
	wire	i_j_tms ;//= 1'b0; //Alex Grinshpun
	wire	i_j_tdi = 1'b0; //Alex Grinshpun
	reg		i_j_trst_n = 1'b1; //Alex Grinshpun
	
	always #10 clk <= !clk;
	initial begin 
		rstn 		<= 1'b0;
		#100 rstn	<= 1'b1;
	end

	initial #1000 i_j_trst_n <= 1'b0; //Alex Grinshpun
	wire o_j_tdo;


//   uart_decoder #(115200) uart_decoder (o_uart_tx);
`endif

  `ifdef ViDBo
     wire [15:0]  gpio_in; //? Alex Grinshpun
     wire [15:0]  gpio_out; //? Alex Grinshpun
     assign gpio_in = i_sw; //?Alex Grinshpun
     always @(posedge clk) begin
        o_led[15:0] <= gpio_out[15:0];
     end
  `endif
integer file;
   reg [1023:0] ram_init_file;
   initial begin
      if (|$test$plusargs("jtag_vpi_enable"))
	       $display("JTAG VPI enabled. Not loading RAM");
      else if ($value$plusargs("ram_init_file=%s", ram_init_file)) begin
	       $display("Loading RAM contents from %0s", ram_init_file);
		   $readmemh(ram_init_file, rvfpganexys.ram.mem);
      end
   end

   reg [1023:0] rom_init_file;
   initial begin
      if ($value$plusargs("rom_init_file=%s", rom_init_file)) begin
	   $display("Loading ROM contents from %0s", rom_init_file);
	   $readmemh(rom_init_file, rvfpganexys.swervolf.bootrom.ram.mem);
      end else if (!(|bootrom_file)) begin
	/*
	 Set mrac to 0xAAAA0000 and jump to address 0
	 if no bootloader is selected
	 0:   aaaa02b7                lui     t0,0xaaaa0
	 4:   7c029073                csrw    0x7c0,t0
	 8:   00000067                jr      zero
	 */
	//Jump to address 0 if no bootloader is selected
		  $display("Loading ROM contents from %0s", rom_init_file); 
		  rvfpganexys.swervolf.bootrom.ram.mem[0] = 64'h7c029073aaaa02b7;;
		  rvfpganexys.swervolf.bootrom.ram.mem[1] = 64'h0000000000000067;
      end
    end




`ifdef ViDBo
`elsif Pipeline
`else

     initial begin
       i_sw = 16'hFE34;

       #45000; 

        i_sw = 16'h5555;
        #10000;   
        i_sw = 16'h6666;
        #10000;   
        i_sw = 16'h7777;        
     end
`endif

rvfpganexys rvfpganexys
   (
    .clk			(clk),
	.rstn			(rstn),
	/*
	.o_flash_cs_n	(o_flash_cs_n),
	.o_flash_mosi	(o_flash_mosi),
	.i_flash_miso	(i_flash_miso),
	*/
    .i_uart_rx		(i_uart_rx),
    .o_uart_tx		(o_uart_tx),
    .i_sw			(i_sw),
	.o_led			(o_led),
	.i_pb			(i_pb),

    //.he soc team
`ifdef JTAG_EXTERNAL
	.j_tck			(i_j_tck),    // JTAG clk
	.j_tms			(i_j_tms),    // JTAG TMS
	.j_tdi			(i_j_tdi),    // JTAG tdi
	.j_trst_n(i_j_trst_n), // JTAG Reset
	.j_tdo(o_j_tdo),    // JTAG TDO
`endif
    .AN				(AN),
    .CA				(CA), 
	.CB				(CB), 
	.CC				(CC), 
	.CD				(CD), 
	.CE				(CE), 
	.CF				(CF), 
	.CG				(CG)/*,
	.o_accel_cs_n	(o_accel_cs_n),
	.o_accel_mosi	(o_accel_mosi),
	.i_accel_miso	(i_accel_miso),
	.accel_sclk		(accel_sclk)
	*/
    );

endmodule
