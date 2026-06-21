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
/* Idea B: the host sends RAW ASCII; each 16-base sequence is 4 words of 4    */
/* ASCII bytes, and the accelerator decodes them in hardware.  No software    */
/* encoding is performed at all.                                              */
#define ACCEL_REG_CONTROL   0x80001300u   /* w: bit0=GO   r: bit31=DONE        */
#define ACCEL_REG_QUERY0    0x80001304u   /* query ASCII bytes 0..3            */
#define ACCEL_REG_REF0      0x80001314u   /* ref   ASCII bytes 0..3            */
#define ACCEL_REG_RESULT    0x80001324u   /* best local-alignment score        */
/* QUERYg = QUERY0 + 4*g , REFg = REF0 + 4*g  (g = 0..3); REF3 write auto-starts */

#define ACCEL_DONE_BIT      0x80000000u

#define ACCEL_RD(addr)        (*(volatile unsigned *)(addr))
#define ACCEL_WR(addr, value) do { (*(volatile unsigned *)(addr)) = (unsigned)(value); } while (0)

/* Send a 16-byte sequence as 4 raw-ASCII words to consecutive registers.     */
/* The sequence stays in its TCM array; we only move the bytes (no encoding). */
/* Reads are 4-byte aligned (the query/reference arrays are aligned(4)), so    */
/* these are plain word loads.  Writing the 4th REF word auto-starts the run.  */
static inline void accel_send4(unsigned base_addr, const char *seq)
{
    const unsigned *w = (const unsigned *)seq;
    ACCEL_WR(base_addr + 0x0u, w[0]);
    ACCEL_WR(base_addr + 0x4u, w[1]);
    ACCEL_WR(base_addr + 0x8u, w[2]);
    ACCEL_WR(base_addr + 0xCu, w[3]);
}

/* Offload one reference to the accelerator and return its score.            */
/* The query is loaded once by the caller (it is stationary in the array).   */
static inline int smith_waterman_accel(const char *ref)
{
    accel_send4(ACCEL_REG_REF0, ref);        /* 4 raw words; REF3 auto-starts  */

    /* polling DONE is required: accelerator_wb acks a read in ~4 cycles while */
    /* the systolic run takes longer, so an immediate read would be partial.  */
    while ((ACCEL_RD(ACCEL_REG_CONTROL) & ACCEL_DONE_BIT) == 0)
        ;

    return (int)ACCEL_RD(ACCEL_REG_RESULT);
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
    /* Load the stationary query once (4 raw words), then stream each         */
    /* reference through the systolic accelerator.                            */
    accel_send4(ACCEL_REG_QUERY0, query);

    for(int i=0;i<NUM_OF_REFS;i++)
    {
        score[i] = smith_waterman_accel(references[i]);
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
