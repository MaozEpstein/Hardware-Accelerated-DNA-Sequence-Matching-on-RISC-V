// Alex Grinshpun Dec 2023
// Register addresses
// Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED
//
// Idea B (Hackathon): the CPU sends RAW ASCII (no software encoding).  Each
// 16-base sequence arrives as 4 words of 4 ASCII bytes.  On every write this
// block decodes 4 bytes -> 4x 2-bit bases combinationally and stores them into
// one byte-lane of the packed register, so after 4 writes reg_a/reg_b hold the
// exact 2-bit-packed value the systolic core already expects.  The core
// (accelerator.sv) and its 2-bit datapath are UNCHANGED -> each core stays
// lean (important for fitting 8 cores).

`define ACCELERATOR_REG_CONTROL		8'h00	// bit0=go (w) ; bit31=done (r)
`define ACCELERATOR_REG_QUERY0		8'h04	// query  ASCII bytes  0..3
`define ACCELERATOR_REG_QUERY1		8'h08	// query  ASCII bytes  4..7
`define ACCELERATOR_REG_QUERY2		8'h0c	// query  ASCII bytes  8..11
`define ACCELERATOR_REG_QUERY3		8'h10	// query  ASCII bytes 12..15
`define ACCELERATOR_REG_REF0		8'h14	// ref    ASCII bytes  0..3
`define ACCELERATOR_REG_REF1		8'h18	// ref    ASCII bytes  4..7
`define ACCELERATOR_REG_REF2		8'h1c	// ref    ASCII bytes  8..11
`define ACCELERATOR_REG_REF3		8'h20	// ref    ASCII bytes 12..15  (write auto-starts)
`define ACCELERATOR_REG_RESULT		8'h24	// best local-alignment score


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
	output	logic	[31:0]			reg_a,		// query, 2-bit packed (to the core)
	output	logic	[31:0]			reg_b,		// ref,   2-bit packed (to the core)
	input	logic	[31:0]			reg_result,
	input	logic					done,
	output	logic					go
);

	// Decode 4 raw ASCII bytes (one Wishbone word) into 8 bits = 4x 2-bit bases.
	// Mapping (c>>1)&3 sends A/C/G/T -> 0/1/3/2 (a bijection; the core only tests
	// equality, so any consistent bijection yields identical scores).  Identical
	// to the software word-at-a-time encoder, now in hardware.
	function automatic logic [7:0] dna_decode4(input logic [31:0] w);
		logic [31:0] codes;
		begin
			codes = (w >> 1) & 32'h03030303;
			dna_decode4 = ( codes         & 32'h03)
			            | ((codes >> 6)   & 32'h0c)
			            | ((codes >> 12)  & 32'h30)
			            | ((codes >> 18)  & 32'hc0);
		end
	endfunction


// Asynchronous reading here because the outputs are sampled in uart_wb.v file
always_comb   // asynchrounous reading
begin
	case (wb_addr_i)
		`ACCELERATOR_REG_CONTROL	:	wb_dat_o = {done,30'h0,go};
		`ACCELERATOR_REG_RESULT	:	wb_dat_o = reg_result;
		default					:	wb_dat_o = 32'b0;
	endcase
end

//
//   WRITES AND RESETS   //
//
	// The auto-clear of "go" and the register writes share one sequential block
	// so that a write setting "go" wins over the auto-clear (later non-blocking
	// assignment wins) -> done stays reliably pollable between references.
	//
	// Auto-start: writing the LAST reference word (REF3) raises "go", so no
	// separate CONTROL/GO write is needed.  Each QUERY/REF write decodes its 4
	// ASCII bytes into the matching byte-lane of reg_a/reg_b.
	always_ff @(posedge clk or posedge wb_rst_i) begin
		if (wb_rst_i)	begin
			reg_a			<= '0;
			reg_b			<= '0;
			go				<= 1'b0;
        end
		else begin
			if (done)
				go			<= 1'b0; // auto-clear go after a completed run

			if (wb_we_i) begin
				case (wb_addr_i)
				`ACCELERATOR_REG_QUERY0	:	reg_a[7:0]   <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY1	:	reg_a[15:8]  <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY2	:	reg_a[23:16] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY3	:	reg_a[31:24] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REF0	:	reg_b[7:0]   <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REF1	:	reg_b[15:8]  <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REF2	:	reg_b[23:16] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REF3	:	begin
												reg_b[31:24] <= dna_decode4(wb_dat_i);
												go			 <= 1'b1; // auto-start the run
											end
				`ACCELERATOR_REG_CONTROL	:	go			<= wb_dat_i[0]; // explicit start still supported
				endcase
			end
		end
	end

endmodule
