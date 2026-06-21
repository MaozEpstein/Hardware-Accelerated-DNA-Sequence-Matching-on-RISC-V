
   localparam aw = 32;
   localparam dw = 32;

   logic	   wb_clk = 1'b1;
   logic	   wb_rst = 1'b1;

   logic    done;

   logic	[31:0]	wb_m2s_addr;
   logic	[31:0]	wb_m2s_data;
   logic	[3:0]   wb_m2s_sel;
   logic          wb_m2s_we ;
   logic          wb_m2s_cyc;
   logic          wb_m2s_stb;
   logic	[2:0]   wb_m2s_cti;
   logic	[1:0]   wb_m2s_bte;
   logic	[31:0]	wb_s2m_data;
   logic          wb_s2m_ack;
   logic          wb_s2m_err;
   logic          wb_s2m_rty;
   logic          wb_s2m_inta;


  task wb_read (
	input [31:0]           addr
	);
    begin
		if(wb_rst !== 1'b0) begin
			@(negedge wb_rst);
			@(posedge wb_clk);
		end

		#500ns

      wb_m2s_sel               <= 	4'hF;
      wb_m2s_we                <= 	1'b0;
      wb_m2s_cyc               <= 	1'b1;
      wb_m2s_addr              <= 	addr;
      wb_m2s_stb               <= 	1'b1; 
        
		@(posedge wb_clk);
		while(wb_s2m_ack !== 1'b1)
			@(posedge wb_clk);
		end
		$display("[%t] Wishbone bus  read addr %x data %x",$realtime,wb_m2s_addr, wb_s2m_data );
		wb_m2s_we                <=  1'b0;
		wb_m2s_cyc               <=  1'b0;
		wb_m2s_stb               <=  1'b0; 
  endtask // while

    task wb_write (
	input [31:0]           addr,
	input [31:0]           data);
    begin
		if(wb_rst !== 1'b0) begin
			@(negedge wb_rst);
			@(posedge wb_clk);
		end
		#500ns
		wb_m2s_sel               <= 	4'hF;
		wb_m2s_we                <= 	1'b1;
		wb_m2s_cyc               <= 	1'b1;
		wb_m2s_addr              <= 	addr;
		wb_m2s_data               <= 	data;
		wb_m2s_stb               <= 	1'b1;
        
		@(posedge wb_clk);
		while(wb_s2m_ack !== 1'b1)
			@(posedge wb_clk);
			wb_m2s_data	= data ;
		end
		$display("[%t] Wishbone bus write addr %x data %x",$realtime,wb_m2s_addr, wb_m2s_data );
		wb_m2s_we                <=  1'b0;
		wb_m2s_cyc               <=  1'b0;
		wb_m2s_stb               <=  1'b0; 
  endtask // while


 
