/////////////////////////////////////////////////////////////////////
////                                                             ////
////  OpenCores                    MC68HC11E based SPI interface ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2002 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: simple_spi_top.v,v 1.5 2004-02-28 15:59:50 rherveille Exp $
//
//  $Date: 2004-02-28 15:59:50 $
//  $Revision: 1.5 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.4  2003/08/01 11:41:54  rherveille
//               Fixed some timing bugs.
//
//               Revision 1.3  2003/01/09 16:47:59  rherveille
//               Updated clkcnt size and decoding due to new SPR bit assignments.
//
//               Revision 1.2  2003/01/07 13:29:52  rherveille
//               Changed SPR bits coding.
//
//               Revision 1.1.1.1  2002/12/22 16:07:15  rherveille
//               Initial release
//
// Alex Grinshpun 2024 SystemVerilog version



//
// Motorola MC68HC11E based SPI interface
//
// Currently only MASTER mode is supported
//

module spi_master #(
  parameter SS_WIDTH = 1
)(
  // 8bit WISHBONE bus slave interface
	input	logic					clk_i,         // clock
	input	logic					rst_i,         // reset (synchronous active high)
	input	logic					cyc_i,         // cycle
	input	logic					stb_i,         // strobe
	input	logic	[7:0]			adr_i,         // address
	input	logic					we_i,          // write enable
	input	logic	[`PTC_ADDRHH+1:0:0]			dat_i,         // data input
	output	logic	[7:0]			dat_o,         // data output
	output	logic	      			ack_o,         // normal bus termination
	output	logic	      			inta_o,        // interrupt output
	
	// SPI port
	output	logic					sck_o,         // serial clock output
	output	logic	[SS_WIDTH-1:0]	ss_o,      // slave select (active low)
	output	logic					mosi_o,        // MasterOut SlaveIN
	input	logic					miso_i         // MasterIn SlaveOut
);

  //
  // Module body
  //
  logic  [7:0]          spcr;       // Serial Peripheral Control   Register ('HC11 naming)
  logic [7:0]          spsr;       // Serial Peripheral Status    Register ('HC11 naming)
  logic  [7:0]          sper;       // Serial Peripheral Extension Register
  logic  [7:0]          treg;       // Transmit Register
  logic  [SS_WIDTH-1:0] ss_r;       // Slave Select Register

  // fifo signals
  logic [7:0] rfdout;
  logic        wfre, rfwe;
  logic       rfre, rffull, rfempty;
  logic [7:0] wfdout;
  logic       wfwe, wffull, wfempty;

  // misc signals
  logic      tirq;     // transfer interrupt (selected number of transfers done)
  logic      wfov;     // write fifo overrun (writing while fifo full)
  logic [1:0] state;    // statemachine state
  logic [2:0] bcnt;

  //
  // Wishbone interface
  logic wb_acc = cyc_i & stb_i;       // WISHBONE access
  logic wb_wr  = wb_acc & we_i;       // WISHBONE write access

////  WISHBONE interface module
wb_module_spi_master wb_module_spi_master  (
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
		.wb_sel_out		(wb_sel_out		),
		.wb_err_o		(wb_err_o		),   // termination w/ error
		.wb_inta_o		(wb_inta_o		),  // Interrupt request output
		.wb_inta_i		(wb_inta_i		),
		.wb_err_i		(wb_err_i		),
		                 
		.wb_adr_reg		(wb_adr_reg		),  // internal signal for address bus
		.wb_data_reg_in	(wb_data_reg_in	), 
		.wb_data_reg_out(wb_data_reg_out),
		.we_o			(we_o			), 
		.re_o			(re_o			) // Write and read enable output for the core
);


endmodule

