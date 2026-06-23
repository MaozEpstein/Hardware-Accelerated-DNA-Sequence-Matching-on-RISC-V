/*
* Wishbone BFM testbench
*/

`define TB_REG_CONTROL  32'h00000000
`define TB_REG_A        32'h00000004
`define TB_REG_B        32'h00000008
`define TB_REG_C        32'h0000000C
`define TB_REG_D        32'h00000010
`define TB_REG_RESULT   32'h00000014

`define GO_BIT          32'h00000001
`define DONE_BIT        32'h80000000

module wishbone_accelerator_tb;
`include "wishbone_accelerator_tb_include.svh"


   always #5 wb_clk <= ~wb_clk;
   initial  #100 wb_rst <= 0;


accelerator_top accelerator_top	(

		.wb_clk_i	(wb_clk			),

		.wb_rst_i	(wb_rst			),
		.wb_adr_i	(wb_m2s_addr	),
		.wb_dat_i	(wb_m2s_data	),
		.wb_dat_o	(wb_s2m_data	),
		.wb_we_i	(wb_m2s_we		),
		.wb_stb_i	(wb_m2s_stb		),
		.wb_cyc_i	(wb_m2s_cyc		),
		.wb_sel_i	(wb_m2s_sel		),
		.wb_ack_o	(wb_s2m_ack		),
		.int_o		(wb_s2m_inta	)

	);

    initial begin
        $display("Test start *****************");

        // ----------------------------------------------------------------
        // Test vector:
        //   A vector = [1, 2, 3, 4]   B vector = [5, 6, 7, 8]
        //   C vector = [9,10,11,12]   D vector = [13,14,15,16]
        //
        // Packing: byte0 -> [7:0], byte1 -> [15:8], byte2 -> [23:16], byte3 -> [31:24]
        //   reg_A = 0x04030201
        //   reg_B = 0x08070605
        //   reg_C = 0x0C0B0A09
        //   reg_D = 0x100F0E0D
        //
        // Expected dot product:
        //   1*5 + 2*6 + 3*7 + 4*8  +  9*13 + 10*14 + 11*15 + 12*16
        // =  5  +  12 +  21 +  32  +  117  +  140  +  165  +  192
        // =  70                    +  614
        // =  684 (decimal) = 0x2AC
        // ----------------------------------------------------------------

        // 1. Write input vectors
        wb_write(`TB_REG_A, 32'h04030201);
        wb_write(`TB_REG_B, 32'h08070605);
        wb_write(`TB_REG_C, 32'h0C0B0A09);
        wb_write(`TB_REG_D, 32'h100F0E0D);

        // 2. Trigger the accelerator (Go = 1)
        wb_write(`TB_REG_CONTROL, `GO_BIT);

        // 3. Poll Control until Done bit (bit 31) is set
        do begin
            wb_read(`TB_REG_CONTROL);
        end while ((wb_s2m_data & `DONE_BIT) == 0);

        // 4. Read the result
        wb_read(`TB_REG_RESULT);
        $display("[%t] Result = %0d (expected 684 = 0x2AC)", $realtime, wb_s2m_data);

        $display("Test complete **************");
        #1000 $finish;
    end

endmodule
