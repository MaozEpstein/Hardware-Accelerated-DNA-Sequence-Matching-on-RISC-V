// SPDX-License-Identifier: Apache-2.0
// Copyright 2019-2020 Western Digital Corporation or its affiliates.
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
// Function: VeeRwolf SoC-level controller
// Comments:
//
//********************************************************************************
// Alex Grinshpun 2023 .Pure SystemVerilog version and display Letters + Digits
// Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED

module veerwolf_syscon   #(parameter [31:0] clk_freq_hz = 0)
	(	
		input	logic			i_clk,
		input	logic			i_rst,
		input	logic			gpio_irq,
		input	logic			ptc_irq,

		input	logic			i_ram_init_done,
		input	logic			i_ram_init_error,
		
		input	logic	[7:0]	i_wb_adr,
		input	logic	[31:0]	i_wb_dat,
		input	logic	[3:0]	i_wb_sel,
		input	logic			i_wb_we,
		input	logic			i_wb_cyc,
		input	logic			i_wb_stb,

		output	logic	[31:0]	o_wb_rdt,
		output	logic			o_wb_ack,

		output	logic	[31:0]	o_nmi_vec,
		output	logic			o_nmi_int,
		output	logic			o_timer_irq,
		output	logic			o_sw_irq3,
		output	logic			o_sw_irq4,
		output	logic	[ 7:0]	AN,
		output	logic	[ 6:0]	Digits_Bits
		);
		
logic	[3:0]			DecNumber;
logic	[7:0]			CharLetter;
logic					CharEn;
logic	[7:0] [7:0]		char_concat;
logic	[15:0]			CharEns_Reg;

logic	[7:0]			Enables_Reg;
logic	[63:0]			Digits_Reg;

logic	[3:0]	wb_sel_out;

logic	[7:0]	wb_adr_reg;  // internal signal for address bus
logic	[31:0]	wb_data_reg_in; 
logic	[31:0]	wb_data_reg_out;
logic			we_o; 
logic			re_o; // Write and read enable output for the core


`ifdef SIMPRINT
   logic [1023:0]  signature_file;
   integer 	f = 0;
   initial begin
      if ($value$plusargs("signature=%s", signature_file)) begin
	 $display("Writing signature to %0s", signature_file);
	 f = $fopen(signature_file, "w");
      end
   end
`endif

////  WISHBONE interface module
wb_module wb_module (
		.clk			(i_clk			), 
		                 
		.wb_rst_i		(i_rst			), 
		.wb_we_i		(i_wb_we		), 
		.wb_stb_i		(i_wb_stb		), 
		.wb_cyc_i		(i_wb_cyc		), 
		.wb_ack_o		(o_wb_ack		), 
		.wb_sel_i		(i_wb_sel		),
		.wb_adr_i		(i_wb_adr		),	//WISHBONE address line
		.wb_dat_i		(i_wb_dat		),   //input WISHBONE bus 
		.wb_dat_o		(o_wb_rdt		), 
		.wb_sel_out		(wb_sel_out),
		                 
		.wb_adr_reg		(wb_adr_reg		),  // internal signal for address bus
		.wb_data_reg_in	(wb_data_reg_in	), 
		.wb_data_reg_out(wb_data_reg_out),
		.we_o			(we_o			), 
		.re_o			(re_o			) // Write and read enable output for the core
);

SystemControllerMisc 
  #(
		.clk_freq_hz		(clk_freq_hz)
	) SystemControllerMisc
  (
		.i_clk				(i_clk				),
		.i_rst				(i_rst				),
		.gpio_irq			(gpio_irq			),
		.ptc_irq			(ptc_irq			),
		.o_timer_irq		(o_timer_irq		),
		.o_sw_irq3			(o_sw_irq3			),
		.o_sw_irq4			(o_sw_irq4			),
		.i_ram_init_done	(i_ram_init_done	),
		.i_ram_init_error	(i_ram_init_error	),
		.o_nmi_vec			(o_nmi_vec			),
		.o_nmi_int			(o_nmi_int			),
		
		.wb_adr_reg			(wb_adr_reg			),  // internal signal for address bus
		.wb_data_reg_in		(wb_data_reg_in		), 
		.wb_data_reg_out	(wb_data_reg_out	),
		.we_o				(we_o				), 
		.re_o				(re_o				), // Write and read enable output for the core
		.wb_sel_out			(wb_sel_out         ),
		.CharEns_Reg		(CharEns_Reg		),
		.Enables_Reg		(Enables_Reg		),
		.Digits_Reg			(Digits_Reg			)

	);
	// Eight-Digit 7 Segment Displays

	  SevSegDisplays_Controller SegDispl_Ctr(
	    .clk			(i_clk		),    
	    .rst_n			(i_rst		),
		.CharEns		(CharEns_Reg),
	    .Enables_Reg	(Enables_Reg), 
	    .Digits_Reg		(Digits_Reg	), 
	    .AN				(AN			),
	    .Digits_Bits	(Digits_Bits),
		.DecNumber		(),
		.CharLetter		(),
		.CharEn			(),
		.char_concat	()
	  );

endmodule
