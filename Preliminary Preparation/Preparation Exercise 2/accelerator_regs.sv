// Alex Grinshpun Dec 2023
// Register addresses
// Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED

`define ACCELERATOR_REG_CONTROL		8'h0	//
`define ACCELERATOR_REG_A			8'h4	// 
`define ACCELERATOR_REG_B			8'h8	// 
`define ACCELERATOR_REG_C			8'hc	//
`define ACCELERATOR_REG_D			8'h10	// 
`define ACCELERATOR_REG_RESULT		8'h14	// 


module accelerator_regs
#(parameter SIM = 0)
 (
	input	logic					clk,
	input	logic					wb_rst_i,
	input	logic	[7:0]			wb_addr_i,
	input	logic	[31:0]			wb_dat_i,
	output	logic	[31:0]			wb_dat_o,
	input	logic					wb_we_i,
	input	logic					wb_re_i,
	output	logic	[31:0]			reg_a,
	output	logic	[31:0]			reg_b,
	output	logic	[31:0]			reg_c,
	output	logic	[31:0]			reg_d,
	input	logic	[31:0]			reg_result,
	input	logic					done,
	output	logic					go
);


// Asynchronous reading here because the outputs are sampled in uart_wb.v file 
always_comb   // asynchrounous reading
begin
	case (wb_addr_i)
		`ACCELERATOR_REG_CONTROL	:	wb_dat_o = {done,30'h0,go};
		`ACCELERATOR_REG_A		:	wb_dat_o = reg_a;
		`ACCELERATOR_REG_B		:	wb_dat_o = reg_b;
		`ACCELERATOR_REG_C		:	wb_dat_o = reg_c;
		`ACCELERATOR_REG_D		:	wb_dat_o = reg_d;
		`ACCELERATOR_REG_RESULT	:	wb_dat_o = reg_result;
		default					:	wb_dat_o = 32'b0; // ??
	endcase // 
end // 

//
//   WRITES AND RESETS   //
//
	always_ff @(posedge clk or posedge wb_rst_i) begin
		if (wb_rst_i)	begin
			reg_a			<= '0;
			reg_b			<= '0;
			reg_c			<= '0;
			reg_d			<= '0;
			go				<= 1'b0;
        end
		else if (done) begin
			go				<= 1'b0; // reset go when done is high
		end

		else
			if (wb_we_i ) begin
				case (wb_addr_i)
				`ACCELERATOR_REG_A		:	reg_a		<= wb_dat_i[31:0];
				`ACCELERATOR_REG_B		:	reg_b		<= wb_dat_i[31:0];
				`ACCELERATOR_REG_C		:	reg_c		<= wb_dat_i[31:0];
				`ACCELERATOR_REG_D		:	reg_d		<= wb_dat_i[31:0];
				`ACCELERATOR_REG_CONTROL	:	go			<= wb_dat_i[0];
				endcase // case(wb_addr_i)			
			end
	end

endmodule
