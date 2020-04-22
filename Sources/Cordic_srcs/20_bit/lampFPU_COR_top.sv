// Copyright 2019 Politecnico di Milano.
// Copyright and related rights are licensed under the Solderpad Hardware
// Licence, Version 2.0 (the "Licence"); you may not use this file except in
// compliance with the Licence. You may obtain a copy of the Licence at
// https://solderpad.org/licenses/SHL-2.0/. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this Licence is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the Licence for the
// specific language governing permissions and limitations under the Licence.
//
// Authors (in alphabetical order):
// Andrea Galimberti    <andrea.galimberti@polimi.it>
// Davide Zoni          <davide.zoni@polimi.it>
//
// Date: 30.09.2019

module lampFPU_COR_top (
	clk, rst,
	flush_i, padv_i,
	opcode_i, rndMode_i, op1_i, op2_i,
	result_o, isResultValid_o, isReady_o
);

import lampFPU_COR_pkg::*;

input									clk;
input									rst;
input									flush_i;	// Flush the FPU invalidating the current operation
input									padv_i;		// Pipeline advance signal: accept new operation
input	opcodeFPU_t						opcode_i;
input	rndModeFPU_t					rndMode_i;
input			[LAMP_FLOAT_DW-1:0]		op1_i;
input			[LAMP_FLOAT_DW-1:0]		op2_i;

output	logic	[LAMP_FLOAT_DW-1:0]	result_o;
output	logic							isResultValid_o;
output	logic							isReady_o;

// INPUT wires: to drive registered input
	logic 									flush_r, flush_r_next;
	opcodeFPU_t								opcode_r, opcode_r_next;
	rndModeFPU_t							rndMode_r, rndMode_r_next;

// OUTPUT wires: to drive registered output
	logic	[LAMP_FLOAT_DW-1:0]			result_o_next;
	logic									isResultValid_o_next;

	//	add/sub outputs
	logic									addsub_s_res;
	logic	[LAMP_FLOAT_E_DW-1:0]			addsub_e_res;
	logic	[LAMP_FLOAT_F_DW+5-1:0]			addsub_f_res;
	logic									addsub_valid;
	logic									addsub_isOverflow;
	logic									addsub_isUnderflow;
	logic									addsub_isToRound;

	logic									doAddSub_r, doAddSub_r_next;
	logic									isOpSub_r, isOpSub_r_next;

	// FUs results and valid bits
	logic	[LAMP_FLOAT_DW-1:0]			res;
	logic									isResValid;

	//	op1
	logic	[LAMP_FLOAT_S_DW-1:0] 			s_op1_r;
	logic	[LAMP_FLOAT_E_DW-1:0] 			e_op1_r;
	logic	[LAMP_FLOAT_F_DW-1:0] 			f_op1_r;
	logic	[(LAMP_FLOAT_F_DW+1)-1:0] 		extF_op1_r;
	logic	[(LAMP_FLOAT_E_DW+1)-1:0] 		extE_op1_r;
	logic									isInf_op1_r;
	logic									isZ_op1_r;
	logic									isSNAN_op1_r;
	logic									isQNAN_op1_r;
	//	op2
	logic	[LAMP_FLOAT_S_DW-1:0] 			s_op2_r;
	logic	[LAMP_FLOAT_E_DW-1:0] 			e_op2_r;
	logic	[LAMP_FLOAT_F_DW-1:0] 			f_op2_r;
	logic	[(LAMP_FLOAT_F_DW+1)-1:0] 		extF_op2_r;
	logic	[(LAMP_FLOAT_E_DW+1)-1:0] 		extE_op2_r;
	logic									isInf_op2_r;
	logic									isZ_op2_r;
	logic									isSNAN_op2_r;
	logic									isQNAN_op2_r;
	//	add/sub only
	logic									op1_GT_op2_r;
	logic	[LAMP_FLOAT_E_DW+1-1 : 0] 		e_diff_r;

	//	pre-operation wires/regs
	//	op1
	logic	[LAMP_FLOAT_S_DW-1:0] 			s_op1_wire;
	logic	[LAMP_FLOAT_E_DW-1:0] 			e_op1_wire;
	logic	[LAMP_FLOAT_F_DW-1:0] 			f_op1_wire;
	logic	[(LAMP_FLOAT_F_DW+1)-1:0] 		extF_op1_wire;
	logic	[(LAMP_FLOAT_E_DW+1)-1:0] 		extE_op1_wire;
	logic									isDN_op1_wire;
	logic									isZ_op1_wire;
	logic									isInf_op1_wire;
	logic									isSNAN_op1_wire;
	logic									isQNAN_op1_wire;
	//	op2
	logic	[LAMP_FLOAT_S_DW-1:0] 			s_op2_wire;
	logic	[LAMP_FLOAT_E_DW-1:0] 			e_op2_wire;
	logic	[LAMP_FLOAT_F_DW-1:0] 			f_op2_wire;
	logic	[(LAMP_FLOAT_F_DW+1)-1:0] 		extF_op2_wire;
	logic	[(LAMP_FLOAT_E_DW+1)-1:0] 		extE_op2_wire;
	logic									isDN_op2_wire;
	logic									isZ_op2_wire;
	logic									isInf_op2_wire;
	logic									isSNAN_op2_wire;
	logic									isQNAN_op2_wire;
	//	add/sub only
	logic									op1_GT_op2_wire;
	logic	[LAMP_FLOAT_E_DW+1-1 : 0] 		e_diff_wire;

	//	pre-rounding wires/regs
	logic									s_res;
	logic	[LAMP_FLOAT_E_DW-1:0]			e_res;
	logic	[LAMP_FLOAT_F_DW+5-1:0]			f_res;
	logic									isOverflow;
	logic									isUnderflow;
	logic									isToRound;

	//	post-rounding wires/regs
	logic									s_res_postRnd;
	logic	[LAMP_FLOAT_F_DW-1:0]			f_res_postRnd;
	logic	[LAMP_FLOAT_E_DW-1:0]			e_res_postRnd;
	logic	[LAMP_FLOAT_DW-1:0]			res_postRnd;
	logic									isOverflow_postRnd;
	logic									isUnderflow_postRnd;

//////////////////////////////////////////////////////////////////
// 							state enum							//
//////////////////////////////////////////////////////////////////

	typedef enum logic [1:0]
	{
		IDLE	= 'd0,
		WORK	= 'd1,
		DONE	= 'd2
	}	ssFpuTop_t;

	ssFpuTop_t 	ss, ss_next;

//////////////////////////////////////////////////////////////////
// 						sequential logic						//
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			ss					<=	IDLE;
		//input
			doAddSub_r			<=	1'b0;
			isOpSub_r			<=	1'b0;
			flush_r				<=	1'b0;
			opcode_r			<=	FPU_IDLE;
			rndMode_r			<=	FPU_RNDMODE_NEAREST;
		//output
			result_o			<=	'0;
			isResultValid_o		<=	1'b0;
		end
		else
		begin
			ss					<=	ss_next;
		//input
			doAddSub_r			<=	doAddSub_r_next;
			isOpSub_r			<=	isOpSub_r_next;
			flush_r				<=	flush_r_next;
			opcode_r			<=	opcode_r_next;
			rndMode_r			<=	rndMode_r_next;
		//output
			result_o			<=	result_o_next;
			isResultValid_o		<=	isResultValid_o_next;
		end
	end

//////////////////////////////////////////////////////////////////
// 						combinational logic						//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		ss_next					=	ss;
		doAddSub_r_next			=	1'b0;
		isOpSub_r_next			=	1'b0;

		flush_r_next			=	flush_r;
		opcode_r_next			=	opcode_r;
		rndMode_r_next			=	rndMode_r;
		result_o_next			=	result_o;
		isResultValid_o_next	=	isResultValid_o;

		s_res					=	1'b0;
		e_res					=	'0;
		f_res					=	'0;
		isOverflow				=	1'b0;
		isUnderflow				=	1'b0;
		isToRound				=	1'b0;

		res						=	'0;
		isResValid				=	1'b0;
		case (ss)
			IDLE:
			begin

				// NOTE: the flush signal can only be set during the first cycle
				// the fpu starts operating on the inputs, after the pipeline has advanced.
				// Therefore, if asserted, avoid executing the current operation
				// and don't start any functional unit. We need a more robust solution
				// here in the future: internal functional units must have one flush_i
				// signal each that resets their inner status in case of flush


				if (opcode_i != FPU_IDLE && !flush_i)
				begin
					ss_next			=	WORK;
					flush_r_next	=	'0;
					opcode_r_next	=	opcode_i;
					rndMode_r_next	=   rndMode_i;
					case (opcode_i)
						FPU_ADD	:
						begin
                            doAddSub_r_next	=	1'b1;
                            isOpSub_r_next	=	1'b0;
						end
						FPU_SUB	:
						begin
                            doAddSub_r_next	=	1'b1;
                            isOpSub_r_next	=	1'b1;
						end
						FPU_MUL	:
						begin
                            ss_next         =   IDLE;
                            opcode_r_next   =	FPU_IDLE;
						end
					endcase
				end
			end
			WORK:
			begin
				case (opcode_r)
					FPU_ADD, FPU_SUB:
					begin
						s_res		=	addsub_s_res;
						e_res		=	addsub_e_res;
						f_res		=	addsub_f_res;
						isOverflow	=	addsub_isOverflow;
						isUnderflow	=	addsub_isUnderflow;
						isToRound	=	addsub_isToRound;

						res			=	res_postRnd;
						isResValid	=	addsub_valid;
					end
					FPU_MUL	:
					begin
                        ss_next         = IDLE;
                        opcode_r_next	=	FPU_IDLE;
					end
				endcase

				if (isResValid)
				begin
					result_o_next			=	res;
					isResultValid_o_next	=	1'b1;
					ss_next					=	DONE;
				end
			end
			DONE:
			begin
				if (padv_i)
				begin
					isResultValid_o_next   =   1'b0;
					ss_next                =   IDLE;
				end
			end
		endcase
	end

//////////////////////////////////////////////////////////////////
// 			operands pre-processing	- sequential logic			//
//////////////////////////////////////////////////////////////////

	always_ff @(posedge clk)
	begin
		if (rst)
		begin
			// op1
			s_op1_r			<=	'0;
			e_op1_r			<=	'0;
			f_op1_r			<=	'0;
			extF_op1_r		<=	'0;
			extE_op1_r		<=	'0;
			isInf_op1_r		<=	'0;
			isZ_op1_r		<=	'0;
			isSNAN_op1_r	<=	'0;
			isQNAN_op1_r	<=	'0;
			// op2
			s_op2_r			<=	'0;
			e_op2_r			<=	'0;
			f_op2_r			<=	'0;
			extF_op2_r		<=	'0;
			extE_op2_r		<=	'0;
			isInf_op2_r		<=	'0;
			isZ_op2_r		<=	'0;
			isSNAN_op2_r	<=	'0;
			isQNAN_op2_r	<=	'0;
			//	add/sub only
			op1_GT_op2_r	<=	'0;
			e_diff_r		<=	'0;
		end
		else
		begin
			//	op1
			s_op1_r			<=	s_op1_wire;
			e_op1_r			<=	e_op1_wire;
			f_op1_r			<=	f_op1_wire;
			extF_op1_r		<=	extF_op1_wire;
			extE_op1_r		<=	extE_op1_wire;
			isInf_op1_r		<=	isInf_op1_wire;
			isZ_op1_r		<=	isZ_op1_wire;
			isSNAN_op1_r	<=	isSNAN_op1_wire;
			isQNAN_op1_r	<=	isQNAN_op1_wire;
			//op2
			s_op2_r			<=	s_op2_wire;
			e_op2_r			<=	e_op2_wire;
			f_op2_r			<=	f_op2_wire;
			extF_op2_r		<=	extF_op2_wire;
			extE_op2_r		<=	extE_op2_wire;
			isInf_op2_r		<=	isInf_op2_wire;
			isZ_op2_r		<=	isZ_op2_wire;
			isSNAN_op2_r	<=	isSNAN_op2_wire;
			isQNAN_op2_r	<=	isQNAN_op2_wire;
			//	add/sub only
			op1_GT_op2_r	<=	op1_GT_op2_wire;
			e_diff_r		<=	e_diff_wire;
		end
	end

//////////////////////////////////////////////////////////////////
// 			operands pre-processing	- combinational logic		//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		{s_op1_wire, e_op1_wire, f_op1_wire}										= FUNC_splitOperand(op1_i);
		{isInf_op1_wire,isDN_op1_wire,isZ_op1_wire,isSNAN_op1_wire,isQNAN_op1_wire}	= FUNC_checkOperand(op1_i);
		extE_op1_wire																= FUNC_extendExp(e_op1_wire, isDN_op1_wire);
		extF_op1_wire 																= FUNC_extendFrac(f_op1_wire, isDN_op1_wire, isZ_op1_wire);

		{s_op2_wire, e_op2_wire, f_op2_wire}										= FUNC_splitOperand(op2_i);
		{isInf_op2_wire,isDN_op2_wire,isZ_op2_wire,isSNAN_op2_wire,isQNAN_op2_wire}	= FUNC_checkOperand(op2_i);
		extE_op2_wire																= FUNC_extendExp(e_op2_wire, isDN_op2_wire);
		extF_op2_wire 																= FUNC_extendFrac(f_op2_wire, isDN_op2_wire, isZ_op2_wire);

		//	add/sub only
		op1_GT_op2_wire																= FUNC_op1_GT_op2(extF_op1_wire, extE_op1_wire, extF_op2_wire, extE_op2_wire);
		e_diff_wire																	= op1_GT_op2_wire ? (extE_op1_wire - extE_op2_wire) : (extE_op2_wire - extE_op1_wire);

	end

	// NOTE: fpu ready signal that makes the pipeline to advance.
	// It is simple and plain combinational logic: this should require
	// some cpu-side optimizations to improve the overall system timing
	// in the future. The entire advancing mechanism should be re-designed
	// from scratch

	assign isReady_o = (opcode_i == FPU_IDLE) | isResultValid_o;

//////////////////////////////////////////////////////////////////
// 				float rounding - combinational logic			//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		if (rndMode_r == FPU_RNDMODE_NEAREST)
			f_res_postRnd	= FUNC_rndToNearestEven(f_res);
		else
			f_res_postRnd	= f_res[3+:LAMP_FLOAT_F_DW];
		if (isToRound)
			res_postRnd		= {s_res, e_res, f_res_postRnd};
		else
			res_postRnd		= {s_res, e_res, f_res[5+:LAMP_FLOAT_F_DW]};
	end

//////////////////////////////////////////////////////////////////
//						internal submodules						//
//////////////////////////////////////////////////////////////////

	lampFPU_COR_addsub
		lampFPU_COR_addsub0(
			.clk					(clk),
			.rst					(rst),
			//	inputs
			.doAddSub_i				(doAddSub_r),
			.isOpSub_i 				(isOpSub_r),
			.s_op1_i				(s_op1_r),
			.extF_op1_i				(extF_op1_r),
			.extE_op1_i				(extE_op1_r),
			.isInf_op1_i			(isInf_op1_r),
			.isSNAN_op1_i			(isSNAN_op1_r),
			.isQNAN_op1_i			(isQNAN_op1_r),
			.s_op2_i				(s_op2_r),
			.extF_op2_i				(extF_op2_r),
			.extE_op2_i				(extE_op2_r),
			.isInf_op2_i			(isInf_op2_r),
			.isSNAN_op2_i			(isSNAN_op2_r),
			.isQNAN_op2_i			(isQNAN_op2_r),
			.op1_GT_op2_i			(op1_GT_op2_r),
			.e_diff_i				(e_diff_r),
			//	outputs
			.s_res_o				(addsub_s_res),
			.e_res_o				(addsub_e_res),
			.f_res_o				(addsub_f_res),
			.valid_o				(addsub_valid),
			.isOverflow_o			(addsub_isOverflow),
			.isUnderflow_o			(addsub_isUnderflow),
			.isToRound_o			(addsub_isToRound)
		);

endmodule
