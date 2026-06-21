/*
* Wishbone BFM testbench - DNA Smith-Waterman (Affine-Gap) accelerator
*
* Idea B: the host sends RAW ASCII (no encoding).  Each 16-base sequence is
* 4 words of 4 ASCII bytes.  Load the query once (QUERY0..3), then for each
* reference write REF0..3 (REF3 auto-starts), poll DONE, read RESULT and check
* it against the expected score from dna_match.c.
*
* Raw-ASCII word literals were pre-computed (little-endian: byte k of the
* sequence sits in bits [8k +: 8] of word k/4).
*/

`define TB_REG_CONTROL  32'h00000000
`define TB_REG_QUERY0   32'h00000004
`define TB_REG_QUERY1   32'h00000008
`define TB_REG_QUERY2   32'h0000000C
`define TB_REG_QUERY3   32'h00000010
`define TB_REG_REF0     32'h00000014
`define TB_REG_REF1     32'h00000018
`define TB_REG_REF2     32'h0000001C
`define TB_REG_REF3     32'h00000020
`define TB_REG_RESULT   32'h00000024

`define DONE_BIT        32'h80000000

`define NUM_REFS        8

module wishbone_accelerator_tb;
`include "wishbone_accelerator_tb_include.svh"

   // query "ACGTCGTACGTACGTA" as 4 raw-ASCII words
   logic [31:0] q_w [0:3];

   // references (raw-ASCII words) and their expected best local-alignment scores
   logic [31:0] ref_w     [0:`NUM_REFS-1][0:3];
   integer      exp_score [0:`NUM_REFS-1];

   integer i;
   integer got;
   integer errors;

   always #5 wb_clk <= ~wb_clk;
   initial  #100 wb_rst <= 0;

   accelerator_top accelerator_top (
       .wb_clk_i (wb_clk      ),
       .wb_rst_i (wb_rst      ),
       .wb_adr_i (wb_m2s_addr ),
       .wb_dat_i (wb_m2s_data ),
       .wb_dat_o (wb_s2m_data ),
       .wb_we_i  (wb_m2s_we   ),
       .wb_stb_i (wb_m2s_stb  ),
       .wb_cyc_i (wb_m2s_cyc  ),
       .wb_sel_i (wb_m2s_sel  ),
       .wb_ack_o (wb_s2m_ack  ),
       .int_o    (wb_s2m_inta )
   );

   initial begin
       // query "ACGTCGTACGTACGTA"
       q_w[0]=32'h54474341; q_w[1]=32'h41544743; q_w[2]=32'h41544743; q_w[3]=32'h41544743;

       // references (raw ASCII) + expected scores
       ref_w[0][0]=32'h54474341; ref_w[0][1]=32'h54474341; ref_w[0][2]=32'h54474341; ref_w[0][3]=32'h54474341; exp_score[0]=26; // ACGTACGTACGTACGT
       ref_w[1][0]=32'h54474341; ref_w[1][1]=32'h54474354; ref_w[1][2]=32'h54474341; ref_w[1][3]=32'h54474341; exp_score[1]=26; // ACGTTCGTACGTACGT
       ref_w[2][0]=32'h54474341; ref_w[2][1]=32'h47474341; ref_w[2][2]=32'h54474341; ref_w[2][3]=32'h54474341; exp_score[2]=23; // ACGTACGGACGTACGT
       ref_w[3][0]=32'h54545454; ref_w[3][1]=32'h54545454; ref_w[3][2]=32'h54545454; ref_w[3][3]=32'h54545454; exp_score[3]= 2; // TTTTTTTTTTTTTTTT
       ref_w[4][0]=32'h54474341; ref_w[4][1]=32'h54474341; ref_w[4][2]=32'h54474354; ref_w[4][3]=32'h54474341; exp_score[4]=23; // ACGTACGTTCGTACGT
       ref_w[5][0]=32'h54474341; ref_w[5][1]=32'h54474341; ref_w[5][2]=32'h54474341; ref_w[5][3]=32'h41474341; exp_score[5]=24; // ACGTACGTACGTACGA
       ref_w[6][0]=32'h54474341; ref_w[6][1]=32'h54475454; ref_w[6][2]=32'h54474341; ref_w[6][3]=32'h54474341; exp_score[6]=23; // ACGTTTGTACGTACGT
       ref_w[7][0]=32'h54474341; ref_w[7][1]=32'h54474341; ref_w[7][2]=32'h54474347; ref_w[7][3]=32'h54474341; exp_score[7]=23; // ACGTACGTGCGTACGT

       errors = 0;
       $display("==== DNA Smith-Waterman accelerator test (Idea B: raw ASCII) ====");

       // 1) load the query once (4 raw words)
       wb_write(`TB_REG_QUERY0, q_w[0]);
       wb_write(`TB_REG_QUERY1, q_w[1]);
       wb_write(`TB_REG_QUERY2, q_w[2]);
       wb_write(`TB_REG_QUERY3, q_w[3]);

       // 2) per reference: write 4 raw words (REF3 auto-starts), poll DONE, read
       for (i = 0; i < `NUM_REFS; i = i + 1) begin
           wb_write(`TB_REG_REF0, ref_w[i][0]);
           wb_write(`TB_REG_REF1, ref_w[i][1]);
           wb_write(`TB_REG_REF2, ref_w[i][2]);
           wb_write(`TB_REG_REF3, ref_w[i][3]);   // auto-starts the run

           do begin
               wb_read(`TB_REG_CONTROL);
           end while ((wb_s2m_data & `DONE_BIT) == 0);

           wb_read(`TB_REG_RESULT);
           got = wb_s2m_data;

           if (got === exp_score[i])
               $display("Reference %0d score = %0d  (OK)", i, got);
           else begin
               $display("Reference %0d score = %0d  (FAIL, expected %0d)",
                        i, got, exp_score[i]);
               errors = errors + 1;
           end
       end

       if (errors == 0)
           $display("==== ALL %0d REFERENCES PASSED ====", `NUM_REFS);
       else
           $display("==== %0d MISMATCH(ES) ====", errors);

       #1000 $finish;
   end

endmodule
