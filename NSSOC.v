module NSSOC(
	nRST, CLK, nHLT, RAMCLK,
	nWR, nRD, ADDR, DATA, DATO,
	nINT, nIOE,
	STATE, PROGC, INST, INSTLEN, RLAST
);

	output[3:0] STATE;
	output[7:0] PROGC;
	output[71:0] INST;
	output[3:0] INSTLEN;
	output[23:0] RLAST;

	input nRST, CLK, RAMCLK;
	output nHLT;
	output nWR, nRD;
	output[23:0] ADDR, DATA, DATO;
	output nINT, nIOE;

	wire NSCPU_nHLT, NSCPU_nWR, NSCPU_nRD, NSCPU_nINT, NSCPU_nIOE;
	wire[23:0] NSCPU_ADDR, NSCPU_DATA, NSCPU_DATO;
	
	NSCPU nscpu(
		.nRST(nRST),
		.CLK(CLK),
		.nHLT(NSCPU_nHLT),
		.nWR(NSCPU_nWR),
		.nRD(NSCPU_nRD),
		.ADDR(NSCPU_ADDR),
		.DATA(NSCPU_DATA),
		.DATO(NSCPU_DATO),
		.nINT(NSCPU_nINT),
		.nIOE(NSCPU_nIOE),
		.STATE(STATE),
		.PROGC(PROGC),
		.INST(INST),
		.INSTLEN(INSTLEN),
		.RLAST(RLAST)
	);
	
	DATA data(
		.address(NSCPU_ADDR[7:0]),
		//.clock(NSCPU_nIOE && (!NSCPU_nWR || !NSCPU_nRD)),
		.clock(NSCPU_nIOE && RAMCLK),
		.data(NSCPU_DATO),
		.rden(!NSCPU_nRD),
		.wren(!NSCPU_nWR),
		.q(NSCPU_DATA)
	);

	assign nHLT = NSCPU_nHLT;
	assign nWR = NSCPU_nWR;
	assign nRD = NSCPU_nRD;
	assign ADDR = NSCPU_ADDR;
	assign DATA = NSCPU_DATA;
	assign DATO = NSCPU_DATO;
	assign nINT = NSCPU_nINT;
	assign nIOE = NSCPU_nIOE;
	
endmodule
