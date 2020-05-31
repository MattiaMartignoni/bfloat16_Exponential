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

//some modifications has been made to make this module perform only the multiplication operation
//also the package has been modified for this purpose

module lampFPU_EXP_top (
	clk, rst,
	flush_i, padv_i,
	opcode_i, rndMode_i, op1_i, op2_i,
	result_o, isResultValid_o, isReady_o
);

//import lampFPU_MUL_pkg::*;
//import main_pkg::*;
import exponential_pkg_scrap::*;

input									clk;
input									rst;
input									flush_i;	// Flush the FPU invalidating the current operation
input									padv_i;		// Pipeline advance signal: accept new operation
input	opcodeFPU_t						opcode_i;
input	rndModeFPU_t					rndMode_i;
input			[LAMP_FLOAT_MUL_DW-1:0]		op1_i;
input			[LAMP_FLOAT_MUL_DW-1:0]		op2_i;

output	logic	[LAMP_FLOAT_MUL_DW-1:0]	result_o;
output	logic							isResultValid_o;
output	logic							isReady_o;

// INPUT wires: to drive registered input
	logic 									flush_r, flush_r_next;
	opcodeFPU_t								opcode_r, opcode_r_next;
	rndModeFPU_t							rndMode_r, rndMode_r_next;

// OUTPUT wires: to drive registered output
	logic	[LAMP_FLOAT_MUL_DW-1:0]			result_o_next;
	logic									isResultValid_o_next;

	//	mul outputs
	logic									mul_s_res;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0]			mul_e_res;
	logic	[LAMP_FLOAT_MUL_F_DW+5-1:0]			mul_f_res;
	logic									mul_valid;
	logic									mul_isOverflow;
	logic									mul_isUnderflow;
	logic									mul_isToRound;

	logic									doMul_r, doMul_next;

	// FUs results and valid bits
	logic	[LAMP_FLOAT_MUL_DW-1:0]			res;
	logic									isResValid;

	//	op1
	logic	[LAMP_FLOAT_MUL_S_DW-1:0] 			s_op1_r;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0] 			e_op1_r;
	logic	[LAMP_FLOAT_MUL_F_DW-1:0] 			f_op1_r;
	logic	[(LAMP_FLOAT_MUL_F_DW+1)-1:0] 		extF_op1_r;
	logic	[(LAMP_FLOAT_MUL_E_DW+1)-1:0] 		extE_op1_r;
	logic									isInf_op1_r;
	logic									isZ_op1_r;
	logic									isSNAN_op1_r;
	logic									isQNAN_op1_r;
	//	op2
	logic	[LAMP_FLOAT_MUL_S_DW-1:0] 			s_op2_r;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0] 			e_op2_r;
	logic	[LAMP_FLOAT_MUL_F_DW-1:0] 			f_op2_r;
	logic	[(LAMP_FLOAT_MUL_F_DW+1)-1:0] 		extF_op2_r;
	logic	[(LAMP_FLOAT_MUL_E_DW+1)-1:0] 		extE_op2_r;
	logic									isInf_op2_r;
	logic									isZ_op2_r;
	logic									isSNAN_op2_r;
	logic									isQNAN_op2_r;
	//	mul/div only
	logic	[(1+LAMP_FLOAT_MUL_F_DW)-1:0] 		extShF_op1_r;
	logic	[$clog2(1+LAMP_FLOAT_MUL_F_DW)-1:0]	nlz_op1_r;
	logic	[(1+LAMP_FLOAT_MUL_F_DW)-1:0] 		extShF_op2_r;
	logic	[$clog2(1+LAMP_FLOAT_MUL_F_DW)-1:0]	nlz_op2_r;

	//	pre-operation wires/regs
	//	op1
	logic	[LAMP_FLOAT_MUL_S_DW-1:0] 			s_op1_wire;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0] 			e_op1_wire;
	logic	[LAMP_FLOAT_MUL_F_DW-1:0] 			f_op1_wire;
	logic	[(LAMP_FLOAT_MUL_F_DW+1)-1:0] 		extF_op1_wire;
	logic	[(LAMP_FLOAT_MUL_E_DW+1)-1:0] 		extE_op1_wire;
	logic									isDN_op1_wire;
	logic									isZ_op1_wire;
	logic									isInf_op1_wire;
	logic									isSNAN_op1_wire;
	logic									isQNAN_op1_wire;
	//	op2
	logic	[LAMP_FLOAT_MUL_S_DW-1:0] 			s_op2_wire;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0] 			e_op2_wire;
	logic	[LAMP_FLOAT_MUL_F_DW-1:0] 			f_op2_wire;
	logic	[(LAMP_FLOAT_MUL_F_DW+1)-1:0] 		extF_op2_wire;
	logic	[(LAMP_FLOAT_MUL_E_DW+1)-1:0] 		extE_op2_wire;
	logic									isDN_op2_wire;
	logic									isZ_op2_wire;
	logic									isInf_op2_wire;
	logic									isSNAN_op2_wire;
	logic									isQNAN_op2_wire;
	//	mul/div only
	logic	[(1+LAMP_FLOAT_MUL_F_DW)-1:0] 		extShF_op1_wire;
	logic	[$clog2(1+LAMP_FLOAT_MUL_F_DW)-1:0]	nlz_op1_wire;
	logic	[(1+LAMP_FLOAT_MUL_F_DW)-1:0] 		extShF_op2_wire;
	logic	[$clog2(1+LAMP_FLOAT_MUL_F_DW)-1:0]	nlz_op2_wire;

	//	pre-rounding wires/regs
	logic									s_res;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0]			e_res;
	logic	[LAMP_FLOAT_MUL_F_DW+5-1:0]			f_res;
	logic									isOverflow;
	logic									isUnderflow;
	logic									isToRound;

	//	post-rounding wires/regs
	logic									s_res_postRnd;
	logic	[LAMP_FLOAT_MUL_F_DW-1:0]			f_res_postRnd;
	logic	[LAMP_FLOAT_MUL_E_DW-1:0]			e_res_postRnd;
	logic	[LAMP_FLOAT_MUL_DW-1:0]			    res_postRnd;
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
			doMul_r				<=	1'b0;
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
			doMul_r				<=	doMul_next;
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
		doMul_next				=	1'b0;

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
					ss_next							=	WORK;
					case (opcode_i)
						FPU_MUL	:	doMul_next		=	1'b1;
					endcase
					flush_r_next						=	'0;
					opcode_r_next						=	opcode_i;
					rndMode_r_next						=	rndMode_i;
				end
			end
			WORK:
			begin
				case (opcode_r)
					FPU_MUL:
					begin
						s_res						=	mul_s_res;
						e_res						=	mul_e_res;
						f_res						=	mul_f_res;
						isOverflow					=	mul_isOverflow;
						isUnderflow					=	mul_isUnderflow;
						isToRound					=	mul_isToRound;

						res							=	res_postRnd;
						isResValid					=	mul_valid;
					end
				endcase

				if (isResValid)
				begin
					result_o_next					=	res;
					isResultValid_o_next			=	1'b1;
					ss_next							=	DONE;
				end
			end
			DONE:
			begin
				if (padv_i)
				begin
					isResultValid_o_next			=  1'b0;
					ss_next							=	IDLE;
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
			//	mul/div only
			extShF_op1_r	<=	'0;
			nlz_op1_r		<=	'0;
			extShF_op2_r	<=	'0;
			nlz_op2_r		<=	'0;
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
			//	mul/div only
			extShF_op1_r	<=	extShF_op1_wire;
			nlz_op1_r		<=	nlz_op1_wire;
			extShF_op2_r	<=	extShF_op2_wire;
			nlz_op2_r		<=	nlz_op2_wire;
		end
	end

//////////////////////////////////////////////////////////////////
// 			operands pre-processing	- combinational logic		//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		{s_op1_wire, e_op1_wire, f_op1_wire}										= FUNC_MUL_splitOperand(op1_i);
		{isInf_op1_wire,isDN_op1_wire,isZ_op1_wire,isSNAN_op1_wire,isQNAN_op1_wire}	= FUNC_MUL_checkOperand(op1_i);
		extE_op1_wire																= FUNC_MUL_extendExp(e_op1_wire, isDN_op1_wire);
		extF_op1_wire 																= FUNC_MUL_extendFrac(f_op1_wire, isDN_op1_wire, isZ_op1_wire);

		{s_op2_wire, e_op2_wire, f_op2_wire}										= FUNC_MUL_splitOperand(op2_i);
		{isInf_op2_wire,isDN_op2_wire,isZ_op2_wire,isSNAN_op2_wire,isQNAN_op2_wire}	= FUNC_MUL_checkOperand(op2_i);
		extE_op2_wire																= FUNC_MUL_extendExp(e_op2_wire, isDN_op2_wire);
		extF_op2_wire 																= FUNC_MUL_extendFrac(f_op2_wire, isDN_op2_wire, isZ_op2_wire);

		//	mul/div only
		nlz_op1_wire																= FUNC_MUL_numLeadingZeros(extF_op1_wire);
		nlz_op2_wire																= FUNC_MUL_numLeadingZeros(extF_op2_wire);
		extShF_op1_wire																= extF_op1_wire << nlz_op1_wire;
		extShF_op2_wire																= extF_op2_wire << nlz_op2_wire;
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
			f_res_postRnd	= FUNC_MUL_rndToNearestEven(f_res);
		else
			f_res_postRnd	= f_res[3+:LAMP_FLOAT_MUL_F_DW];
		if (isToRound)
			res_postRnd		= {s_res, e_res, f_res_postRnd};
		else
			res_postRnd		= {s_res, e_res, f_res[5+:LAMP_FLOAT_MUL_F_DW]};
	end

//////////////////////////////////////////////////////////////////
//						internal submodules						//
//////////////////////////////////////////////////////////////////

	lampFPU_EXP_mul
		lampFPU_EXP_mul0 (
			.clk					(clk),
			.rst					(rst),
			//	inputs
			.doMul_i				(doMul_r),
			.s_op1_i				(s_op1_r),
			.extShF_op1_i			(extShF_op1_r),
			.extE_op1_i				(extE_op1_r),
			.nlz_op1_i				(nlz_op1_r),
			.isZ_op1_i				(isZ_op1_r),
			.isInf_op1_i			(isInf_op1_r),
			.isSNAN_op1_i			(isSNAN_op1_r),
			.isQNAN_op1_i			(isQNAN_op1_r),
			.s_op2_i				(s_op2_r),
			.extShF_op2_i			(extShF_op2_r),
			.extE_op2_i				(extE_op2_r),
			.nlz_op2_i				(nlz_op2_r),
			.isZ_op2_i				(isZ_op2_r),
			.isInf_op2_i			(isInf_op2_r),
			.isSNAN_op2_i			(isSNAN_op2_r),
			.isQNAN_op2_i			(isQNAN_op2_r),
			//	outputs
			.s_res_o				(mul_s_res),
			.e_res_o				(mul_e_res),
			.f_res_o				(mul_f_res),
			.valid_o				(mul_valid),
			.isOverflow_o			(mul_isOverflow),
			.isUnderflow_o			(mul_isUnderflow),
			.isToRound_o			(mul_isToRound)
		);

endmodule
