//////////////////////////////////////////////////////////////////////
////                                                              ////
////  WISHBONE PWM/Timer/Counter                                  ////
////                                                              ////
////  This file is part of the PTC project                        ////
////  http://www.opencores.org/cores/ptc/                         ////
////                                                              ////
////  Description                                                 ////
////  Implementation of PWM/Timer/Counter IP core according to    ////
////  PTC IP core specification document.                         ////
////                                                              ////
////  To Do:                                                      ////
////   Nothing                                                    ////
////                                                              ////
////  Author(s):                                                  ////
////      - Damjan Lampret, lampret@opencores.org                 ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.4  2001/09/18 18:48:29  lampret
// Changed top level ptc into ptc_top. Changed defines.v into ptc_defines.v. Reset of the counter is now synchronous.
//
// Revision 1.3  2001/08/21 23:23:50  lampret
// Changed directory structure, defines and port names.
//
// Revision 1.2  2001/07/17 00:18:10  lampret
// Added new parameters however RTL still has some issues related to hrc_match and int_match
//
// Revision 1.1  2001/06/05 07:45:36  lampret
// Added initial RTL and test benches. There are still some issues with these files.
//
//

// synopsys translate_off
//`include "timescale.v"
// synopsys translate_on
`include "timer_defines.v"

module timer_top(
	// WISHBONE Interface
	wb_clk_i, wb_rst_i, wb_cyc_i, wb_adr_i, wb_dat_i, wb_sel_i, wb_we_i, wb_stb_i,
	wb_dat_o, wb_ack_o, wb_err_o, wb_inta_o,

	// External PTC Interface
	gate_clk_pad_i, capt_pad_i, pwm_pad_o, oen_padoen_o
);

parameter dw = 32;
parameter aw = `PTC_ADDRHH+1;
parameter cw = `PTC_CW;


//
// WISHBONE Interface
//
input wire		wb_clk_i;	// Clock
input wire		wb_rst_i;	// Reset
input wire		wb_cyc_i;	// cycle valid input
input wire	[aw-1:0]	wb_adr_i;	// address bus inputs
input wire	[dw-1:0]	wb_dat_i;	// input data bus
input wire	[3:0]		wb_sel_i;	// byte select inputs
input wire			wb_we_i;	// indicates write transfer
input wire		wb_stb_i;	// strobe input
output		[dw-1:0]	wb_dat_o;	// output data bus
output wire		wb_ack_o;	// normal termination
output wire		wb_err_o;	// termination w/ error
output wire		wb_inta_o;	// Interrupt request output

//
// External PTC Interface
//
input wire	gate_clk_pad_i;	// EClk/Gate input
input wire	capt_pad_i;	// Capture input
output 		pwm_pad_o;	// PWM output
output wire	oen_padoen_o;	// PWM output driver enable

wb_module_timer wb_module_timer (
		.clk			(wb_clk_i		), 
		                 
		.wb_rst_i		(wb_rst_i		), 
		.wb_we_i		(wb_we_i		), 
		.wb_stb_i		(wb_stb_i		), 
		.wb_cyc_i		(wb_cyc_i		), 
		.wb_ack_o		(wb_ack_o		), 
		.wb_sel_i		(wb_sel_i		),
		.wb_adr_i		(wb_adr_i		),	//WISHBONE address line
		.wb_dat_i		(wb_dat_i		),   //input WISHBONE bus 
		.wb_dat_o		(wb_dat_o		), 	
		.wb_inta_o		(wb_inta_o		),
		.wb_err_o		(wb_err_o		),
		                 
		.wb_inta_i_internal	(1'b0			),
		.wb_err_i		(1'b0			),
		                 
		.wb_adr_reg		(),  // internal signal for address bus
		.wb_data_reg_in	(0), 
		.wb_data_reg_out(),
		.wb_inta_i		(1'b0),  // Interrupt request output
		.wb_sel_out		(),
		.we_o			(), 
		.re_o			() // Write and read enable output for the core
);



endmodule
