#if defined(D_NEXYS_A7)
   #include <bsp_printf.h>
   #include <bsp_mem_map.h>
   #include <bsp_version.h>
   #include <stdint.h>
#else
   PRE_COMPILED_MSG("no platform was defined")
#endif
#include <psp_api.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#define ACCELERATOR_REG_CONTROL	    0x80001300	//
#define ACCELERATOR_REG_A		    0x80001304	// 
#define ACCELERATOR_REG_B		    0x80001308	// 
#define ACCELERATOR_REG_C		    0x8000130C	//
#define ACCELERATOR_REG_D		    0x80001310	//
#define ACCELERATOR_REG_RESULT		0x80001314	//
#define GO_BIT                      0x00000001  //
#define DONE_BIT                    0x80000000  // 

#define READ_GPIO(dir) (*(volatile unsigned *)dir)
#define WRITE_GPIO(dir, value) { (*(volatile unsigned *)dir) = (value); }

//#define VIVADO_SIMULATOR

static const uint8_t A[8][8] = {
    { 53, 24, 92, 10, 49, 99, 15, 72},
    { 30, 69, 88, 77, 45, 65, 16, 81},
    { 24,  6, 55, 26, 31, 48, 37, 12},
    {  4, 71, 98, 82, 59, 39, 79, 97},
    { 96, 40, 14, 95, 50, 29, 66, 17},
    {  2, 94, 33, 61, 91, 88, 78, 54},
    { 60, 35, 73, 62, 57, 18, 47, 85},
    { 20, 11, 21, 83, 38, 44, 64, 91}
};

static const uint8_t B[8][8] = {
    { 30, 66, 84, 88, 13, 49, 19, 93},
    { 28, 31, 67, 14, 79, 17, 27, 45},
    { 50, 56, 47, 24, 34, 57, 70, 82},
    {  8, 60, 54, 76, 80, 33, 40, 95},
    {  4, 75, 22, 29, 59, 41, 64, 29},
    { 95, 12, 71, 53, 14, 38, 22, 16},
    {  7, 37, 68, 41, 61, 12, 58, 55},
    { 99, 65, 25, 20, 46, 91, 32, 68}
};

static uint32_t result[8][8];

int main ( void )
{
   int cyc_beg, cyc_end;

//#ifndef VIVADO_SIMULATOR

   pspMachinePerfMonitorEnableAll();

   pspMachinePerfCounterSet(D_PSP_COUNTER0, D_CYCLES_CLOCKS_ACTIVE);
   cyc_beg = pspMachinePerfCounterGet(D_PSP_COUNTER0);

//#endif

   for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
         // 1. Build the row vector from matrix A (row i), packed as 4 bytes per uint32
         uint32_t a_low  = (uint32_t)A[i][0]       | ((uint32_t)A[i][1] << 8)
                         | ((uint32_t)A[i][2] << 16) | ((uint32_t)A[i][3] << 24);
         uint32_t a_high = (uint32_t)A[i][4]       | ((uint32_t)A[i][5] << 8)
                         | ((uint32_t)A[i][6] << 16) | ((uint32_t)A[i][7] << 24);

         // 2. Build the column vector from matrix B (column j)
         uint32_t b_low  = (uint32_t)B[0][j]       | ((uint32_t)B[1][j] << 8)
                         | ((uint32_t)B[2][j] << 16) | ((uint32_t)B[3][j] << 24);
         uint32_t b_high = (uint32_t)B[4][j]       | ((uint32_t)B[5][j] << 8)
                         | ((uint32_t)B[6][j] << 16) | ((uint32_t)B[7][j] << 24);

         // 3. Write the four accelerator inputs
         WRITE_GPIO(ACCELERATOR_REG_A, a_low);
         WRITE_GPIO(ACCELERATOR_REG_B, b_low);
         WRITE_GPIO(ACCELERATOR_REG_C, a_high);
         WRITE_GPIO(ACCELERATOR_REG_D, b_high);

         // 4. Trigger the accelerator
         WRITE_GPIO(ACCELERATOR_REG_CONTROL, GO_BIT);

         // 5. Wait until Done bit is set
         //while ((READ_GPIO(ACCELERATOR_REG_CONTROL) & DONE_BIT) == 0);

         // 6. Read the result into the result matrix
         result[i][j] = READ_GPIO(ACCELERATOR_REG_RESULT);
      }
   }

#ifndef VIVADO_SIMULATOR
   cyc_end = pspMachinePerfCounterGet(D_PSP_COUNTER0);

   // 7. Print the result matrix
   for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
         printf("%5u ", result[i][j]);
      }
      printf("\n");
   }

   printf("Cycles = %d\n", cyc_end - cyc_beg);
#endif

   return(0);
}