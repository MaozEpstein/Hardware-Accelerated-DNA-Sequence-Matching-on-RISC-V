/*
* Wishbone BFM testbench - DNA Smith-Waterman accelerator (double-buffer)
*
* Pipelined / ping-pong flow:
*   - load the query once (QUERY0..3, raw ASCII)
*   - send reference 0 into buffer A
*   - then for each i: prefetch reference i+1 into the OTHER buffer while the
*     core runs reference i, and read reference i's score from RESULT_A/RESULT_B
*     by parity - NO polling (the prefetch writes guarantee the run finished).
*   Hardware auto-chains: finishing a run starts the other pending buffer.
*/

`define TB_CONTROL   32'h00000000
`define TB_QUERY0    32'h00000004
`define TB_REFA0     32'h00000014
`define TB_REFB0     32'h00000024
`define TB_RESULTA   32'h00000034
`define TB_RESULTB   32'h00000038

`define NUM_REFS     8

module wishbone_accelerator_tb;
`include "wishbone_accelerator_tb_include.svh"

   logic [31:0] q_w   [0:3];
   logic [31:0] ref_w [0:`NUM_REFS-1][0:3];
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

   // Model real-hardware per-write bus latency (~42 cycles through the
   // AXI->Wishbone bridge).  The simple BFM acks in ~4 cycles, which is far
   // faster than the FPGA and would not let the systolic run (~36 cycles) hide
   // under the next reference's writes.  On real hardware 4 writes (~168 cyc)
   // comfortably exceed one run, so the pipeline is safe; here we re-create
   // that margin so Icarus exercises the same logic.
   task slow_write(input [31:0] addr, input [31:0] data);
   begin
       wb_write(addr, data);
       repeat (30) @(posedge wb_clk);
   end
   endtask

   // send the 4 raw-ASCII words of reference index k to a buffer base address
   task send_ref(input integer k, input [31:0] base);
   begin
       slow_write(base + 32'h0, ref_w[k][0]);
       slow_write(base + 32'h4, ref_w[k][1]);
       slow_write(base + 32'h8, ref_w[k][2]);
       slow_write(base + 32'hC, ref_w[k][3]);
   end
   endtask

   initial begin
       // query "ACGTCGTACGTACGTA"
       q_w[0]=32'h54474341; q_w[1]=32'h41544743; q_w[2]=32'h41544743; q_w[3]=32'h41544743;

       ref_w[0][0]=32'h54474341; ref_w[0][1]=32'h54474341; ref_w[0][2]=32'h54474341; ref_w[0][3]=32'h54474341; exp_score[0]=26; // ACGTACGTACGTACGT
       ref_w[1][0]=32'h54474341; ref_w[1][1]=32'h54474354; ref_w[1][2]=32'h54474341; ref_w[1][3]=32'h54474341; exp_score[1]=26; // ACGTTCGTACGTACGT
       ref_w[2][0]=32'h54474341; ref_w[2][1]=32'h47474341; ref_w[2][2]=32'h54474341; ref_w[2][3]=32'h54474341; exp_score[2]=23; // ACGTACGGACGTACGT
       ref_w[3][0]=32'h54545454; ref_w[3][1]=32'h54545454; ref_w[3][2]=32'h54545454; ref_w[3][3]=32'h54545454; exp_score[3]= 2; // TTTTTTTTTTTTTTTT
       ref_w[4][0]=32'h54474341; ref_w[4][1]=32'h54474341; ref_w[4][2]=32'h54474354; ref_w[4][3]=32'h54474341; exp_score[4]=23; // ACGTACGTTCGTACGT
       ref_w[5][0]=32'h54474341; ref_w[5][1]=32'h54474341; ref_w[5][2]=32'h54474341; ref_w[5][3]=32'h41474341; exp_score[5]=24; // ACGTACGTACGTACGA
       ref_w[6][0]=32'h54474341; ref_w[6][1]=32'h54475454; ref_w[6][2]=32'h54474341; ref_w[6][3]=32'h54474341; exp_score[6]=23; // ACGTTTGTACGTACGT
       ref_w[7][0]=32'h54474341; ref_w[7][1]=32'h54474341; ref_w[7][2]=32'h54474347; ref_w[7][3]=32'h54474341; exp_score[7]=23; // ACGTACGTGCGTACGT

       errors = 0;
       $display("==== DNA accelerator test (double-buffer / ping-pong) ====");

       // load the query once
       wb_write(`TB_QUERY0 + 32'h0, q_w[0]);
       wb_write(`TB_QUERY0 + 32'h4, q_w[1]);
       wb_write(`TB_QUERY0 + 32'h8, q_w[2]);
       wb_write(`TB_QUERY0 + 32'hC, q_w[3]);

       // prime the pipeline: reference 0 -> buffer A
       send_ref(0, `TB_REFA0);

       for (i = 0; i < `NUM_REFS; i = i + 1) begin
           // prefetch the next reference into the opposite buffer; its writes
           // overlap the current run and provide the delay that makes the
           // poll-free read of the current result safe.
           if (i + 1 < `NUM_REFS)
               send_ref(i + 1, ((i + 1) & 1) ? `TB_REFB0 : `TB_REFA0);
           else
               // the LAST reference has no following prefetch: poll its done
               // flag once (1 transaction) before reading - the only poll left.
               do wb_read(`TB_CONTROL);
               while ((wb_s2m_data & ((i & 1) ? 32'h2 : 32'h1)) == 0);

           // read this reference's score by buffer parity
           wb_read((i & 1) ? `TB_RESULTB : `TB_RESULTA);
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
