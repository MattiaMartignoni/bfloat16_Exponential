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

//some modifications has been made to make this module perform the taylor approximation using only add-sub and mul submodules
//also the package has been modified for this purpose

module lampFPU_TAY_top (
	clk, rst,
	flush_i, padv_i,
	valid_i, rndMode_i, approxLevel_i, op_i,
	result_o, isResultValid_o, isReady_o
);

import exponential_pkg::*;

input									clk;
input									rst;
input									flush_i;		// Flush the FPU invalidating the current operation
input									padv_i;			// Pipeline advance signal: accept new operation
input	logic							valid_i;		//<<< makes only one operation, no need of opcode
input	rndModeFPU_t					rndMode_i;
input 			[2:0]					approxLevel_i;	//<<< level of approxumation can be givenat input (in pkg the range is 1-7)
input			[LAMP_FLOAT_TAY_DW-1:0]		op_i;			//<<< has only one input

output	logic	[LAMP_FLOAT_TAY_DW-1:0]		result_o;
output	logic							isResultValid_o;
output	logic							isReady_o;

// INPUT wires: to drive registered input
	logic 									flush_r, flush_r_next;
	logic									valid_r, valid_r_next;
	rndModeFPU_t							rndMode_r, rndMode_r_next;
	logic	[2:0]							approxLevel_r, approxLevel_r_next;

// OUTPUT wires: to drive registered output
	logic	[LAMP_FLOAT_TAY_DW-1:0]				result_o_next;
	logic									isResultValid_o_next;



	//	add/sub outputs
	logic									addsub_s_res;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0]			addsub_e_res;
	logic	[LAMP_FLOAT_TAY_F_DW+5-1:0]			addsub_f_res;
	logic									addsub_valid;
	logic									addsub_isOverflow;
	logic									addsub_isUnderflow;
	logic									addsub_isToRound;

	//	mul outputs
	logic									mul_s_res;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0]			mul_e_res;
	logic	[LAMP_FLOAT_TAY_F_DW+5-1:0]			mul_f_res;
	logic									mul_valid;
	logic									mul_isOverflow;
	logic									mul_isUnderflow;
	logic									mul_isToRound;
	//
	logic									doAddSub_r, doAddSub_r_next;
	logic									isOpSub_r, isOpSub_r_next;
	logic									doMul_r, doMul_next;

	// FUs results and valid bits
	logic	[LAMP_FLOAT_TAY_DW-1:0]				res;
	logic									isResValid;

	//	op1
	logic	[LAMP_FLOAT_TAY_S_DW-1:0] 			s_op1_r;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0] 			e_op1_r;
	logic	[LAMP_FLOAT_TAY_F_DW-1:0] 			f_op1_r;
	logic	[(LAMP_FLOAT_TAY_F_DW+1)-1:0] 		extF_op1_r;
	logic	[(LAMP_FLOAT_TAY_E_DW+1)-1:0] 		extE_op1_r;
	logic									isInf_op1_r;
	logic									isZ_op1_r;
	logic									isSNAN_op1_r;
	logic									isQNAN_op1_r;
	//	op2
	logic	[LAMP_FLOAT_TAY_S_DW-1:0] 			s_op2_r;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0] 			e_op2_r;
	logic	[LAMP_FLOAT_TAY_F_DW-1:0] 			f_op2_r;
	logic	[(LAMP_FLOAT_TAY_F_DW+1)-1:0] 		extF_op2_r;
	logic	[(LAMP_FLOAT_TAY_E_DW+1)-1:0] 		extE_op2_r;
	logic									isInf_op2_r;
	logic									isZ_op2_r;
	logic									isSNAN_op2_r;
	logic									isQNAN_op2_r;
	//	add/sub only
	logic									op1_GT_op2_r;
	logic	[LAMP_FLOAT_TAY_E_DW+1-1 : 0] 		e_diff_r;
	//	mul/div only
	logic	[(1+LAMP_FLOAT_TAY_F_DW)-1:0] 		extShF_op1_r;
	logic	[$clog2(1+LAMP_FLOAT_TAY_F_DW)-1:0]	nlz_op1_r;
	logic	[(1+LAMP_FLOAT_TAY_F_DW)-1:0] 		extShF_op2_r;
	logic	[$clog2(1+LAMP_FLOAT_TAY_F_DW)-1:0]	nlz_op2_r;

	//	pre-operation wires/regs
	//	op1
	logic	[LAMP_FLOAT_TAY_S_DW-1:0] 			s_op1_wire;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0] 			e_op1_wire;
	logic	[LAMP_FLOAT_TAY_F_DW-1:0] 			f_op1_wire;
	logic	[(LAMP_FLOAT_TAY_F_DW+1)-1:0] 		extF_op1_wire;
	logic	[(LAMP_FLOAT_TAY_E_DW+1)-1:0] 		extE_op1_wire;
	logic									isDN_op1_wire;
	logic									isZ_op1_wire;
	logic									isInf_op1_wire;
	logic									isSNAN_op1_wire;
	logic									isQNAN_op1_wire;
	//	op2
	logic	[LAMP_FLOAT_TAY_S_DW-1:0] 			s_op2_wire;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0] 			e_op2_wire;
	logic	[LAMP_FLOAT_TAY_F_DW-1:0] 			f_op2_wire;
	logic	[(LAMP_FLOAT_TAY_F_DW+1)-1:0] 		extF_op2_wire;
	logic	[(LAMP_FLOAT_TAY_E_DW+1)-1:0] 		extE_op2_wire;
	logic									isDN_op2_wire;
	logic									isZ_op2_wire;
	logic									isInf_op2_wire;
	logic									isSNAN_op2_wire;
	logic									isQNAN_op2_wire;
	//	add/sub only
	logic									op1_GT_op2_wire;
	logic	[LAMP_FLOAT_TAY_E_DW+1-1 : 0] 		e_diff_wire;
	//	mul/div only
	logic	[(1+LAMP_FLOAT_TAY_F_DW)-1:0] 		extShF_op1_wire;
	logic	[$clog2(1+LAMP_FLOAT_TAY_F_DW)-1:0]	nlz_op1_wire;
	logic	[(1+LAMP_FLOAT_TAY_F_DW)-1:0] 		extShF_op2_wire;
	logic	[$clog2(1+LAMP_FLOAT_TAY_F_DW)-1:0]	nlz_op2_wire;

	//	pre-rounding wires/regs
	logic									s_res;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0]			e_res;
	logic	[LAMP_FLOAT_TAY_F_DW+5-1:0]			f_res;
	logic									isOverflow;
	logic									isUnderflow;
	logic									isToRound;

	//	post-rounding wires/regs
	logic									s_res_postRnd;
	logic	[LAMP_FLOAT_TAY_F_DW-1:0]			f_res_postRnd;
	logic	[LAMP_FLOAT_TAY_E_DW-1:0]			e_res_postRnd;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				res_postRnd;
	logic									isOverflow_postRnd;
	logic									isUnderflow_postRnd;

// ALGORITHM's logic
	logic	[LAMP_FLOAT_TAY_DW-1:0]				op1_i;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				op2_i;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				pwr_acc, pwr_acc_next;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				sum_acc, sum_acc_next;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				x, x_next;
	logic	[LAMP_FLOAT_TAY_DW-1:0]				factorial_r, factorial_wire;
	logic									isOpMul_r, isOpMul_r_next;
	logic	[2:0]							iteration, iteration_next;

//////////////////////////////////////////////////////////////////
// 							state enum							//
//////////////////////////////////////////////////////////////////

	typedef enum logic [1:0]
	{
		IDLE	= 'd0,
		ITER	= 'd1,
		DONE	= 'd2
	}	ssFpuTop_t;

	ssFpuTop_t 	ss, ss_next;

	typedef enum logic[1:0]
	{
		PWR		= 'd0,
		FACT	= 'd1,
		SUM		= 'd2
	} iterssexpTop_t;

	iterssexpTop_t	iter_ss, iter_ss_next;

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
			doMul_r				<=	1'b0;
			flush_r				<=	1'b0;
			valid_r				<=	1'b0;
			rndMode_r			<=	FPU_RNDMODE_NEAREST;
			approxLevel_r		<=	'd0;
		//output
			result_o			<=	'0;
			isResultValid_o		<=	1'b0;
			//algorithm
			iteration			<=	'd0;
		end
		else
		begin
			ss					<=	ss_next;
			iter_ss				<=	iter_ss_next;
		//input
			doAddSub_r			<=	doAddSub_r_next;
			isOpSub_r			<=	isOpSub_r_next;
			doMul_r				<=	doMul_next;
			flush_r				<=	flush_r_next;
			valid_r				<=	valid_r_next;
			rndMode_r			<=	rndMode_r_next;
			approxLevel_r		<= approxLevel_r_next;
		//output
			result_o			<=	result_o_next;
			isResultValid_o		<=	isResultValid_o_next;
		//algorithm
			pwr_acc				<=	pwr_acc_next;
			sum_acc				<=	sum_acc_next;
			x					<=	x_next;
			isOpMul_r			<=	isOpMul_r_next;
			iteration			<=	iteration_next;
		end
	end

//////////////////////////////////////////////////////////////////
// 						combinational logic						//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		ss_next					=	ss;
		iter_ss_next			=	iter_ss;
		doAddSub_r_next			=	1'b0;
		isOpSub_r_next			=	1'b0;
		doMul_next				=	1'b0;

		flush_r_next			=	flush_r;
		valid_r_next			=	valid_r;
		rndMode_r_next			=	rndMode_r;
		approxLevel_r_next		=	approxLevel_r;

		result_o_next			=	result_o;
		isResultValid_o_next	=	isResultValid_o;

		pwr_acc_next			=	pwr_acc;
		sum_acc_next			=	sum_acc;
		x_next					=	x;
		isOpMul_r_next			=	isOpMul_r;
		iteration_next			=	iteration;

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

				if (valid_i && !flush_i)
				begin
					ss_next				=	ITER;
					iter_ss_next		=	PWR;

					op1_i 				=	ONE_CONST;	// 1
					op2_i 				=	op_i;		// X

					doAddSub_r_next		=	1'b1;		// +
					isOpSub_r_next		=	1'b0;
					isOpMul_r_next		=	1'b0;

					x_next 				=	op_i;
					pwr_acc_next		=	op_i;

					flush_r_next		=	'0;
					rndMode_r_next		=	rndMode_i;
					approxLevel_r_next	=	approxLevel_i;
					iteration_next		=	'd1;
				end
			end

			ITER:
			begin
				if (isOpMul_r)
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
				else
				begin
					s_res						=	addsub_s_res;
					e_res						=	addsub_e_res;
					f_res						=	addsub_f_res;
					isOverflow					=	addsub_isOverflow;
					isUnderflow					=	addsub_isUnderflow;
					isToRound					=	addsub_isToRound;

					res							=	res_postRnd;
					isResValid					=	addsub_valid;
				end

				if (isResValid)
				begin
					if(iteration == approxLevel_r)
					begin
						result_o_next					=	res;
						isResultValid_o_next			=	1'b1;
						ss_next							=	DONE;
					end
					else
					begin
						case (iter_ss)
							PWR:
							begin
								sum_acc_next	=	res;
								op1_i			=	x;			// X
								op2_i			=	pwr_acc;	// X^i
								doMul_next		=	1'b1;		// *
								isOpMul_r_next	=	1'b1;
								iter_ss_next	=	FACT;
							end
							FACT:
							begin
								pwr_acc_next	=	res;
								op1_i			=	res;			// X^(i+1)
								op2_i			=	factorial_r;	// 1/(i+1)!
								doMul_next		=	1'b1;			// *
								isOpMul_r_next	=	1'b1;
								iter_ss_next	=	SUM;
							end
							SUM:
							begin
								op1_i			=	res;		// X^(i+1)/(i+1)!
								op2_i			=	sum_acc;	// previous iterations result (1 + x + (X^2)/2! + (X^3)/3! + ...)
								doAddSub_r_next	=	1'b1;		// +
								isOpSub_r_next	=	1'b0;
								isOpMul_r_next	=	1'b0;
								iter_ss_next	=	PWR;
								iteration_next	=	iteration + 'd1;
							end
						endcase
					end
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
			//	add/sub only
			op1_GT_op2_r	<=	'0;
			e_diff_r		<=	'0;
			//	mul/div only
			extShF_op1_r	<=	'0;
			nlz_op1_r		<=	'0;
			extShF_op2_r	<=	'0;
			nlz_op2_r		<=	'0;
			//	exp only
			factorial_r		<=	'0;
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
			//	mul/div only
			extShF_op1_r	<=	extShF_op1_wire;
			nlz_op1_r		<=	nlz_op1_wire;
			extShF_op2_r	<=	extShF_op2_wire;
			nlz_op2_r		<=	nlz_op2_wire;
			//	exp only
			factorial_r		<=	factorial_wire;
		end
	end

//////////////////////////////////////////////////////////////////
// 			operands pre-processing	- combinational logic		//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		{s_op1_wire, e_op1_wire, f_op1_wire}										= FUNC_TAY_splitOperand(op1_i);
		{isInf_op1_wire,isDN_op1_wire,isZ_op1_wire,isSNAN_op1_wire,isQNAN_op1_wire}	= FUNC_TAY_checkOperand(op1_i);
		extE_op1_wire																= FUNC_TAY_extendExp(e_op1_wire, isDN_op1_wire);
		extF_op1_wire 																= FUNC_TAY_extendFrac(f_op1_wire, isDN_op1_wire, isZ_op1_wire);

		{s_op2_wire, e_op2_wire, f_op2_wire}										= FUNC_TAY_splitOperand(op2_i);
		{isInf_op2_wire,isDN_op2_wire,isZ_op2_wire,isSNAN_op2_wire,isQNAN_op2_wire}	= FUNC_TAY_checkOperand(op2_i);
		extE_op2_wire																= FUNC_TAY_extendExp(e_op2_wire, isDN_op2_wire);
		extF_op2_wire 																= FUNC_TAY_extendFrac(f_op2_wire, isDN_op2_wire, isZ_op2_wire);

		//	add/sub only
		op1_GT_op2_wire																= FUNC_TAY_op1_GT_op2(extF_op1_wire, extE_op1_wire, extF_op2_wire, extE_op2_wire);
		e_diff_wire																	= op1_GT_op2_wire ? (extE_op1_wire - extE_op2_wire) : (extE_op2_wire - extE_op1_wire);

		//	mul/div only
		nlz_op1_wire																= FUNC_TAY_numLeadingZeros(extF_op1_wire);
		nlz_op2_wire																= FUNC_TAY_numLeadingZeros(extF_op2_wire);
		extShF_op1_wire																= extF_op1_wire << nlz_op1_wire;
		extShF_op2_wire																= extF_op2_wire << nlz_op2_wire;

		//	exp only
		factorial_wire																= FUNC_lut_factorial(iteration - 'd1);
	end

	// NOTE: fpu ready signal that makes the pipeline to advance.
	// It is simple and plain combinational logic: this should require
	// some cpu-side optimizations to improve the overall system timing
	// in the future. The entire advancing mechanism should be re-designed
	// from scratch

	assign isReady_o = (ss == IDLE) | isResultValid_o;//??? not sure why first condition

//////////////////////////////////////////////////////////////////
// 				float rounding - combinational logic			//
//////////////////////////////////////////////////////////////////

	always_comb
	begin
		if (rndMode_r == FPU_RNDMODE_NEAREST)
			f_res_postRnd	= FUNC_TAY_rndToNearestEven(f_res);
		else
			f_res_postRnd	= f_res[3+:LAMP_FLOAT_TAY_F_DW];
		if (isToRound)
			res_postRnd		= {s_res, e_res, f_res_postRnd};
		else
			res_postRnd		= {s_res, e_res, f_res[5+:LAMP_FLOAT_TAY_F_DW]};
	end

//////////////////////////////////////////////////////////////////
//						internal submodules						//
//////////////////////////////////////////////////////////////////

	lampFPU_TAY_addsub
		lampFPU_TAY_addsub0(
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

	lampFPU_TAY_mul
		lampFPU_TAY_mul0 (
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
