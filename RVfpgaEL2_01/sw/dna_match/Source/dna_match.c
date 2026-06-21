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

/* Memory-mapped registers (base 0x80001300, matches accelerator_regs.sv).  */
#define ACCEL_REG_CONTROL   0x80001300u   /* w: bit0=GO   r: bit31=DONE       */
#define ACCEL_REG_QUERY     0x80001304u   /* reg_a: 16 query bases, 2b each   */
#define ACCEL_REG_REF       0x80001308u   /* reg_b: 16 ref   bases, 2b each   */
#define ACCEL_REG_RESULT    0x80001314u   /* best local-alignment score       */

#define ACCEL_DONE_BIT      0x80000000u

#define ACCEL_RD(addr)        (*(volatile unsigned *)(addr))
#define ACCEL_WR(addr, value) do { (*(volatile unsigned *)(addr)) = (unsigned)(value); } while (0)

/* Pack a DNA string into 2 bits per base; base k occupies bits [2k +: 2],    */
/* up to 16 bases per 32-bit word.  The input sequences stay in the TCM array;*/
/* only their encoding is built.                                              */
/*                                                                            */
/* Branchless mapping: (c >> 1) & 3 sends A/C/G/T -> 0/1/3/2.  This replaces a */
/* 4-way switch (the dominant ~86% of run time at -O0).  The mapping value is  */
/* irrelevant: the accelerator's PE only tests query==reference for equality,  */
/* so ANY bijection gives identical match/mismatch decisions and identical     */
/* scores - as long as query and references use this same encoder.             */
static inline unsigned dna_encode(const char *s)
{
    unsigned packed = 0;

    for (int k = 0; s[k] != '\0'; k++)
        packed |= (unsigned)((s[k] >> 1) & 3) << (2 * k);

    return packed;
}

/* Offload one reference to the accelerator and return its score.           */
/* The query is loaded once by the caller (it is stationary in the array).  */
static inline int smith_waterman_accel(const char *ref)
{
    /* Layer 3.1 (auto-start): writing the reference register launches the run */
    /* automatically, so the separate CONTROL/GO write is no longer needed.    */
    /*                                                                         */
    /* NOTE: polling DONE is required.  accelerator_wb acks a read in ~4 cycles */
    /* and reg_result is read combinationally, so reading without polling would */
    /* return a partial (mid-computation) score.  Layer 3.2 (poll-free) was     */
    /* reverted for this reason.                                                */
    ACCEL_WR(ACCEL_REG_REF, dna_encode(ref));    /* write ref -> auto-start    */

    while ((ACCEL_RD(ACCEL_REG_CONTROL) & ACCEL_DONE_BIT) == 0)
        ;                                        /* poll until DONE            */

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
    const char *query =
        "ACGTCGTACGTACGTA";

    int score[NUM_OF_REFS]; 

    const char *references[] =
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
    /* Load the stationary query once, then stream each reference through    */
    /* the systolic accelerator.  query/references stay in the TCM arrays.   */
    ACCEL_WR(ACCEL_REG_QUERY, dna_encode(query));

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
