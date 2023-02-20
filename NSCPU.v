`define NSCPU_INST_A
`define NSCPU_INST_B

module NSCPU(
	nRST, CLK, nHLT,
	nWR, nRD, ADDR, DATA, DATO,
	nINT, nIOE,
	
	STATE, PROGC, INST, INSTLEN, RLAST
);

	output[3:0] STATE;
	output[7:0] PROGC;
	output[71:0] INST;
	output[3:0] INSTLEN;
	output[23:0] RLAST;
	
	assign STATE = state;
	assign PROGC = PC[7:0];
	assign INST = inst_bus;
	assign INSTLEN = inst_len;
	assign RLAST = RL;

	input nRST, CLK;
	output nHLT;
	output reg nWR, nRD;
	output reg[23:0] ADDR;
	input[23:0] DATA;
	output[23:0] DATO;
	output reg nINT, nIOE;
	
	reg[23:0] data_buf;
	assign DATO = !nWR ? (nRD ? data_buf : 24'bz) : 24'bz;

	reg HLT;
	reg[23:0] PC, RL, RE;
`ifdef NSCPU_INST_A
	reg[3:0] SP;
	reg[23:0] STACK[15:0];
`endif
	integer i;
	
	assign nHLT = !HLT;
	
	reg[3:0] state, cmd_state;
	
	// type: 1->ADDR, 0->DATA; vaild: 1->VAILD, 0->NOPE
	reg src_type, dst_type, ext_vaild;
	reg[7:0] cmd, ext;
	reg[23:0] dst, src;
	
	reg[23:0] inst[2:0];
	
	wire[71:0] inst_bus;
	assign inst_bus = { inst[2], inst[1], inst[0] };
	
	wire[1:0] dst_len, src_len, cmd_len;
	assign dst_len = inst[0][2:1];
	assign src_len = inst[0][4:3];
	assign cmd_len = inst[0][0] ? (inst[0][8] ? 2'd3 : 2'd2) : 2'd1;
	reg[3:0] inst_len;
	
	initial begin
		nWR <= 1'b1;
		nRD <= 1'b1;
		ADDR <= 24'b0;
		data_buf <= 24'b0;
		nINT <= 1'b1;
		nIOE <= 1'b1;
		
		HLT <= 1'b0;
		PC <= 24'b0;
		RL <= 24'b0;
		RE <= 24'b0;
		
	`ifdef NSCPU_INST_A
		SP <= 4'b0;
		for (i = 0; i < 16; i = i + 1)
			STACK[i] <= 24'b0;
	`endif
			
		state <= 4'b0;
		cmd_state <= 4'b0;
	end
	
	always @(negedge nRST or posedge CLK) begin
		if (!nRST) begin
			nWR <= 1'b1;
			nRD <= 1'b1;
			ADDR <= 24'b0;
			data_buf <= 24'b0;
			nINT <= 1'b1;
			nIOE <= 1'b1;
			
			HLT <= 1'b0;
			PC <= 24'b0;
			RL <= 24'b0;
			RE <= 24'b0;
			
		`ifdef NSCPU_INST_A
			SP <= 4'b0;
			for (i = 0; i < 16; i = i + 1)
				STACK[i] <= 24'b0;
		`endif
				
			state <= 4'b0;
			cmd_state <= 4'b0;
		end else begin
			if (HLT) begin
				ADDR <= PC;
				data_buf <= RE;
				nWR <= 1'b0;
				nRD <= 1'b1;
			end else begin
				case (state)
					4'h0: begin		// inst[0] fetch, build addr
						ADDR <= PC;
						state <= state + 4'b1;
					end
					4'h1: begin		// inst[0] fetch, read edge
						nRD <= 1'b0;
						
						for (i = 0; i < 3; i = i + 1)
							inst[i] <= 24'b0;
						
						state <= state + 4'b1;
					end
					4'h2: begin		// inst[0] fetch, got data
						inst[0] <= DATA;
						ADDR <= 24'bz;
						nRD <= 1'b1;
						PC <= PC + 24'd1;
						
						state <= state + 4'b1;
					end
					4'h3: begin		// calc inst length
						dst_type <= 1'b0;
						src_type <= 1'b0;
						ext_vaild <= 1'b0;
						cmd <= 8'b0;
						ext <= 8'b0;
						dst <= 24'b0;
						src <= 24'b0;
						
						inst_len <= cmd_len + dst_len + src_len;
						state <= state + 4'b1;
					end
					4'h4: begin		// late fetch
						case (inst_len)
							4'd1, 4'd2, 4'd3: state <= state + 4'h7;
							4'd4, 4'd5, 4'd6: state <= state + 4'h1;
							4'd7, 4'd8, 4'd9: state <= state + 4'h1;
						endcase
					end
					4'h5: begin		// inst[1] fetch, build addr
						ADDR <= PC;
						state <= state + 4'b1;
					end
					4'h6: begin		// inst[1] fetch, read edge
						nRD <= 1'b0;
						state <= state + 4'b1;
					end
					4'h7: begin		// inst[1] fetch, got data
						inst[1] <= DATA;
						ADDR <= 24'bz;
						nRD <= 1'b1;
						PC <= PC + 24'd1;
						
						state <= state + 4'b1;
						case (inst_len)
							4'd1, 4'd2, 4'd3: begin
								RE <= { 8'hEE, "SM" };
								HLT <= 1'b1;
							end
							4'd4, 4'd5, 4'd6: state <= state + 4'h4;
							4'd7, 4'd8, 4'd9: state <= state + 4'h1;
						endcase
					end
					4'h8: begin		// inst[2] fetch, build addr
						ADDR <= PC;
						state <= state + 4'b1;
					end
					4'h9: begin		// inst[2] fetch, read edge
						nRD <= 1'b0;
						state <= state + 4'b1;
					end
					4'hA: begin		// inst[2] fetch, got data
						inst[2] <= DATA;
						ADDR <= 24'bz;
						nRD <= 1'b1;
						PC <= PC + 24'd1;
						
						state <= state + 4'b1;
					end
					4'hB: begin		// fetch expr
						if (cmd_len == 2'd1) begin
							cmd <= { 5'b0, inst[0][7:5] };
						end else begin
							cmd <= { inst[0][15:11], inst[0][7:5] };
							dst_type <= inst[0][9];
							src_type <= inst[0][10];
							if (cmd_len == 2'd3) begin
								ext_vaild <= 1'b1;
								ext <= inst[0][23:16];
							end
						end
						case (dst_len)
							2'd1: dst <= inst_bus[8 * cmd_len +: 8 * 1];
							2'd2: dst <= inst_bus[8 * cmd_len +: 8 * 2];
							2'd3: dst <= inst_bus[8 * cmd_len +: 8 * 3];
						endcase
						case (src_len)
							2'd1: src <= inst_bus[8 * (cmd_len + dst_len) +: 8 * 1];
							2'd2: src <= inst_bus[8 * (cmd_len + dst_len) +: 8 * 2];
							2'd3: src <= inst_bus[8 * (cmd_len + dst_len) +: 8 * 3];
						endcase
							
						state <= state + 4'b1;
					end
					4'hC: begin		// execute
						case (cmd)
							8'h0: begin		// nop
								if (dst_len != 0 || src_len != 0) begin
									RE <= { 8'h0, "EE" };
									HLT <= 1'b1;
								end else begin
									RL <= 24'b0;
									state <= state + 4'b1;
								end
							end
							8'h1: begin		// mov
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'h1, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'h1, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												data_buf <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'h2: begin		// add
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'h2, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'h2, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf + DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA + src;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'h3: begin		// sub
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'h3, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'h3, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf - DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA - src;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'h4: begin		// int
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h4, "EE" };
									HLT <= 1'b1;
								end else begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												ADDR <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												nINT <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nINT <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												RL <= dst;
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nINT <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												ADDR <= 24'bz;
												nINT <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'h5: begin		// jmp
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h5, "EE" };
									HLT <= 1'b1;
								end else begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												PC <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										PC <= dst;
										state <= state + 4'b1;
									end
								end
							end
							8'h6: begin		// jnz
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h6, "EE" };
									HLT <= 1'b1;
								end else if (RL != 0) begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												PC <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										PC <= dst;
										state <= state + 4'b1;
									end
								end else begin
									state <= state + 4'b1;
								end
							end
							8'h7: begin		// hlt
								if (dst_len != 0 || src_len != 0) begin
									RE <= { 8'h7, "EE" };
									HLT <= 1'b1;
								end else begin
									RE <= { dst[7:0], "OK" };
									HLT <= 1'b1;
								end
							end
					`ifdef NSCPU_INST_A
							8'h8: begin		// push
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h8, "EE" };
									HLT <= 1'b1;
								end else begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												STACK[SP] <= DATA;
												SP <= SP + 4'd1;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										STACK[SP] <= dst;
										SP <= SP + 4'd1;
										state <= state + 4'b1;
									end
								end
							end
							8'h9: begin		// pop
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h9, "EE" };
									HLT <= 1'b1;
								end else begin
									if (!dst_type) begin
										RE <= { 8'h9, "NW" };
										HLT <= 1'b1;
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												data_buf <= STACK[SP];
												RL <= STACK[SP];
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												SP <= SP - 4'd1;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hA: begin		// not
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'hA, "EE" };
									HLT <= 1'b1;
								end else begin
									if (!dst_type) begin
										RE <= { 8'hA, "NW" };
										HLT <= 1'b1;
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= ~DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hB: begin		// and
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'hB, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'hB, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf & DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA & src;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hC: begin		// or
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'hC, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'hC, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf | DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA | src;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hD: begin 	// xor
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'hD, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'hD, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf ^ DATA;
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA ^ src;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hE: begin 	// shl
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'hE, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'hE, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf << DATA[4:0];
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA << src[4:0];
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'hF: begin		// shr
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'hF, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'hF, "NW" };
									HLT <= 1'b1;
								end else begin
									if (src_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												data_buf <= data_buf >> DATA[4:0];
												ADDR <= dst;
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd7: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA >> src[4:0];
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
						`ifdef NSCPU_INST_B
							8'h10: begin	// cmp
								if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'h10, "EE" };
									HLT <= 1'b1;
								end else begin
									case (cmd_state)
										4'd0: begin
											if (dst_type) begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end else
												cmd_state <= 4'd3;
										end
										4'd1: begin
											nRD <= 1'b0;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd2: begin
											dst <= DATA;
											ADDR <= 24'bz;
											nRD <= 1'b1;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd3: begin
											if (src_type) begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end else
												cmd_state <= 4'd6;
										end
										4'd4: begin
											nRD <= 1'b0;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd5: begin
											src <= DATA;
											ADDR <= 24'bz;
											nRD <= 1'b1;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd6: begin
											RL <= dst - src;
											state <= state + 4'b1;
										end
									endcase
								end
							end
							8'h11: begin	// jg
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h11, "EE" };
									HLT <= 1'b1;
								end else if (RL > 0) begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												PC <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										PC <= dst;
										state <= state + 4'b1;
									end
								end else begin
									state <= state + 4'b1;
								end
							end
							8'h12: begin	// jl
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h12, "EE" };
									HLT <= 1'b1;
								end else if (RL < 0) begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												PC <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										PC <= dst;
										state <= state + 4'b1;
									end
								end else begin
									state <= state + 4'b1;
								end
							end
							8'h13: begin	// jz
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h13, "EE" };
									HLT <= 1'b1;
								end else if (RL == 0) begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												PC <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										RL <= dst;
										PC <= dst;
										state <= state + 4'b1;
									end
								end else begin
									state <= state + 4'b1;
								end
							end
							8'h14: begin	// loop
								if (!ext_vaild) begin
									RE <= { 8'h14, "EX" };
									HLT <= 1'b1;
								end else if (dst_len == 0 || src_len == 0) begin
									RE <= { 8'h14, "EE" };
									HLT <= 1'b1;
								end else if (!dst_type) begin
									RE <= { 8'h14, "NW" };
									HLT <= 1'b1;
								end else begin
									case (cmd_state)
										4'd0: begin
											ADDR <= dst;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd1: begin
											nRD <= 1'b0;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd2: begin
											data_buf <= DATA;
											ADDR <= 24'bz;
											nRD <= 1'b1;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd3: begin
											if (src_type) begin
												ADDR <= src;
												cmd_state <= cmd_state + 4'd1;
											end else
												cmd_state <= 4'd6;
										end
										4'd4: begin
											nRD <= 1'b0;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd5: begin
											src <= DATA;
											ADDR <= 24'bz;
											nRD <= 1'b1;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd6: begin
											if (data_buf[7:0] != ext) begin
												if (ext == 0)
													data_buf <= data_buf - 24'd1;
												else
													data_buf <= data_buf + 24'd1;
												PC <= src;
											end
											ADDR <= dst;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd7: begin
											nWR <= 1'b0;
											cmd_state <= cmd_state + 4'd1;
										end
										4'd8: begin
											ADDR <= 24'bz;
											nWR <= 1'b1;
											state <= state + 4'b1;
										end
									endcase
								end
							end
							8'h15: begin	// rst
								if (dst_len != 0 || src_len != 0) begin
									RE <= { 8'h15, "EE" };
									HLT <= 1'b1;
								end else begin
									PC <= 24'b0;
									state <= state + 4'b1;
								end
							end
							8'h16: begin	// in
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h16, "EE" };
									HLT <= 1'b1;
								end else begin
									if (!dst_type) begin
										RE <= { 8'h16, "NW" };
										HLT <= 1'b1;
									end else begin
										case (cmd_state)
											4'd0: begin
												nIOE <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												RL <= DATA;
												data_buf <= DATA;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												nRD <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												nIOE <= 1'b1;
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												ADDR <= 24'bz;
												nWR <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
							8'h17: begin	// out
								if (dst_len == 0 || src_len != 0) begin
									RE <= { 8'h17, "EE" };
									HLT <= 1'b1;
								end else begin
									if (dst_type) begin
										case (cmd_state)
											4'd0: begin
												ADDR <= dst;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												nRD <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												data_buf <= DATA;
												ADDR <= 24'bz;
												nRD <= 1'b1;
												state <= state + 4'b1;
											end
											4'd3: begin
												nIOE <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd4: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd5: begin
												nWR <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd6: begin
												nIOE <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end else begin
										case (cmd_state)
											4'd0: begin
												data_buf <= dst;
												nIOE <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd1: begin
												RL <= data_buf;
												nWR <= 1'b0;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd2: begin
												nWR <= 1'b1;
												cmd_state <= cmd_state + 4'd1;
											end
											4'd3: begin
												nIOE <= 1'b1;
												state <= state + 4'b1;
											end
										endcase
									end
								end
							end
						`endif
					`endif
						endcase
					end
					4'hD: begin		// reset state machine
						cmd_state <= 4'b0;
						state <= 4'b0;
					end
				endcase
			end
		end
	end
	
endmodule
