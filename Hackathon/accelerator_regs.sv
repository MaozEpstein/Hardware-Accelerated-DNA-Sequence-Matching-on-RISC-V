// Alex Grinshpun Dec 2023
// Register addresses
// Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED
//
// Double-buffer (ping-pong) front-end (Hackathon):
//   The CPU still sends RAW ASCII (4 words per sequence, decoded in hardware).
//   There are now TWO reference buffers, A and B, each with its own result
//   register.  While the systolic core computes the reference in one buffer,
//   the CPU writes the next reference into the other buffer over Wishbone.
//   When a run finishes, hardware automatically chains to the other buffer if
//   it is pending.  This overlaps software data movement with the compute and
//   lets the driver read results WITHOUT polling (the next reference's writes
//   guarantee the current run has finished).
//
//   Per-buffer result registers make correctness timing-INDEPENDENT: the CPU
//   reads RESULT_A/RESULT_B by reference parity, and each holds its run's score
//   until the next run on the SAME buffer overwrites it.
//
//   The systolic core (accelerator.sv) is UNCHANGED: this block muxes the
//   active buffer onto reg_b, pulses go, and captures reg_result/done.

`define ACCELERATOR_REG_CONTROL		8'h00	// r: {busy, .., done_b, done_a}
`define ACCELERATOR_REG_QUERY0		8'h04	// query ASCII bytes 0..3
`define ACCELERATOR_REG_QUERY1		8'h08
`define ACCELERATOR_REG_QUERY2		8'h0c
`define ACCELERATOR_REG_QUERY3		8'h10
`define ACCELERATOR_REG_REFA0		8'h14	// buffer A: ref ASCII bytes 0..3
`define ACCELERATOR_REG_REFA1		8'h18
`define ACCELERATOR_REG_REFA2		8'h1c
`define ACCELERATOR_REG_REFA3		8'h20	// write -> buffer A pending (queue a run)
`define ACCELERATOR_REG_REFB0		8'h24	// buffer B: ref ASCII bytes 0..3
`define ACCELERATOR_REG_REFB1		8'h28
`define ACCELERATOR_REG_REFB2		8'h2c
`define ACCELERATOR_REG_REFB3		8'h30	// write -> buffer B pending (queue a run)
`define ACCELERATOR_REG_RESULTA		8'h34	// score of the last run on buffer A
`define ACCELERATOR_REG_RESULTB		8'h38	// score of the last run on buffer B


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
	output	logic	[31:0]			reg_b,		// active reference buffer (to the core)
	input	logic	[31:0]			reg_result,	// score from the core
	input	logic					done,		// core run finished
	output	logic					go			// start a run (1-cycle pulse)
);

	// Decode 4 raw ASCII bytes into 8 bits = 4x 2-bit bases (see Idea B).
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

	// ---- state -----------------------------------------------------------
	logic [31:0] buf_a, buf_b;        // two reference buffers (2-bit packed)
	logic        pending_a, pending_b;// a buffer holds a not-yet-run reference
	logic [31:0] result_a, result_b;  // per-buffer scores
	logic        done_a, done_b;      // per-buffer "result valid" flags
	logic        busy;                // a run is in progress
	logic        cur;                 // which buffer the current run uses (0=A,1=B)
	logic        nxt;                 // which buffer runs NEXT (enforces A,B,A,B order)
	logic        done_d;              // previous-cycle "done" (for rising-edge detect)

	// active buffer presented to the core (stable while busy)
	assign reg_b = cur ? buf_b : buf_a;

	// ---- asynchronous read -----------------------------------------------
	always_comb begin
		case (wb_addr_i)
			`ACCELERATOR_REG_CONTROL	:	wb_dat_o = {busy, 29'h0, done_b, done_a};
			`ACCELERATOR_REG_RESULTA	:	wb_dat_o = result_a;
			`ACCELERATOR_REG_RESULTB	:	wb_dat_o = result_b;
			default						:	wb_dat_o = 32'b0;
		endcase
	end

	// ---- writes + ping-pong controller -----------------------------------
	always_ff @(posedge clk or posedge wb_rst_i) begin
		if (wb_rst_i) begin
			reg_a     <= '0;
			buf_a     <= '0;  buf_b     <= '0;
			pending_a <= 1'b0; pending_b <= 1'b0;
			result_a  <= '0;  result_b  <= '0;
			done_a    <= 1'b0; done_b    <= 1'b0;
			busy      <= 1'b0; cur       <= 1'b0;
			nxt       <= 1'b0;
			done_d    <= 1'b0;
			go        <= 1'b0;
		end else begin
			go     <= 1'b0;   // go is a 1-cycle pulse
			done_d <= done;   // track core "done" for rising-edge detection

			// --- register writes (ASCII decoded into byte-lanes) ---
			if (wb_we_i) begin
				case (wb_addr_i)
				`ACCELERATOR_REG_QUERY0	:	reg_a[7:0]   <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY1	:	reg_a[15:8]  <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY2	:	reg_a[23:16] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_QUERY3	:	reg_a[31:24] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFA0	:	buf_a[7:0]   <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFA1	:	buf_a[15:8]  <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFA2	:	buf_a[23:16] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFA3	:	begin
												buf_a[31:24] <= dna_decode4(wb_dat_i);
												pending_a    <= 1'b1; // queue a run on A
												done_a       <= 1'b0; // result not ready until this run finishes
											end
				`ACCELERATOR_REG_REFB0	:	buf_b[7:0]   <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFB1	:	buf_b[15:8]  <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFB2	:	buf_b[23:16] <= dna_decode4(wb_dat_i);
				`ACCELERATOR_REG_REFB3	:	begin
												buf_b[31:24] <= dna_decode4(wb_dat_i);
												pending_b    <= 1'b1; // queue a run on B
												done_b       <= 1'b0; // result not ready until this run finishes
											end
				endcase
			end

			// --- ping-pong controller ---
			if (!busy) begin
				// strict alternation A,B,A,B... : run the NEXT buffer when its
				// reference is pending (matches the order the CPU fills them)
				if ((nxt == 1'b0) && pending_a) begin
					busy <= 1'b1; cur <= 1'b0; pending_a <= 1'b0;
					go <= 1'b1; nxt <= 1'b1;
				end else if ((nxt == 1'b1) && pending_b) begin
					busy <= 1'b1; cur <= 1'b1; pending_b <= 1'b0;
					go <= 1'b1; nxt <= 1'b0;
				end
			end else if (done & ~done_d) begin
				// capture on the RISING edge of done (the held level from the
				// previous run must not trigger a premature capture)
				if (cur == 1'b0) begin
					result_a <= reg_result; done_a <= 1'b1;
				end else begin
					result_b <= reg_result; done_b <= 1'b1;
				end
				busy <= 1'b0;
			end
		end
	end

endmodule
