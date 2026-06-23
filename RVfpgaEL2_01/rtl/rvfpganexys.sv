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
// Function: SweRVolf toplevel for Nexys A7 board
// Comments:
//
//********************************************************************************
`include "common_defines.vh" //Alex Grinshpun
`default_nettype wire // Alex Grinshpun
module rvfpganexys
`ifndef XSIM //Alex Grinshpun
  #(parameter bootrom_file = "boot_main.mem")
 `else
  #(parameter bootrom_file = "")
 `endif
 (
    input wire         clk,
    input  wire        rstn,

    input wire         i_uart_rx,
    output wire        o_uart_tx,
    //inout  wire [15:0]  i_sw,
    
    `ifdef XSIM //Alex Grinshpun
        input  wire [15:0]  i_sw,
    `else
        inout  wire [15:0]  i_sw,
    `endif
    
    output reg  [15:0]  o_led,
    inout wire [4:0]   i_pb,    
    // ports added by the soc team
   `ifdef JTAG_EXTERNAL
    input wire                             j_tck,    // JTAG clk
    input wire                             j_tms,    // JTAG TMS
    input wire                             j_tdi,    // JTAG tdi
    input wire                             j_trst_n, // JTAG Reset
    output wire                            j_tdo,    // JTAG TDO
   `endif
    output reg [7:0]   AN,
    output reg         CA, CB, CC, CD, CE, CF, CG
    );


   wire [63:0]         gpio_out;

   wire          pwm_pad_o_ptc2;
   wire          pwm_pad_o_ptc3;
   wire          pwm_pad_o_ptc4;
   wire          i_rst;

   localparam RAM_SIZE     = 32'h1F000;

   wire    clk_core;
   wire    rst_core;
   assign i_rst = ~rstn;
   clk_gen_nexys
   clk_gen
     (.i_clk (clk),
      //Alex Grinshpun .i_rst (1'b0),
      .i_rst (i_rst),
      .o_clk_core (clk_core),
      .o_rst_core (rst_core));


   wire [5:0]  ram_awid;
   wire [31:0] ram_awaddr;
   wire [7:0]  ram_awlen;
   wire [2:0]  ram_awsize;
   wire [1:0]  ram_awburst;
   wire        ram_awlock;
   wire [3:0]  ram_awcache;
   wire [2:0]  ram_awprot;
   wire [3:0]  ram_awregion;
   wire [3:0]  ram_awqos;
   wire        ram_awvalid;
   wire        ram_awready;
   wire [5:0]  ram_arid;
   wire [31:0] ram_araddr;
   wire [7:0]  ram_arlen;
   wire [2:0]  ram_arsize;
   wire [1:0]  ram_arburst;
   wire        ram_arlock;
   wire [3:0]  ram_arcache;
   wire [2:0]  ram_arprot;
   wire [3:0]  ram_arregion;
   wire [3:0]  ram_arqos;
   wire        ram_arvalid;
   wire        ram_arready;
   wire [63:0] ram_wdata;
   wire [7:0]  ram_wstrb;
   wire        ram_wlast;
   wire        ram_wvalid;
   wire        ram_wready;
   wire [5:0]  ram_bid;
   wire [1:0]  ram_bresp;
   wire        ram_bvalid;
   wire        ram_bready;
   wire [5:0]  ram_rid;
   wire [63:0] ram_rdata;
   wire [1:0]  ram_rresp;
   wire        ram_rlast;
   wire        ram_rvalid;
   wire        ram_rready;

   wire [5:0]     vga_awid;	
   wire [31:0]    vga_awaddr;
   wire [7:0]     vga_awlen;
   wire [2:0]     vga_awsize;
   wire [1:0]     vga_awburst;
   wire           vga_awlock;
   wire [3:0]     vga_awcache;
   wire [2:0]     vga_awprot;
   wire [3:0]     vga_awregion;
   wire [3:0]     vga_awqos;
   wire           vga_awvalid;
   wire           vga_awready;
   wire [5:0]     vga_arid	;
   wire [31:0]    vga_araddr;
   wire [7:0]     vga_arlen;
   wire [2:0]     vga_arsize;
   wire [1:0]     vga_arburst;
   wire           vga_arlock;
   wire [3:0]     vga_arcache;
   wire [2:0]     vga_arprot;
   wire [3:0]     vga_arregion;
   wire [3:0]     vga_arqos;
   wire           vga_arvalid;
   wire           vga_arread;
   wire [63:0]    vga_wdata;
   wire [7:0]     vga_wstrb;
   wire           vga_wlast;
   wire           vga_wvalid;
   wire           vga_wready;
   wire [5:0]     vga_bid	;
   wire [1:0]     vga_bresp;
   wire           vga_bvalid;
   wire           vga_bready;
   wire [5:0]     vga_rid	;
   wire [63:0]    vga_rdata;
   wire [1:0]     vga_rresp;
   wire           vga_rlast;
   wire           vga_rvalid;
   wire           vga_rready;
   

 
   axi_ram
     #(.DATA_WIDTH (64),
       .ADDR_WIDTH ($clog2(RAM_SIZE)),
       .ID_WIDTH  (`RV_LSU_BUS_TAG+3))
   ram
     (.clk       (clk_core),
      .rst       (rst_core),
      .s_axi_awid    (ram_awid),
      .s_axi_awaddr  (ram_awaddr[$clog2(RAM_SIZE)-1:0]),
      .s_axi_awlen   (ram_awlen),
      .s_axi_awsize  (ram_awsize),
      .s_axi_awburst (ram_awburst),
      .s_axi_awlock  (1'd0),
      .s_axi_awcache (4'd0),
      .s_axi_awprot  (3'd0),
      .s_axi_awvalid (ram_awvalid),
      .s_axi_awready (ram_awready),

      .s_axi_arid    (ram_arid),
      .s_axi_araddr  (ram_araddr[$clog2(RAM_SIZE)-1:0]),
      .s_axi_arlen   (ram_arlen),
      .s_axi_arsize  (ram_arsize),
      .s_axi_arburst (ram_arburst),
      .s_axi_arlock  (1'd0),
      .s_axi_arcache (4'd0),
      .s_axi_arprot  (3'd0),
      .s_axi_arvalid (ram_arvalid),
      .s_axi_arready (ram_arready),

      .s_axi_wdata  (ram_wdata),
      .s_axi_wstrb  (ram_wstrb),
      .s_axi_wlast  (ram_wlast),
      .s_axi_wvalid (ram_wvalid),
      .s_axi_wready (ram_wready),

      .s_axi_bid    (ram_bid),
      .s_axi_bresp  (ram_bresp),
      .s_axi_bvalid (ram_bvalid),
      .s_axi_bready (ram_bready),

      .s_axi_rid    (ram_rid),
      .s_axi_rdata  (ram_rdata),
      .s_axi_rresp  (ram_rresp),
      .s_axi_rlast  (ram_rlast),
      .s_axi_rvalid (ram_rvalid),
      .s_axi_rready (ram_rready));


   wire        dmi_reg_en;
   wire [6:0]  dmi_reg_addr;
   wire        dmi_reg_wr_en;
   wire [31:0] dmi_reg_wdata;
   wire [31:0] dmi_reg_rdata;
   wire        dmi_hard_reset;
   wire        flash_sclk;

   STARTUPE2 STARTUPE2
     (
      .CFGCLK    (),
      .CFGMCLK   (),
      .EOS       (),
      .PREQ      (),
      .CLK       (1'b0),
      .GSR       (1'b0),
      .GTS       (1'b0),
      .KEYCLEARB (1'b1),
      .PACK      (1'b0),
      .USRCCLKO  (flash_sclk),
      .USRCCLKTS (1'b0),
      .USRDONEO  (1'b1),
      .USRDONETS (1'b0));




//Alex Grinshpun
axi_mem 
  #(
	.ID_WIDTH(`RV_LSU_BUS_TAG+3),
    .MEM_SIZE(32'h1000),  //Alex Grinshpun
    .mem_clear(0)
    )
vga_mem
  (
		.clk			(clk_core),
		.rst_n			(~rst_core),
		                  
		.i_awid			(vga_awid),
		.i_awaddr		(vga_awaddr-32'h4000),
		.i_awlen		(vga_awlen),
		.i_awsize		(vga_awsize),
		.i_awburst		(vga_awburst),
		.i_awvalid		(vga_awvalid),
		.o_awready		(vga_awready),
		                 
		.i_arid			(vga_arid),
		.i_araddr		(vga_araddr-32'h4000),
		.i_arlen		(vga_arlen),
		.i_arsize		(vga_arsize),
		.i_arburst		(vga_arburst),
		.i_arvalid		(vga_arvalid),
		.o_arready		(vga_arready),

		.i_wdata		(vga_wdata),
		.i_wstrb		(vga_wstrb),
		.i_wlast		(vga_wlast),
		.i_wvalid		(vga_wvalid),
		.o_wready		(vga_wready),
				              
		.o_bid			(vga_bid), 
		.o_bresp		(vga_bresp),
		.o_bvalid		(vga_bvalid),
		.i_bready		(vga_bready),
		                                  
		.o_rid			(vga_rid),
		.o_rdata		(vga_rdata),
		.o_rresp		(vga_rresp),
		.o_rlast		(vga_rlast),
		.o_rvalid		(vga_rvalid),
		.i_rready       (vga_rready)       
		);                     

`ifdef JTAG_EXTERNAL
`ifndef XSIM
/*
ila_jtag ila_jtag (
	.clk(clk), // input wire clk


	.probe0(j_trst_n), // input wire [0:0]  probe0  
	.probe1(j_tck), // input wire [0:0]  probe1 
	.probe2(j_tms), // input wire [0:0]  probe2 
	.probe3(j_tdi), // input wire [0:0]  probe3 
	.probe4(j_tdo) // input wire [0:0]  probe4
);
*/
`endif
// Alex Grinshpun
// https://github.com/chipsalliance/Cores-VeeR-EH1/blob/main/design/dmi/dmi_wrapper.v
   dmi_wrapper  dmi_wrapper (
    // JTAG signals
    .trst_n      (j_trst_n),     // JTAG reset
    .tck         (j_tck),        // JTAG clock
    .tms         (j_tms),        // Test mode select
    .tdi         (j_tdi),        // Test Data Input
    .tdo         (j_tdo),        // Test Data Output
    .tdoEnable   (),
    // Processor Signals
    .core_rst_n  (~rst_core),       // Debug reset, active low
    .core_clk    (clk_core),             // Core clock
    .jtag_id     (31'd0),         // JTAG ID
    .rd_data     (dmi_reg_rdata),   // Read data from  Processor
    .reg_wr_data (dmi_reg_wdata),   // Write data to Processor
    .reg_wr_addr (dmi_reg_addr),    // Write address to Processor
    .reg_en      (dmi_reg_en),      // Write interface bit to Processor
    .reg_wr_en   (dmi_reg_wr_en),   // Write enable to Processor
    .dmi_hard_reset   (dmi_hard_reset)
   );
`else
   bscan_tap tap
     (.clk            (clk_core),
      .rst            (rst_core),
      .jtag_id        (31'd0),
      .dmi_reg_wdata  (dmi_reg_wdata),
      .dmi_reg_addr   (dmi_reg_addr),
      .dmi_reg_wr_en  (dmi_reg_wr_en),
      .dmi_reg_en     (dmi_reg_en),
      .dmi_reg_rdata  (dmi_reg_rdata),
      .dmi_hard_reset (dmi_hard_reset),
      .rd_status      (2'd0),
      .idle           (3'd0),
      .dmi_stat       (2'd0),
      .version        (4'd1));
`endif
   veerwolf_core
     #(.bootrom_file (bootrom_file),
       .clk_freq_hz  (32'd12_500_000))
   swervolf
     (.clk  (clk_core),
      .rstn (~rst_core),
      .dmi_reg_rdata       (dmi_reg_rdata),
      .dmi_reg_wdata       (dmi_reg_wdata),
      .dmi_reg_addr        (dmi_reg_addr),
      .dmi_reg_en          (dmi_reg_en),
      .dmi_reg_wr_en       (dmi_reg_wr_en),
      .dmi_hard_reset      (dmi_hard_reset),
      .i_uart_rx           (i_uart_rx),
      .o_uart_tx           (o_uart_tx),
      .o_ram_awid          (ram_awid),
      .o_ram_awaddr        (ram_awaddr),
      .o_ram_awlen         (ram_awlen),
      .o_ram_awsize        (ram_awsize),
      .o_ram_awburst       (ram_awburst),
      .o_ram_awlock        (ram_awlock),
      .o_ram_awcache       (ram_awcache),
      .o_ram_awprot        (ram_awprot),
      .o_ram_awregion      (ram_awregion),
      .o_ram_awqos         (ram_awqos),
      .o_ram_awvalid       (ram_awvalid),
      .i_ram_awready       (ram_awready),
      .o_ram_arid          (ram_arid),
      .o_ram_araddr        (ram_araddr),
      .o_ram_arlen         (ram_arlen),
      .o_ram_arsize        (ram_arsize),
      .o_ram_arburst       (ram_arburst),
      .o_ram_arlock        (ram_arlock),
      .o_ram_arcache       (ram_arcache),
      .o_ram_arprot        (ram_arprot),
      .o_ram_arregion      (ram_arregion),
      .o_ram_arqos         (ram_arqos),
      .o_ram_arvalid       (ram_arvalid),
      .i_ram_arready       (ram_arready),
      .o_ram_wdata         (ram_wdata),
      .o_ram_wstrb         (ram_wstrb),
      .o_ram_wlast         (ram_wlast),
      .o_ram_wvalid        (ram_wvalid),
      .i_ram_wready        (ram_wready),
      .i_ram_bid           (ram_bid),
      .i_ram_bresp         (ram_bresp),
      .i_ram_bvalid        (ram_bvalid),
      .o_ram_bready        (ram_bready),
      .i_ram_rid           (ram_rid),
      .i_ram_rdata         (ram_rdata),
      .i_ram_rresp         (ram_rresp),
      .i_ram_rlast         (ram_rlast),
      .i_ram_rvalid        (ram_rvalid),
      .o_ram_rready        (ram_rready),
      .i_ram_init_done     (1'b1),
      .i_ram_init_error    (1'b0),
    //Alex Grinshpun
	.o_vga_awid			(vga_awid	),
	.o_vga_awaddr		(vga_awaddr),
	.o_vga_awlen		(vga_awlen),
	.o_vga_awsize		(vga_awsize),
	.o_vga_awburst		(vga_awburst),
	.o_vga_awlock		(vga_awlock),
	.o_vga_awcache		(vga_awcache),
	.o_vga_awprot		(vga_awprot),
	.o_vga_awregion		(vga_awregion),
	.o_vga_awqos		(vga_awqos),
	.o_vga_awvalid		(vga_awvalid),
	.i_vga_awready		(vga_awready),
	.o_vga_arid			(vga_arid	),
	.o_vga_araddr		(vga_araddr),
	.o_vga_arlen		(vga_arlen),
	.o_vga_arsize		(vga_arsize),
	.o_vga_arburst		(vga_arburst),
	.o_vga_arlock		(vga_arlock),
	.o_vga_arcache		(vga_arcache),
	.o_vga_arprot		(vga_arprot),
	.o_vga_arregion		(vga_arregion),
	.o_vga_arqos		(vga_arqos),
	.o_vga_arvalid		(vga_arvalid),
	.i_vga_arready		(vga_arready),
	.o_vga_wdata		(vga_wdata),
	.o_vga_wstrb		(vga_wstrb),
	.o_vga_wlast		(vga_wlast),
	.o_vga_wvalid		(vga_wvalid),
	.i_vga_wready		(vga_wready),
	.i_vga_bid			(vga_bid	),
	.i_vga_bresp		(vga_bresp),
	.i_vga_bvalid		(vga_bvalid),
	.o_vga_bready		(vga_bready),
	.i_vga_rid			(vga_rid	),
	.i_vga_rdata		(vga_rdata),
	.i_vga_rresp		(vga_rresp),
	.i_vga_rlast		(vga_rlast),
	.i_vga_rvalid		(vga_rvalid),
	.o_vga_rready		(vga_rready),
      //Alex Grinshpun .io_data        ({i_sw[15:0],gpio_out[15:0]}),
      .io_data2       (i_pb[4:0]),

      `ifdef XSIM  //Alex Grinshpun
        .i_sw           (i_sw),
        .io_data        (gpio_out[15:0]),
      `else
         .io_data        ({i_sw[15:0],gpio_out[15:0]}),
      `endif

      .AN (AN),
      .Digits_Bits ({CA,CB,CC,CD,CE,CF,CG}),
      .pwm_pad_o_ptc2 (),
      .pwm_pad_o_ptc3 (),
      .pwm_pad_o_ptc4 ()
      );

   always @(posedge clk_core) begin
      o_led[15:0] <= gpio_out[15:0];
   end



endmodule
