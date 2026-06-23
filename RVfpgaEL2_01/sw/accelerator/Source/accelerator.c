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
#include <ctype.h>
#include <stdlib.h>

#define ACCELERATOR_REG_A		0x80001300	// 
#define ACCELERATOR_REG_B		0x80001304	// 
#define ACCELERATOR_REG_RESULT		0x80001308	// 
#define  ACCELERATOR_REG_STATUS		0x8000130C	// 

#define READ_GPIO(dir) (*(volatile unsigned *)dir)
#define WRITE_GPIO(dir, value) { (*(volatile unsigned *)dir) = (value); }

//#define VIVADO_SIMULATOR

int main ( void )
{
   int reg_a_value, reg_b_value, reg_result_value,reg_status_value;
   int cyc_beg, cyc_end;
   int instr_beg, instr_end;
   int BrCom_beg, BrCom_end;
   int BrMis_beg, BrMis_end;

    int A = 1;
    int B = 2;

//#ifndef VIVADO_SIMULATOR

   pspMachinePerfMonitorEnableAll();

   pspMachinePerfCounterSet(D_PSP_COUNTER0, D_CYCLES_CLOCKS_ACTIVE);
   cyc_beg = pspMachinePerfCounterGet(D_PSP_COUNTER0);

//#endif

   for (int i=0; i < 10; i++) {
      WRITE_GPIO(ACCELERATOR_REG_A, A);
      WRITE_GPIO(ACCELERATOR_REG_B, B);

      reg_a_value = READ_GPIO(ACCELERATOR_REG_A);
      reg_b_value = READ_GPIO(ACCELERATOR_REG_B);
      reg_result_value = READ_GPIO(ACCELERATOR_REG_RESULT);
      reg_status_value = READ_GPIO(ACCELERATOR_REG_STATUS);
#ifndef VIVADO_SIMULATOR
      printf("***************\n");
      printf("A %d\n",A);
      printf("B %d\n",B);
      printf("reg_result_value %d\n",reg_result_value);
      printf("reg_status_value %d\n",reg_status_value);
#endif
      A = A + 2;
      B = B + 3;
   }   

#ifndef VIVADO_SIMULATOR   
   cyc_end = pspMachinePerfCounterGet(D_PSP_COUNTER0);

   printf("Cycles = %d", cyc_end-cyc_beg);

#endif 
    return(0);
}