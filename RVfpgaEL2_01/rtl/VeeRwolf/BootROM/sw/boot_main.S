#define SegEn_ADDR    	0x80001038
#define SegDig_ADDR   	0x8000103C
#define SegEn_ADDR    	0x80001038
#define SegLo_ADDR   	0x8000103C
#define SegUp_ADDR   	0x80001014
#define SegCharEn_ADDR   	0x80001004
#define VERSION_MSB_ADDR  	0x80001024
#define VERSION_LSB_ADDR  	0x80001010
#define GPIO_SWs    	0x80001400
#define GPIO_LEDs   	0x80001404
#define GPIO_INOUT  	0x80001408
#define OUTPRINT  	0xE2002023


#define DELAY   	0xFFFF
//#define DELAY   	0x2

//#define  SegCharEn      0x10FF // enable ASCII mode && Blink 4th character
#define  SegCharEn      0x04FF // enable ASCII mode && Blink 6th character
.globl _start
_start:


li t0, SegCharEn_ADDR
li t3, SegCharEn
sw t3, 0(t0)

li t0, SegLo_ADDR
li t1, SegUp_ADDR

li t3, VERSION_LSB_ADDR
lw t3, 0(t3)
sw t3, 0(t0)

li t3, VERSION_MSB_ADDR
lw t3, 0(t3)
sw t3, 0(t1)

//lw t3, Message
//sw t3, 0(t1)
//lw t3, Message + 4
//sw t3, 0(t0)
li t0, SegEn_ADDR
li t3, 0x55
sb t3, 0(t0)					# Enable the 7SegDisplays

li t1, GPIO_INOUT
li t2, 0xFFFF
sw t2, 0(t1)                  	# Write the GPIO Enable Register
li t1, GPIO_LEDs
li t2, 0x5555

li t4, 0xFFFF
li t6, 0x4

next:
	beq t6, zero, GoOut
	add t6, t6, -1

	li t5, DELAY				# Initialize delay

        sw t2, 0(t1)          # Write the LEDs
        xor t2, t2, t4				# Invert LEDs

        sw t3, 0(t0)				  # Write the 7SegDisplays
        xor t3, t3, t4				# Invert the 7SegDisplays

  delay:
    	beq t5, zero, next
    	addi t5, t5, -1
    	j delay

GoOut:

li t3, VERSION_LSB_ADDR
lw t3, 0(t3)
sw t3, 0(t0)

li t3, VERSION_MSB_ADDR
lw t3, 0(t3)
sw t3, 0(t1)

//lw t3, Message
//sw t3, 0(t1)
//lw t3, Message + 4
//sw t3, 0(t0)

li t0, SegEn_ADDR
li t3, 0x0
sb t3, 0(t0)					# Enable the 7SegDisplays

li t1, GPIO_LEDs
li t2, 0x0
sw t2, 0(t1)          # Write the LEDs

j .
.section .rodata
Message: .ascii "EL2-0223"
.end
