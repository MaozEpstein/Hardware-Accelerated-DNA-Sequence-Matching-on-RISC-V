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


// Register addresses


`define 	CharEns_REG					7'd1	// 
`define 	SW_IRQ_REG					7'd2	// 
`define 	NMI_VEC_REG					7'd3	// 

`define		Digits_Reg_MSB_REG			7'd5
`define		IRQ_GPIO_PTC_ENABLE_REG		7'd6
`define		CLK_FREQ_HZ_REG				7'd7
`define		MTIME_REG					7'd8
`define		FPGA_REVISION_LSB_REG		7'd4
`define 	FPGA_REVISION_MSB_REG		7'd9	// 
`define		MTIMECMP_LSB_REG			7'd10
`define		MTIMECMP_MSB_REG			7'd11
`define		IRQ_TIMER_CNT_EN_REG		7'd12
`define		IRQ_TIMER_EN_REG			7'd13
`define		ENABLES_REG					7'd14
`define		DIGIT_REG_LSB_REG			7'd15

module SystemControllerMisc
  #(parameter [31:0] clk_freq_hz = 0)
  (
	input	logic			i_clk,
	input	logic			i_rst,
	input	logic			gpio_irq,
	input	logic			ptc_irq,
	output	logic			o_timer_irq,
	output	logic			o_sw_irq3,
	output	logic			o_sw_irq4,
	input	logic			i_ram_init_done,
	input	logic			i_ram_init_error,
	output	logic	[31:0]	o_nmi_vec,
	output	logic			o_nmi_int,

	input	logic	[5:0]	wb_adr_reg,  // internal signal for address bus
	output	logic	[31:0]	wb_data_reg_in, 
	input	logic	[31:0]	wb_data_reg_out,
	input	logic	[3:0]	wb_sel_out,
	input	logic			we_o, 
	input	logic			re_o, // Write and read enable output for the core

	output	logic	[15:0]	CharEns_Reg,
	output	logic	[ 7:0]  Enables_Reg,
	output	logic	[63:0]  Digits_Reg
	);

	logic	[63:0]	mtime;
	logic	[63:0]	mtimecmp;
	
	logic			sw_irq3;
	logic			sw_irq3_edge;
	logic			sw_irq3_pol;
	logic			sw_irq3_timer;
	logic			sw_irq4;
	logic			sw_irq4_edge;
	logic			sw_irq4_pol;
	logic			sw_irq4_timer;
	
	logic			irq_timer_en;
	logic	[31:0]	irq_timer_cnt;
	
	logic			irq_gpio_enable;
	logic			irq_ptc_enable;
	
	logic			nmi_int;
	logic			nmi_int_r;
	logic   [3:0]   addr_i;
			

`ifndef VERSION_DIRTY
 `define VERSION_DIRTY 1
`endif
`ifndef VERSION_MAJOR
 `define VERSION_MAJOR 255
`endif
`ifndef VERSION_MINOR
 `define VERSION_MINOR 255
`endif
`ifndef VERSION_REV
 `define VERSION_REV 255
`endif
`ifndef VERSION_SHA
 `define VERSION_SHA deadbeef
`endif


/*
   assign version[31]    = `VERSION_DIRTY;
   assign version[30:24] = `VERSION_REV;
   assign version[23:16] = `VERSION_MAJOR;
   assign version[15: 8] = 8'h02;
   assign version[ 7: 0] = 8'h24;
   */
   
logic			reg_we;
logic			reg_re;

logic	[31:0]	FPGA_REVISION_MSB	;
logic	[31:0]	FPGA_REVISION_LSB	;

logic	[0:7] [7:0] VERSION   ="EL2nn-02"; //EL2, n-MexysA7100T, n-No DDR, 02- Version
logic	[0:3] [7:0]	VERSION_LSB  =VERSION[4:7];
logic 	[0:3] [7:0]	VERSION_MSB  =VERSION[0:3];

// LITTLE ENDIAN TO BIGENDIAN
assign FPGA_REVISION_MSB[31:24] = VERSION_MSB[3];
assign FPGA_REVISION_MSB[23:16] = VERSION_MSB[2];
assign FPGA_REVISION_MSB[15:8]	= VERSION_MSB[1];
assign FPGA_REVISION_MSB[7:0]	= VERSION_MSB[0];

assign FPGA_REVISION_LSB[31:24] = VERSION_LSB[3];
assign FPGA_REVISION_LSB[23:16] = VERSION_LSB[2];
assign FPGA_REVISION_LSB[15:8]	= VERSION_LSB[1];
assign FPGA_REVISION_LSB[7:0]	= VERSION_LSB[0];
assign  addr_i                  = wb_adr_reg[5:2];

/*
   assign version[31]    = `VERSION_DIRTY;
   assign version[30:24] = `VERSION_REV;
   assign version[23:16] = `VERSION_MAJOR;
   assign version[15: 8] = 8'h02;
   assign version[ 7: 0] = 8'h24;
   */

   assign o_sw_irq4 = sw_irq4^sw_irq4_pol;
   assign o_sw_irq3 = sw_irq3^sw_irq3_pol;
   assign o_nmi_int = nmi_int | nmi_int_r;
  // assign reg_we = i_wb_cyc & i_wb_stb & i_wb_we & ~o_wb_ack;
   //assign reg_re = i_wb_cyc & i_wb_stb & ~i_wb_we & ~o_wb_ack;

 // Asynchronous reading here because the outputs are sampled in uart_wb.v file 
always_comb   // asynchrounous reading
begin
	case (addr_i)
	`CharEns_REG:				wb_data_reg_in = CharEns_Reg; //Alex Grinshpun				
	`SW_IRQ_REG: begin
								//0xB
								wb_data_reg_in[31:28] = {sw_irq4, sw_irq4_edge, sw_irq4_pol, sw_irq4_timer};
								wb_data_reg_in[27:24] = {sw_irq3, sw_irq3_edge, sw_irq3_pol, sw_irq3_timer};
								//0xA
								wb_data_reg_in[23:18] = 6'd0;
								wb_data_reg_in[17:16] = {i_ram_init_error, i_ram_init_done};
								//0x8-0x9
								wb_data_reg_in[15:0]  = 16'd0;
	end						
	`NMI_VEC_REG:				wb_data_reg_in = o_nmi_vec;				
	`Digits_Reg_MSB_REG		:	wb_data_reg_in = Digits_Reg[63:32];		
	`IRQ_GPIO_PTC_ENABLE_REG:	wb_data_reg_in = {30'd0, irq_ptc_enable, irq_gpio_enable};
	`CLK_FREQ_HZ_REG		:	wb_data_reg_in = clk_freq_hz;
	`MTIME_REG				:	wb_data_reg_in = mtime[31:0];
	`FPGA_REVISION_LSB_REG	:	wb_data_reg_in = FPGA_REVISION_LSB;
	`FPGA_REVISION_MSB_REG	:	wb_data_reg_in = FPGA_REVISION_MSB;
	`MTIMECMP_LSB_REG		:	wb_data_reg_in = mtimecmp[31:0];
	`MTIMECMP_MSB_REG		:	wb_data_reg_in = mtimecmp[63:32];
	`IRQ_TIMER_CNT_EN_REG	:	wb_data_reg_in = irq_timer_cnt;
	`IRQ_TIMER_EN_REG		:	wb_data_reg_in = {31'd0, irq_timer_en};
	`ENABLES_REG			:	wb_data_reg_in = {24'd0, Enables_Reg[7:0]};	
	`DIGIT_REG_LSB_REG	    :	wb_data_reg_in = Digits_Reg[31:0];
	endcase // 
end // 
   //00 = ver
   //04 = sha
   //08 = simprint
   //09 = simexit
   //0A = RAM status
   //0B = sw_irq
   //20 = timer/timecmp
   //40 = SPI
   always_ff @(posedge i_clk) begin
		if (i_rst) begin
			o_nmi_vec		<=	32'h0;//Alex Grinshpun
			nmi_int			<=	1'b0;
			irq_gpio_enable <=	1'b0; //Alex Grinshpun
			irq_ptc_enable	<=	1'b0; //Alex Grinshpun
			mtime			<=	64'd0;
			mtimecmp		<=	64'd0;
			CharEns_Reg		<=	'0;
			
			
			irq_timer_en	<=	1'b0;
			irq_timer_cnt	<=	'0;

			sw_irq3			<=	1'b0;
			sw_irq3_edge	<=	1'b0;
			sw_irq3_pol		<=	1'b0;
			sw_irq3_timer	<=	1'b0;
			sw_irq4			<=	1'b0;
			sw_irq4_edge	<=	1'b0;
			sw_irq4_pol		<=	1'b0;
			sw_irq4_timer	<=	1'b0;

		end
		else	begin
		
			//Alex Grinshpun o_wb_ack			<= i_wb_cyc & i_wb_stb & ~o_wb_ack;
			nmi_int				<= 1'b0;
			nmi_int_r			<= nmi_int;
			
			// GPIO Interrupt through IRQ4. Enable by setting bit 0 of word 0x80001018
			if (irq_gpio_enable & gpio_irq) begin
				sw_irq4 <= 1'b1;
			end
			
			// Timer (PTC) Interrupt through IRQ3. Enable by setting bit 1 of word 0x80001018
			if (irq_ptc_enable & ptc_irq) begin
				sw_irq3 <= 1'b1;
			end
			
			// SweRVolf simple timer and software interrupts. Enable by resetting bits 0 and 1 of word 0x80001018
			if (!irq_gpio_enable & !irq_ptc_enable) begin
				if (sw_irq3_edge)
					sw_irq3 <= 1'b0;
				if (sw_irq4_edge)
					sw_irq4 <= 1'b0;
			
				if (irq_timer_en)
					irq_timer_cnt <= irq_timer_cnt - 1;
			
				if (irq_timer_cnt == 32'd1) begin
					irq_timer_en <= 1'b0;
				if (sw_irq3_timer)
					sw_irq3 <= 1'b1;
				if (sw_irq4_timer)
					sw_irq4 <= 1'b1;
				if (!(sw_irq3_timer | sw_irq4_timer))
					nmi_int <= 1'b1;
				end
			
			end

			if (we_o ) begin
				case (addr_i)
				`CharEns_REG: begin //0x04
					CharEns_Reg		<= wb_data_reg_out[15:0]; //Alex Grinshpun LSB - every bit "1" ASCII display, MSB - every bit "1" corresponds to Seven Segment Blinking
				end				
				`SW_IRQ_REG: begin //0x08-0x0B
					`ifdef SIMPRINT
						if (i_wb_sel[0]) begin
							if (|f) $fwrite(f, "%c", wb_data_reg_out[7:0]);
							$write("%c", wb_data_reg_out[7:0]);
							end
							if (i_wb_sel[1]) begin
								$display("\nFinito");
								$finish;
							end
					`endif
						if (wb_sel_out[3]) begin
							sw_irq4       <= wb_data_reg_out[31];
							sw_irq4_edge  <= wb_data_reg_out[30];
							sw_irq4_pol   <= wb_data_reg_out[29];
							sw_irq4_timer <= wb_data_reg_out[28];
							sw_irq3       <= wb_data_reg_out[27];
							sw_irq3_edge  <= wb_data_reg_out[26];
							sw_irq3_pol   <= wb_data_reg_out[25];
							sw_irq3_timer <= wb_data_reg_out[24];
					end
				end				
				`NMI_VEC_REG: begin //0x0C-0x0F
					if (wb_sel_out[0]) o_nmi_vec[7:0]		<= wb_data_reg_out[7:0];
					if (wb_sel_out[1]) o_nmi_vec[15:8]	<= wb_data_reg_out[15:8];
					if (wb_sel_out[2]) o_nmi_vec[23:16]	<= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) o_nmi_vec[31:24]	<= wb_data_reg_out[31:24];
				end				
				`Digits_Reg_MSB_REG: begin //Alex Grinshpun
					if (wb_sel_out[0]) Digits_Reg[39:32]	<= wb_data_reg_out[7:0];
					if (wb_sel_out[1]) Digits_Reg[47:40]	<= wb_data_reg_out[15:8];
					if (wb_sel_out[2]) Digits_Reg[55:48]	<= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) Digits_Reg[63:56]	<= wb_data_reg_out[31:24];
				end		
				`IRQ_GPIO_PTC_ENABLE_REG: begin //0x18-0x1B
					if (wb_sel_out[0])
						irq_gpio_enable <= wb_data_reg_out[0];
						irq_ptc_enable	<=  wb_data_reg_out[1];
					end
				`MTIMECMP_LSB_REG: begin //0x28-0x2B
					if (wb_sel_out[0]) mtimecmp[7:0]   <= wb_data_reg_out[7:0];
					if (wb_sel_out[1]) mtimecmp[15:8]  <= wb_data_reg_out[15:8];
					if (wb_sel_out[2]) mtimecmp[23:16] <= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) mtimecmp[31:24] <= wb_data_reg_out[31:24];
				end
				`MTIMECMP_MSB_REG: begin //0x2C-0x2F
					if (wb_sel_out[0]) mtimecmp[39:32] <= wb_data_reg_out[7:0];
					if (wb_sel_out[1]) mtimecmp[47:40] <= wb_data_reg_out[15:8];
					if (wb_sel_out[2]) mtimecmp[55:48] <= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) mtimecmp[63:56] <= wb_data_reg_out[31:24];
				end		
						
				`IRQ_TIMER_CNT_EN_REG: begin //0x30-3f
					if (wb_sel_out[0]) irq_timer_cnt[7:0]   <= wb_data_reg_out[7:0]  ;
					if (wb_sel_out[1]) irq_timer_cnt[15:8]  <= wb_data_reg_out[15:8] ;
					if (wb_sel_out[2]) irq_timer_cnt[23:16] <= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) irq_timer_cnt[31:24] <= wb_data_reg_out[31:24];
				end

				`IRQ_TIMER_EN_REG: begin
					if (wb_sel_out[0])
						irq_timer_en <= wb_data_reg_out[0];
				end
				`ENABLES_REG: begin
				//14: begin
					if (wb_sel_out[0]) Enables_Reg[7:0]  <= wb_data_reg_out[7:0];
				end
				`DIGIT_REG_LSB_REG: begin
					if (wb_sel_out[0]) Digits_Reg[7:0]   <= wb_data_reg_out[7:0];
					if (wb_sel_out[1]) Digits_Reg[15:8]  <= wb_data_reg_out[15:8];
					if (wb_sel_out[2]) Digits_Reg[23:16] <= wb_data_reg_out[23:16];
					if (wb_sel_out[3]) Digits_Reg[31:24] <= wb_data_reg_out[31:24];
				end		
				endcase // case(wb_addr_i)			
			end
	end

    end
endmodule
	
	