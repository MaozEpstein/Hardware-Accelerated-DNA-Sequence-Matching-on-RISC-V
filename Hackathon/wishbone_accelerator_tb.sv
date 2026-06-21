/*
* Wishbone BFM testbench - DNA Smith-Waterman (Affine-Gap) accelerator
*
* Loads the query once (reg_a), then streams each of the 8 references
* (reg_b), triggers a run via the GO bit, polls the DONE bit, reads the
* RESULT, and checks it against the expected score from dna_match.c.
*
* 2-bit base encoding A=00,C=01,G=10,T=11; base k in bits [2k +: 2].
* Packed values pre-computed (see comments) so the TB needs no string logic.
*/

`define TB_REG_CONTROL  32'h00000000
`define TB_REG_A        32'h00000004   // query_packed
`define TB_REG_B        32'h00000008   // ref_packed (write auto-starts the run)
`define TB_REG_RESULT   32'h00000014

`define DONE_BIT        32'h80000000

`define NUM_REFS        8

module wishbone_accelerator_tb;
`include "wishbone_accelerator_tb_include.svh"

   // query  "ACGTCGTACGTACGTA"
   localparam [31:0] QUERY = 32'h393939E4;

   // references and their expected best local-alignment scores
   logic [31:0] ref_packed [0:`NUM_REFS-1];
   integer      exp_score  [0:`NUM_REFS-1];

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
       // reference dataset (packed) and expected scores
       ref_packed[0] = 32'hE4E4E4E4;  exp_score[0] = 26; // ACGTACGTACGTACGT
       ref_packed[1] = 32'hE4E4E7E4;  exp_score[1] = 26; // ACGTTCGTACGTACGT
       ref_packed[2] = 32'hE4E4A4E4;  exp_score[2] = 23; // ACGTACGGACGTACGT
       ref_packed[3] = 32'hFFFFFFFF;  exp_score[3] =  2; // TTTTTTTTTTTTTTTT
       ref_packed[4] = 32'hE4E7E4E4;  exp_score[4] = 23; // ACGTACGTTCGTACGT
       ref_packed[5] = 32'h24E4E4E4;  exp_score[5] = 24; // ACGTACGTACGTACGA
       ref_packed[6] = 32'hE4E4EFE4;  exp_score[6] = 23; // ACGTTTGTACGTACGT
       ref_packed[7] = 32'hE4E6E4E4;  exp_score[7] = 23; // ACGTACGTGCGTACGT

       errors = 0;
       $display("==== DNA Smith-Waterman accelerator test ====");

       // 1) load the query once
       wb_write(`TB_REG_A, QUERY);

       // 2) for each reference: write, trigger, poll DONE, read score
       for (i = 0; i < `NUM_REFS; i = i + 1) begin
           wb_write(`TB_REG_B, ref_packed[i]);   // writing REF auto-starts the run (3.1)

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
