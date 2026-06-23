// SPDX-License-Identifier: Apache-2.0
// Copyright 2019-2020 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//********************************************************************************
// $Id$
//
// Function: VeeRwolf SoC-level controller
// Comments:
//
//********************************************************************************
// Alex Grinshpun 2023 .Pure SystemVerilog version and display Letters + Digits
// Provided AS IS without any warranty of any kind nor EXPLICIT nor IMPLIED

module SevenSegDecoder(
						input	logic			CharEn,
						input	logic	[7:0]	CharLetter,
						input	logic	[3:0]	data,
						output	logic	[6:0]	seg
					   );
logic	[6:0]	seg1;
  always_comb	  //Alex Grinshpun
	if (!CharEn)	begin
		case(data)
						    // abc_defg            
			4'h0:   seg1 =   7'b111_1110;
			4'h1:   seg1 =   7'b011_0000;
			4'h2:   seg1 =   7'b110_1101;
			4'h3:   seg1 =   7'b111_1001;
			4'h4:   seg1 =   7'b011_0011;
			4'h5:   seg1 =   7'b101_1011;
			4'h6:   seg1 =   7'b101_1111;
			4'h7:   seg1 =   7'b111_0000;
			4'h8:   seg1 =   7'b111_1111;
			4'h9:   seg1 =   7'b111_0011;
			4'ha:   seg1 =   7'b111_0111;
			4'hb:   seg1 =   7'b001_1111;
			4'hc:   seg1 =   7'b000_1101;
			4'hd:   seg1 =   7'b011_1101;
			4'he:   seg1 =   7'b100_1111;
			4'hf:   seg1 =   7'b100_0111;
			default: 
					seg1 = 7'b000_0000;
			endcase
	end
	else	begin //Alex Grinshpun
/*
https://en.wikichip.org/wiki/seven-segment_display/representing_letters
Digit	7-Segments				abcdefg	gfedcba	Display	Reference
	abc_defg
A	111_0111	0x77	0x77	A	7 segment display labeled.svg
a	111_1101	0x7D	0x5F	a
b	001_1111	0x1F	0x7C	b
C	100_1110	0x4E	0x39	C
c	000_1101	0x0D	0x58	c
d	011_1101	0x3D	0x5E	d
E	100_1111	0x4F	0x79	E
F	100_0111	0x47	0x71	F
G	101_1110	0x5E	0x3D	G
H	011_0111	0x37	0x76	H
h	001_0111	0x17	0x74	h
I	000_0110	0x06	0x30	I
J	011_1100	0x3C	0x1E	J*
L	000_1110	0x0E	0x38	L
n	001_0101	0x15	0x54	n
O	111_1110	0x7E	0x3F	O
o	001_1101	0x1D	0x5C	o
P	110_0111	0x67	0x73	P
q	111_0011	0x73	0x67	q
r	000_0101	0x05	0x50	r
S	101_1011	0x5B	0x6D	S
t	000_1111	0x0F	0x78	t
U	011_1110	0x3E	0x3E	U
u	001_1100	0x1C	0x1C	u
y	011_1011	0x3B	0x6E	y
*/
		case(CharLetter)
						    // abc_defg
			8'h30:   seg1 =   7'b111_1110;
			8'h31:   seg1 =   7'b011_0000;
			8'h32:   seg1 =   7'b110_1101;
			8'h33:   seg1 =   7'b111_1001;
			8'h34:   seg1 =   7'b011_0011;
			8'h35:   seg1 =   7'b101_1011;
			8'h36:   seg1 =   7'b101_1111;
			8'h37:   seg1 =   7'b111_0000;
			8'h38:   seg1 =   7'b111_1111;
			8'h39:   seg1 =   7'b111_0011;
			8'h3a:   seg1 =   7'b111_0111;
			8'h3b:   seg1 =   7'b001_1111;
			8'h3c:   seg1 =   7'b000_1101;
			8'h3d:   seg1 =   7'b011_1101;
			8'h3e:   seg1 =   7'b100_1111;
			8'h3f:   seg1 =   7'b100_0111;
			8'h2d:   seg1 =   7'b000_0001; //-
			8'h41:   seg1 =   7'b111_0111; //A
			8'h61:   seg1 =   7'b111_1101; //a
			8'h62:   seg1 =   7'b001_1111; //b
			8'h43:   seg1 =   7'b100_1110; //C
			8'h63:   seg1 =   7'b000_1101; //c
			8'h64:   seg1 =   7'b011_1101; //d
			8'h45:   seg1 =   7'b100_1111; //E
			8'h46:   seg1 =   7'b100_0111; //F
			8'h47:   seg1 =   7'b101_1110; //G
			8'h48:   seg1 =   7'b011_0111; //H
			8'h68:   seg1 =   7'b001_0111; //h
			8'h49:   seg1 =   7'b000_0110; //I
			8'h4A:   seg1 =   7'b011_1100; //J
			8'h4C:   seg1 =   7'b000_1110; //L
			8'h6E:   seg1 =   7'b001_0101; //n
			8'h4F:   seg1 =   7'b111_1110; //O
			8'h6F:   seg1 =   7'b001_1101; //o
			8'h50:   seg1 =   7'b110_0111; //P
			8'h71:   seg1 =   7'b111_0011; //q
			8'h72:   seg1 =   7'b000_0101; //r
			8'h53:   seg1 =   7'b101_1011; //S
			8'h74:   seg1 =   7'b000_1111; //t
            8'h55:   seg1 =   7'b011_1110; //U
            8'h75:   seg1 =   7'b001_1100; //u
            8'h79:   seg1 =   7'b011_1011; //y
			default:                     
					seg1 = 7'b000_0000;   
			endcase                      
	end                                  
	assign seg = ~seg1;	                                 
endmodule                                
