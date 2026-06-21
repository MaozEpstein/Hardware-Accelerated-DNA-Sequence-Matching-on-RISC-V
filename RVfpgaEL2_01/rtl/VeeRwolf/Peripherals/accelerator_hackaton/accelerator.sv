// ------------------------------------------------------------------------
//  accelerator.sv  -  DNA Smith-Waterman (Affine-Gap) systolic accelerator
//
//  Hackathon - VLSI / RISC-V (HUJI).  Based on the preparation-exercise-2
//  accelerator skeleton (Alex Grinshpun 2023); the dot-product core has been
//  replaced by a query-stationary systolic Smith-Waterman engine.
//  Provided AS IS without any warranty of any kind.
//
//  Layer 1 of the staged plan: pure compute core, same module ports as the
//  original so accelerator_top.sv / accelerator_wb.sv stay unchanged.
//
//  Register meaning (set by accelerator_regs.sv):
//      reg_a  = query_packed   : 16 query bases, 2 bits each  (loaded once)
//      reg_b  = ref_packed     : 16 reference bases, 2 bits each
//      go     = start a run    ; done = result ready ; reg_result = best score
//      reg_c / reg_d           : reserved (future: parallel references)
//
//  Algorithm (matches dna_match.c exactly), W-bit signed saturating math:
//      s      = (q==r) ? +2 : -1
//      I(i,j) = max( M(i-1,j)+GAP_OPEN , I(i-1,j)+GAP_EXT )      // up
//      D(i,j) = max( M(i,j-1)+GAP_OPEN , D(i,j-1)+GAP_EXT )      // left
//      M(i,j) = max( 0, M(i-1,j-1)+s , I(i,j) , D(i,j) )         // diag
//      score  = max over all M
//
//  No multipliers (only add/max) -> 0 DSPs.  No block RAM.
//  2-bit base encoding: A=00, C=01, G=10, T=11.  Verified in Python that
//  W>=6 reproduces the reference scores; W=8 chosen for safe margin.
// ------------------------------------------------------------------------

// ===================== single Processing Element =========================
module sw_pe #(
    parameter int W = 8
) (
    input  logic                clk,
    input  logic                rst,          // synchronous, active high
    input  logic [1:0]          q_base,       // stationary query base
    input  logic                in_valid,     // cell from row above valid now
    input  logic [1:0]          in_ref,       // reference base for this column
    input  logic signed [W-1:0] up_m,         // M(i-1,j)
    input  logic signed [W-1:0] up_i,         // I(i-1,j)
    output logic                out_valid,
    output logic [1:0]          out_ref,
    output logic signed [W-1:0] out_m,        // M(i,j)
    output logic signed [W-1:0] out_i,        // I(i,j)
    output logic                cell_valid,
    output logic signed [W-1:0] cell_m        // M(i,j) just produced
);
    localparam signed [W-1:0] MATCH    =  2;
    localparam signed [W-1:0] MISMATCH = -1;
    localparam signed [W-1:0] GAP_OPEN = -4;
    localparam signed [W-1:0] GAP_EXT  = -1;
    localparam signed [W-1:0] NEG_INF  = -(1 <<< (W-1));  // saturating sentinel

    // saturating signed add (2 guard bits, clamp to W-bit range)
    function automatic signed [W-1:0] sadd(input signed [W-1:0] a,
                                           input signed [W-1:0] b);
        logic signed [W+1:0] t;
        logic signed [W+1:0] hi, lo;
        begin
            t  = $signed({a[W-1], a}) + $signed({b[W-1], b});
            hi = (1 <<< (W-1)) - 1;     //  +max =  2^(W-1)-1
            lo = -(1 <<< (W-1));        //  -min = -2^(W-1)  (== NEG_INF)
            if      (t > hi) sadd = hi[W-1:0];
            else if (t < lo) sadd = lo[W-1:0];
            else             sadd = t[W-1:0];
        end
    endfunction

    function automatic signed [W-1:0] max2(input signed [W-1:0] a,
                                           input signed [W-1:0] b);
        max2 = (a > b) ? a : b;
    endfunction

    logic signed [W-1:0] m_reg;    // M(i,j-1) "left" (= output M)
    logic signed [W-1:0] i_reg;    // I(i,j)        (= output I)
    logic signed [W-1:0] d_reg;    // D(i,j-1) "left"
    logic signed [W-1:0] diag_reg; // M(i-1,j-1) "diag"

    logic signed [W-1:0] s_score, new_i, new_d, new_m;
    always_comb begin
        s_score = (q_base == in_ref) ? MATCH : MISMATCH;
        new_i   = max2(sadd(up_m,  GAP_OPEN), sadd(up_i,  GAP_EXT));
        new_d   = max2(sadd(m_reg, GAP_OPEN), sadd(d_reg, GAP_EXT));
        new_m   = max2(max2('0, sadd(diag_reg, s_score)), max2(new_i, new_d));
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            m_reg <= '0; i_reg <= NEG_INF; d_reg <= NEG_INF; diag_reg <= '0;
            out_ref <= 2'b00; out_valid <= 1'b0; cell_valid <= 1'b0; cell_m <= '0;
        end else begin
            if (in_valid) begin
                diag_reg <= up_m;     // becomes diag for the next column
                m_reg    <= new_m;
                i_reg    <= new_i;
                d_reg    <= new_d;
            end
            out_ref    <= in_ref;
            out_valid  <= in_valid;
            cell_valid <= in_valid;
            cell_m     <= new_m;
        end
    end

    assign out_m = m_reg;
    assign out_i = i_reg;
endmodule


// ========================= accelerator core ==============================
module accelerator
(
    input   logic                 clk,
    input   logic                 wb_rst_i,
    input   logic unsigned [31:0] reg_a,    // query_packed
    input   logic unsigned [31:0] reg_b,    // ref_packed
    input   logic unsigned [31:0] reg_c,    // reserved
    input   logic unsigned [31:0] reg_d,    // reserved
    input   logic                 go,
    output  logic                 done,
    output  logic unsigned [31:0] reg_result
);
    localparam int W      = 8;     // datapath width (signed)
    localparam int QLEN   = 16;    // query length (= number of PEs)
    localparam int REFLEN = 16;    // reference length
    localparam int RUN_CYCLES = QLEN + REFLEN + 2;
    localparam int CW = $clog2(RUN_CYCLES + 1);
    localparam signed [W-1:0] NEG_INF = -(1 <<< (W-1));

    // keep reserved inputs from being optimization-pruned warnings
    wire _unused = &{1'b0, reg_c, reg_d};

    // synchronous, active-high reset for the internal logic
    logic rst;
    assign rst = wb_rst_i;

    // ---- stationary query bases ------------------------------------------
    logic [1:0] q_base [0:QLEN-1];
    genvar gi;
    generate
        for (gi = 0; gi < QLEN; gi++) begin : g_qbase
            assign q_base[gi] = reg_a[2*gi +: 2];
        end
    endgenerate

    // ---- control FSM (triggered by a rising edge of go) ------------------
    typedef enum logic [1:0] {S_IDLE, S_CLR, S_RUN, S_DONE} state_t;
    state_t        state;
    logic [CW-1:0] cyc;
    logic          go_d;
    logic          clr_pes;
    logic          start_pulse;

    assign start_pulse = go & ~go_d;          // rising edge of go
    assign clr_pes     = (state == S_CLR);

    // stream of reference bases into PE0 during S_RUN
    logic        feed_valid;
    logic [1:0]  feed_ref;
    assign feed_valid = (state == S_RUN) && (cyc < REFLEN);
    assign feed_ref   = reg_b[2*cyc[3:0] +: 2];

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            cyc   <= '0;
            go_d  <= 1'b0;
            done  <= 1'b0;
        end else begin
            go_d <= go;
            case (state)
                S_IDLE: begin
                    if (start_pulse) begin
                        done  <= 1'b0;     // clear previous result flag
                        cyc   <= '0;
                        state <= S_CLR;
                    end
                end
                S_CLR: begin
                    cyc   <= '0;
                    state <= S_RUN;
                end
                S_RUN: begin
                    if (cyc == RUN_CYCLES-1)
                        state <= S_DONE;
                    else
                        cyc <= cyc + 1'b1;
                end
                S_DONE: begin
                    done  <= 1'b1;         // held high until the next run starts
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    // ---- PE chain ---------------------------------------------------------
    logic                pe_valid [0:QLEN-1];
    logic [1:0]          pe_ref   [0:QLEN-1];
    logic signed [W-1:0] pe_m     [0:QLEN-1];
    logic signed [W-1:0] pe_i     [0:QLEN-1];
    logic                pe_cv    [0:QLEN-1];
    logic signed [W-1:0] pe_cm    [0:QLEN-1];

    logic pe_rst;
    assign pe_rst = rst | clr_pes;

    generate
        for (gi = 0; gi < QLEN; gi++) begin : g_pe
            if (gi == 0) begin : g_head
                sw_pe #(.W(W)) u_pe (
                    .clk(clk), .rst(pe_rst),
                    .q_base   (q_base[0]),
                    .in_valid (feed_valid),
                    .in_ref   (feed_ref),
                    .up_m     ({W{1'b0}}),     // row-0 boundary M(0,j)=0
                    .up_i     (NEG_INF),       // row-0 boundary I(0,j)=NEG_INF
                    .out_valid(pe_valid[0]), .out_ref(pe_ref[0]),
                    .out_m(pe_m[0]), .out_i(pe_i[0]),
                    .cell_valid(pe_cv[0]), .cell_m(pe_cm[0])
                );
            end else begin : g_body
                sw_pe #(.W(W)) u_pe (
                    .clk(clk), .rst(pe_rst),
                    .q_base   (q_base[gi]),
                    .in_valid (pe_valid[gi-1]),
                    .in_ref   (pe_ref[gi-1]),
                    .up_m     (pe_m[gi-1]),
                    .up_i     (pe_i[gi-1]),
                    .out_valid(pe_valid[gi]), .out_ref(pe_ref[gi]),
                    .out_m(pe_m[gi]), .out_i(pe_i[gi]),
                    .cell_valid(pe_cv[gi]), .cell_m(pe_cm[gi])
                );
            end
        end
    endgenerate

    // ---- global maximum reduction (M is always >= 0) ---------------------
    logic signed [W-1:0] cyc_max;
    integer k;
    always_comb begin
        cyc_max = '0;
        for (k = 0; k < QLEN; k++)
            if (pe_cv[k] && (pe_cm[k] > cyc_max))
                cyc_max = pe_cm[k];
    end

    logic signed [W-1:0] best_reg;
    always_ff @(posedge clk) begin
        if (rst || clr_pes)
            best_reg <= '0;
        else if (state == S_RUN && cyc_max > best_reg)
            best_reg <= cyc_max;
    end

    assign reg_result = {{(32-W){best_reg[W-1]}}, best_reg};  // sign-extend
endmodule
