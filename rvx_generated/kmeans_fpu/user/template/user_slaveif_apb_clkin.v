// ****************************************************************************
// ****************************************************************************
// Copyright SoC Design Research Group, All rights reserved.
// Electronics and Telecommunications Research Institute (ETRI)
// 
// THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE
// WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS
// TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE
// REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL
// SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE,
// IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE
// COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
// ****************************************************************************
// 2026-06-20
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************


module USER_SLAVEIF_APB_CLKIN
(
	clk,
	rstnn,
	rpsel,
	rpenable,
	rpwrite,
	rpaddr,
	rpwdata,
	rpready,
	rprdata,
	rpslverr
);

parameter SIZE_OF_MEMORYMAP = 1;
parameter BW_ADDR = 1;
parameter BW_DATA = 1;

input wire clk;
input wire rstnn;
input wire rpsel;
input wire rpenable;
input wire rpwrite;
input wire [(BW_ADDR)-1:0] rpaddr;
input wire [(BW_DATA)-1:0] rpwdata;
output wire rpready;
output wire [(BW_DATA)-1:0] rprdata;
output wire rpslverr;






endmodule