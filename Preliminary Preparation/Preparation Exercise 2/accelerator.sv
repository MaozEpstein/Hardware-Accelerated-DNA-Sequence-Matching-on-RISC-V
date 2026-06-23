// Alex Grinshpun Dec 2023
//Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED

module accelerator
(
    // Control signals
	input	logic				clk,
	input	logic				wb_rst_i,


	input	logic	unsigned	[31:0]		reg_a,
	input	logic	unsigned	[31:0]		reg_b,
	input 	logic	unsigned	[31:0]		reg_c,
	input 	logic	unsigned	[31:0]		reg_d,
	input 	logic							go,
	output 	logic							done,
	output	logic	unsigned	[31:0]		reg_result
);

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
	logic [7:0] A [0:3];
	logic [7:0] B [0:3];
	logic [7:0] C [0:3];
	logic [7:0] D [0:3];

	assign A[0] = reg_a[7:0];
	assign A[1] = reg_a[15:8];
	assign A[2] = reg_a[23:16];
	assign A[3] = reg_a[31:24];

	assign B[0] = reg_b[7:0];
	assign B[1] = reg_b[15:8];
	assign B[2] = reg_b[23:16];
	assign B[3] = reg_b[31:24];

	assign C[0] = reg_c[7:0];
	assign C[1] = reg_c[15:8];
	assign C[2] = reg_c[23:16];
	assign C[3] = reg_c[31:24];

	assign D[0] = reg_d[7:0];
	assign D[1] = reg_d[15:8];
	assign D[2] = reg_d[23:16];
	assign D[3] = reg_d[31:24];

//-------------------------------------------------------------------------------
// Core interface
//-------------------------------------------------------------------------------

	logic [31:0] result_value;

//////////////CALCULATE RESULT////////////////////////////

	assign result_value = A[0]*B[0] + A[1]*B[1] + A[2]*B[2] + A[3]*B[3]
                        + C[0]*D[0] + C[1]*D[1] + C[2]*D[2] + C[3]*D[3];

//////////////////////////////////////////

	always_ff @(posedge clk or posedge wb_rst_i) begin
		if (wb_rst_i) begin
			reg_result	<=	32'h0;
			done		<=	1'b0;
		end
		else if (go) begin
			reg_result	<=	result_value;
			done		<=	1'b1;
		end
		else begin
			done		<=	1'b0;
		end
	end
endmodule
