#if defined(D_NEXYS_A7)
   #include <bsp_printf.h>
   #include <bsp_mem_map.h>
   #include <bsp_version.h>
#else
   PRE_COMPILED_MSG("no platform was defined")
#endif
#include <psp_api.h>

#include <stdio.h>
#include <string.h>

#define MATCH       2
#define MISMATCH   -1

#define GAP_OPEN   -4
#define GAP_EXT    -1

#define MAX_LEN   32

#define NEG_INF  (-1000000)

#define NUM_OF_REFS 8

/* ======================================================================== */
/*  Hardware accelerator interface (DNA Smith-Waterman systolic engine)     */
/*                                                                          */
/*  Define USE_ACCELERATOR to offload the scoring to the FPGA accelerator.  */
/*  Comment it out to fall back to the pure-software reference below        */
/*  (identical results -> useful as a cross-check / safe rollback).         */
/* ======================================================================== */
#define USE_ACCELERATOR

#ifdef USE_ACCELERATOR

/* Memory-mapped registers (base 0x80001300, matches accelerator_regs.sv).   */
/* The host sends RAW ASCII (4 words/sequence, decoded in hardware).  There   */
/* are TWO reference buffers (A/B) so the CPU can write the next reference     */
/* while the core computes the current one (double-buffer / ping-pong).        */
#define ACCEL_REG_CONTROL   0x80001300u   /* r: {busy, .., done_b, done_a}     */
#define ACCEL_REG_QUERY0    0x80001304u   /* query ASCII bytes 0..3            */
#define ACCEL_REG_REFA0     0x80001314u   /* buffer A: ref ASCII bytes 0..3    */
#define ACCEL_REG_REFB0     0x80001324u   /* buffer B: ref ASCII bytes 0..3    */
#define ACCEL_REG_RESULTA   0x80001334u   /* score of the last run on buffer A */
#define ACCEL_REG_RESULTB   0x80001338u   /* score of the last run on buffer B */
/* REGg = REG0 + 4*g (g=0..3).  Writing word 3 of a buffer queues a run on it. */

#define ACCEL_DONE_A        0x00000001u
#define ACCEL_DONE_B        0x00000002u

#define ACCEL_RD(addr)        (*(volatile unsigned *)(addr))
#define ACCEL_WR(addr, value) do { (*(volatile unsigned *)(addr)) = (unsigned)(value); } while (0)

/* Send a 16-byte sequence as 4 raw-ASCII words to a buffer's registers.      */
/* The sequence stays in its TCM array; we only move the bytes (no encoding). */
/* Reads are 4-byte aligned (the query/reference arrays are aligned(4)).      */
/* Writing the 4th word queues a run on that buffer.                          */
static inline void accel_send4(unsigned base_addr, const char *seq)
{
    const unsigned *w = (const unsigned *)seq;
    ACCEL_WR(base_addr + 0x0u, w[0]);
    ACCEL_WR(base_addr + 0x4u, w[1]);
    ACCEL_WR(base_addr + 0x8u, w[2]);
    ACCEL_WR(base_addr + 0xCu, w[3]);
}

#endif /* USE_ACCELERATOR */

static int M[MAX_LEN][MAX_LEN];
static int I[MAX_LEN][MAX_LEN];
static int D[MAX_LEN][MAX_LEN];

static inline int max2(int a, int b)
{
    return (a > b) ? a : b;
}

static inline int max4(int a,int b,int c,int d)
{
    int m = a;

    if(b > m) m = b;
    if(c > m) m = c;
    if(d > m) m = d;

    return m;
}

int smith_waterman_affine(
        const char *ref,
        const char *query)
{
    int rows = strlen(query) + 1;
    int cols = strlen(ref) + 1;

    int best_score = 0;

    for(int i=0;i<rows;i++)
    {
        for(int j=0;j<cols;j++)
        {
            M[i][j] = 0;
            I[i][j] = NEG_INF;
            D[i][j] = NEG_INF;
        }
    }

    for(int i=1;i<rows;i++)
    {
        for(int j=1;j<cols;j++)
        {
            int s;

            if(query[i-1] == ref[j-1])
                s = MATCH;
            else
                s = MISMATCH;

            /* -------------------------- */
            /* Insertion matrix           */
            /* -------------------------- */

            I[i][j] =
                max2(
                    M[i-1][j] + GAP_OPEN,
                    I[i-1][j] + GAP_EXT);

            /* -------------------------- */
            /* Deletion matrix            */
            /* -------------------------- */

            D[i][j] =
                max2(
                    M[i][j-1] + GAP_OPEN,
                    D[i][j-1] + GAP_EXT);

            /* -------------------------- */
            /* Match matrix               */
            /* -------------------------- */

            M[i][j] =
                max4(
                    0,
                    M[i-1][j-1] + s,
                    I[i][j],
                    D[i][j]);

            if(M[i][j] > best_score)
                best_score = M[i][j];
        }
    }

    return best_score;
}

int main(void)
{
    /* aligned(4) so the accelerator driver can move each sequence as 4 raw    */
    /* 32-bit words (the input stays in these TCM arrays - no encoding).        */
    static const char query[20] __attribute__((aligned(4))) =
        "ACGTCGTACGTACGTA";

    int score[NUM_OF_REFS];

    static const char references[NUM_OF_REFS][20] __attribute__((aligned(4))) =
    {
        "ACGTACGTACGTACGT",
        "ACGTTCGTACGTACGT",
        "ACGTACGGACGTACGT",
        "TTTTTTTTTTTTTTTT",
        "ACGTACGTTCGTACGT",
        "ACGTACGTACGTACGA",
        "ACGTTTGTACGTACGT",
        "ACGTACGTGCGTACGT"
    };


    // read time here
   int cyc_beg, cyc_end;

   pspMachinePerfMonitorEnableAll();
   pspMachinePerfCounterSet(D_PSP_COUNTER0, D_CYCLES_CLOCKS_ACTIVE);
   cyc_beg = pspMachinePerfCounterGet(D_PSP_COUNTER0);


#ifdef USE_ACCELERATOR
    /* Double-buffer pipeline: load the query once, prime buffer A with the    */
    /* first reference, then for each reference write the NEXT one into the     */
    /* opposite buffer (which overlaps the current run and provides the delay   */
    /* that makes the poll-free result read safe) and read the current score.   */
    /* Only the last reference - which has no following prefetch - is polled.   */
    accel_send4(ACCEL_REG_QUERY0, query);
    accel_send4(ACCEL_REG_REFA0, references[0]);     /* queue run 0 on buffer A */

    for(int i=0;i<NUM_OF_REFS;i++)
    {
        if(i+1 < NUM_OF_REFS)
            accel_send4(((i+1) & 1) ? ACCEL_REG_REFB0 : ACCEL_REG_REFA0,
                        references[i+1]);
        else
            while((ACCEL_RD(ACCEL_REG_CONTROL)
                   & ((i & 1) ? ACCEL_DONE_B : ACCEL_DONE_A)) == 0)
                ;                                    /* poll only the last one  */

        score[i] = (int)ACCEL_RD((i & 1) ? ACCEL_REG_RESULTB
                                         : ACCEL_REG_RESULTA);
    }
#else
    for(int i=0;i<NUM_OF_REFS;i++)
    {
        score[i] =
            smith_waterman_affine(
                references[i],
                query);

    }
#endif


    // read timer here and print execution time
   cyc_end = pspMachinePerfCounterGet(D_PSP_COUNTER0);

   printf("Cycles = %d\n", cyc_end-cyc_beg);

    for(int i=0;i<NUM_OF_REFS;i++)
    {
        printf(
            "Reference %d score = %d\n",
            i,
            score[i]);
    }

    return 0;
}
