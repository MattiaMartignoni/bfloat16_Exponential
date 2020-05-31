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

//some modifications has been made removing functions for operations not implemented to calculate the exponential function

package exponential_pkg;

	//////////////////////////////////////////////////
	//              	exponential             	//
	//////////////////////////////////////////////////

	parameter LAMP_FLOAT_DW		= 16;
	parameter LAMP_FLOAT_S_DW 	= 1;
	parameter LAMP_FLOAT_E_DW 	= 8;
	parameter LAMP_FLOAT_F_DW 	= 7;

	parameter LAMP_FLOAT_E_BIAS	= (2 ** (LAMP_FLOAT_E_DW - 1)) - 1;
	parameter LAMP_FLOAT_E_MAX	= (2 ** LAMP_FLOAT_E_DW) - 1;

	parameter INF				= 15'h7f80;
	parameter ZERO				= 15'h0000;
	parameter SNAN				= 15'h7fbf;
	parameter QNAN				= 15'h7fc0;

	//	used in TB only
	parameter PLUS_INF			= 16'h7f80;
	parameter MINUS_INF			= 16'hff80;
	parameter PLUS_ZERO			= 16'h0000;
	parameter MINUS_ZERO		= 16'h8000;

	parameter INF_E_F			= 15'b111111110000000; // w/o sign
	parameter SNAN_E_F			= 15'b111111110111111; // w/o sign
	parameter QNAN_E_F			= 15'b111111111000000; // w/o sign
	parameter ZERO_E_F			= 15'b000000000000000; // w/o sign

	typedef enum logic{
		FPU_RNDMODE_NEAREST		= 'd0,
		FPU_RNDMODE_TRUNCATE	= 'd1
	} rndModeFPU_t;

	typedef enum logic[1:0]{
		FPU_IDLE	= 2'd0,
		FPU_ADD		= 2'd1,
		FPU_SUB		= 2'd2,
		FPU_MUL		= 2'd3
	} opcodeFPU_t;

	//////////////////////////////////////////////////
	//				  multiplication		        //
	//////////////////////////////////////////////////

	parameter LAMP_FLOAT_MUL_DW	  = 25; //AVAILABLE OPTIONS: 20-26 CHANGE ALSO THE MARKED SECTION!!!
	parameter LAMP_FLOAT_MUL_S_DW =	1;
	parameter LAMP_FLOAT_MUL_E_DW =	8;
	parameter LAMP_FLOAT_MUL_F_DW =	LAMP_FLOAT_MUL_DW-LAMP_FLOAT_MUL_S_DW-LAMP_FLOAT_MUL_E_DW;

	parameter INF_MUL_E_F  = {8'b1, {LAMP_FLOAT_MUL_F_DW{1'b0}}};
	parameter SNAN_MUL_E_F = {8'b1, 1'b0, {LAMP_FLOAT_MUL_F_DW-1{1'b1}}};
	parameter QNAN_MUL_E_F = {9'b1, {LAMP_FLOAT_MUL_F_DW-1{1'b0}}};
	parameter ZERO_MUL_E_F = {LAMP_FLOAT_MUL_DW-1{1'b0}};


	//////////////////////////////////////////////////
	//					  taylor		            //
	//////////////////////////////////////////////////

	parameter LAMP_FLOAT_TAY_DW	  = 22; //AVAILABLE OPTIONS: 16, 20-26 CHANGE ALSO THE MARKED SECTION!!!
	parameter LAMP_FLOAT_TAY_S_DW = 1;
	parameter LAMP_FLOAT_TAY_E_DW = 8;
	parameter LAMP_FLOAT_TAY_F_DW = LAMP_FLOAT_TAY_DW-LAMP_FLOAT_TAY_S_DW-LAMP_FLOAT_TAY_E_DW;

	parameter TAYLOR_APPROX		  = 5;

	const logic [LAMP_FLOAT_TAY_DW-1:0] ONE_CONST = {1'b0, 8'd127, {LAMP_FLOAT_TAY_F_DW{1'b0}}}; //16'b0_0111_1111_0000_000;


	//////////////////////////////////////////////////
	//					 functions		            //
	//////////////////////////////////////////////////

	//////////////////////////////////////////////////
	//				exponential	functions			//
	//////////////////////////////////////////////////

	function automatic logic FUNC_op1_GT_op2(
			input [LAMP_FLOAT_F_DW+1-1:0] f_op1, input [LAMP_FLOAT_E_DW+1-1:0] e_op1,
			input [LAMP_FLOAT_F_DW+1-1:0] f_op2, input [LAMP_FLOAT_E_DW+1-1:0] e_op2
	);
		logic 		e_op1_GT_op2, e_op1_EQ_op2;
		logic 		f_op1_GT_op2;
		logic 		op1_GT_op2, op1_EQ_op2;

		e_op1_GT_op2 	= (e_op1 > e_op2);
		e_op1_EQ_op2 	= (e_op1 == e_op2);

		f_op1_GT_op2 	= (f_op1 > f_op2);

		op1_GT_op2		= e_op1_GT_op2 | (e_op1_EQ_op2 & f_op1_GT_op2);

		return	op1_GT_op2;
	endfunction


	function automatic logic [5-1:0] FUNC_checkOperand(input [LAMP_FLOAT_DW-1:0] op);
		logic [LAMP_FLOAT_S_DW-1:0] s_op;
		logic [LAMP_FLOAT_E_DW-1:0] e_op;
		logic [LAMP_FLOAT_F_DW-1:0] f_op;

		logic isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op;
		s_op = op[LAMP_FLOAT_DW-1];
		e_op = op[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW];
		f_op = op[LAMP_FLOAT_F_DW-1:0];

		// check deNorm (isDN), +/-inf (isInf), +/-zero (isZ), not a number (isSNaN, isQNaN)
		isInf_op 	= (&e_op) &  ~(|f_op); 				// E==0xFF &&	  f==0x0
		isDN_op 	= ~(|e_op) & (|f_op);					// E==0x0	 && 	f!=0x0
		isZ_op 		= ~(|op[LAMP_FLOAT_DW-2:0]);	// E==0x0	 && 	f==0x0
		isSNAN_op 	= (&e_op) & ~f_op[6] & (|f_op[5:0]);
		isQNAN_op 	= (&e_op) & f_op[6];

		return {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op};
	endfunction


	function automatic logic[4:0] FUNC_calcInfNanZeroResMul(
		input isZero_op1_i, isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
		input isZero_op2_i, isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
		);

		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isZeroRes, isInfRes, isNanRes, signRes;

		isValidRes	= (isZero_op1_i || isZero_op2_i || isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin //sign is not important, since a Nan remains a nan what-so-ever
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({isZero_op1_i, isZero_op2_i, isInf_op1_i,isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end
				4'b00_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b01_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end	//TODO check sign of zero res
				4'b01_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end	//Impossible
				4'b01_10: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1; 						end	//TODO check sign of zero res
				4'b01_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b10_01: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1;						 	end
				4'b10_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b11_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
			endcase
		end
		return {isValidRes, isZeroRes, isInfRes, isNanRes, signRes};
	endfunction


	function automatic logic[LAMP_FLOAT_F_DW-1:0] FUNC_rndToNearestEven(input [(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_F_DW+3/*G,R,S*/)-1:0] f_res_postNorm);

		localparam NUM_BIT_TO_RND	=	4;

		logic 								isAddOne;
		logic [(1+1+LAMP_FLOAT_F_DW+3)-1:0] tempF_1;
		logic [(1+1+LAMP_FLOAT_F_DW+3)-1:0] tempF;
		//
		// Rnd to nearest even
		//	X0.00 -> X0		|	X1.00 -> X1
		//	X0.01 -> X0		|	X1.01 -> X1
		//	X0.10 -> X0		|	X1.10 -> X1. +1
		//	X0.11 -> X1		|	X1.11 -> X1. +1
		//
		tempF_1 = f_res_postNorm;
		case(f_res_postNorm[3:1] /*3 bits X.G(S|R)*/ )
		3'b0_00:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_01:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_10:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_11:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_00:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_01:	begin tempF_1[3] = 1; 	isAddOne =0; end
		3'b1_10:	begin tempF_1[3] = 1;	isAddOne =1; end
		3'b1_11:	begin tempF_1[3] = 1;	isAddOne =1; end
		endcase

		// limit rnd to NUM_BIT_TO_RND LSBs of the f, truncate otherwise
		// this avoid another normalization step, if any
		if(&tempF_1[3+:NUM_BIT_TO_RND])
		tempF =	tempF_1 ;
		else
		tempF =	tempF_1 + (isAddOne<<3);

		return tempF[3+:LAMP_FLOAT_F_DW];
	endfunction

	//////////////////////////////////////////////////
	//			multiplication functions			//
	//////////////////////////////////////////////////

	function automatic logic [LAMP_FLOAT_MUL_S_DW+LAMP_FLOAT_MUL_E_DW+LAMP_FLOAT_MUL_F_DW-1:0] FUNC_MUL_splitOperand(input [LAMP_FLOAT_MUL_DW-1:0] op); //MODIFICARE I NOMI IN
		return op;
	endfunction


	function automatic logic [LAMP_FLOAT_MUL_E_DW+1-1:0] FUNC_MUL_extendExp(input [LAMP_FLOAT_MUL_E_DW-1:0] e_op, input isDN);
		return	{ 1'b0, e_op[7:1], (e_op[0] | isDN) };
	endfunction


	function automatic logic [LAMP_FLOAT_MUL_F_DW+1-1:0] FUNC_MUL_extendFrac(input [LAMP_FLOAT_MUL_F_DW-1:0] f_op, input isDN, input isZ);
		return	{ (~isDN & ~isZ), f_op};
	endfunction

	function automatic logic [$clog2(LAMP_FLOAT_MUL_F_DW+1)-1:0] FUNC_MUL_numLeadingZeros(input logic [(LAMP_FLOAT_MUL_F_DW+1)-1:0] f_i);
		casez(f_i)
			17'b1????????????????: return 'd0;
			17'b01???????????????: return 'd1;
			17'b001??????????????: return 'd2;
			17'b0001?????????????: return 'd3;
			17'b00001????????????: return 'd4;
			17'b000001???????????: return 'd5;
			17'b0000001??????????: return 'd6;
			17'b00000001?????????: return 'd7;
			17'b000000001????????: return 'd8;
			17'b0000000001???????: return 'd9;
			17'b00000000001??????: return 'd10;
			17'b000000000001?????: return 'd11;
			17'b0000000000001????: return 'd12;
			17'b00000000000001???: return 'd13;
			17'b000000000000001??: return 'd14;
			17'b0000000000000001?: return 'd15;
			17'b00000000000000001: return 'd16;
			17'b00000000000000000: return 'd0; // zero result
		endcase
	endfunction

	function automatic logic [LAMP_FLOAT_MUL_F_DW-1:0] FUNC_MUL_shiftMantissa(input logic [LAMP_FLOAT_MUL_F_DW-1:0] mantissa, input logic [$clog2(LAMP_FLOAT_MUL_F_DW+1)-1:0] shCount);
		case(shCount)
		'd0:	return {mantissa[LAMP_FLOAT_MUL_F_DW-2:0], 1'b0};
		'd1:	return {mantissa[LAMP_FLOAT_MUL_F_DW-3:0], 2'b0};
		'd2:	return {mantissa[LAMP_FLOAT_MUL_F_DW-4:0], 3'b0};
		'd3:	return {mantissa[LAMP_FLOAT_MUL_F_DW-5:0], 4'b0};
		'd4:	return {mantissa[LAMP_FLOAT_MUL_F_DW-6:0], 5'b0};
		'd5:	return {mantissa[LAMP_FLOAT_MUL_F_DW-7:0], 6'b0};
		'd6:	return {mantissa[LAMP_FLOAT_MUL_F_DW-8:0], 7'b0};
		'd7:	return {mantissa[LAMP_FLOAT_MUL_F_DW-9:0], 8'b0};
		'd8:	return {mantissa[LAMP_FLOAT_MUL_F_DW-10:0], 9'b0};
		'd9:	return {mantissa[LAMP_FLOAT_MUL_F_DW-11:0], 10'b0};
		'd10:	return {mantissa[LAMP_FLOAT_MUL_F_DW-12:0], 11'b0};
		'd11:	return {mantissa[LAMP_FLOAT_MUL_F_DW-13:0], 12'b0};
		'd12:	return {mantissa[LAMP_FLOAT_MUL_F_DW-14:0], 13'b0};
		'd13:	return {mantissa[LAMP_FLOAT_MUL_F_DW-15:0], 14'b0};
		'd14:	return {mantissa[LAMP_FLOAT_MUL_F_DW-16:0], 15'b0};
		'd15:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};
		endcase
	endfunction

	function automatic logic [5-1:0] FUNC_MUL_checkOperand(input [LAMP_FLOAT_MUL_DW-1:0] op);
		logic [LAMP_FLOAT_MUL_S_DW-1:0] s_op;
		logic [LAMP_FLOAT_MUL_E_DW-1:0] e_op;
		logic [LAMP_FLOAT_MUL_F_DW-1:0] f_op;

		logic isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op;
		s_op = op[LAMP_FLOAT_MUL_DW-1];
		e_op = op[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW];
		f_op = op[LAMP_FLOAT_MUL_F_DW-1:0];

		// check deNorm (isDN), +/-inf (isInf), +/-zero (isZ), not a number (isSNaN, isQNaN)
		isInf_op 	= (&e_op) &  ~(|f_op); 				// E==0xFF &&	  f==0x0
		isDN_op 	= ~(|e_op) & (|f_op);					// E==0x0	 && 	f!=0x0
		isZ_op 		= ~(|op[LAMP_FLOAT_MUL_DW-2:0]);	// E==0x0	 && 	f==0x0
		isSNAN_op 	= (&e_op) & ~f_op[6] & (|f_op[5:0]);
		isQNAN_op 	= (&e_op) & f_op[6];

		return {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op};
	endfunction


	function automatic logic[LAMP_FLOAT_MUL_F_DW-1:0] FUNC_MUL_rndToNearestEven(input [(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_MUL_F_DW+3/*G,R,S*/)-1:0] f_res_postNorm);

		localparam NUM_BIT_TO_RND	=	4;

		logic 									isAddOne;
		logic [(1+1+LAMP_FLOAT_MUL_F_DW+3)-1:0]	tempF_1;
		logic [(1+1+LAMP_FLOAT_MUL_F_DW+3)-1:0] tempF;
		//
		// Rnd to nearest even
		//	X0.00 -> X0		|	X1.00 -> X1
		//	X0.01 -> X0		|	X1.01 -> X1
		//	X0.10 -> X0		|	X1.10 -> X1. +1
		//	X0.11 -> X1		|	X1.11 -> X1. +1
		//
		tempF_1 = f_res_postNorm;
		case(f_res_postNorm[3:1] /*3 bits X.G(S|R)*/ )
		3'b0_00:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_01:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_10:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_11:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_00:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_01:	begin tempF_1[3] = 1; 	isAddOne =0; end
		3'b1_10:	begin tempF_1[3] = 1;	isAddOne =1; end
		3'b1_11:	begin tempF_1[3] = 1;	isAddOne =1; end
		endcase

		// limit rnd to NUM_BIT_TO_RND LSBs of the f, truncate otherwise
		// this avoid another normalization step, if any
		if(&tempF_1[3+:NUM_BIT_TO_RND])
		tempF =	tempF_1 ;
		else
		tempF =	tempF_1 + (isAddOne<<3);

		return tempF[3+:LAMP_FLOAT_MUL_F_DW];
	endfunction


	//////////////////////////////////////////////////
	//				taylor functions				//
	//////////////////////////////////////////////////

	function automatic logic [LAMP_FLOAT_TAY_S_DW+LAMP_FLOAT_TAY_E_DW+LAMP_FLOAT_TAY_F_DW-1:0] FUNC_TAY_splitOperand(input [LAMP_FLOAT_TAY_DW-1:0] op);
		return op;
	endfunction


	function automatic logic [LAMP_FLOAT_TAY_E_DW+1-1:0] FUNC_TAY_extendExp(input [LAMP_FLOAT_TAY_E_DW-1:0] e_op, input isDN);
		return	{ 1'b0, e_op[7:1], (e_op[0] | isDN) };
	endfunction


	function automatic logic [LAMP_FLOAT_TAY_F_DW+1-1:0] FUNC_TAY_extendFrac(input [LAMP_FLOAT_TAY_F_DW-1:0] f_op, input isDN, input isZ);
		return	{ (~isDN & ~isZ), f_op};
	endfunction


	function automatic logic FUNC_TAY_op1_GT_op2(
			input [LAMP_FLOAT_TAY_F_DW+1-1:0] f_op1, input [LAMP_FLOAT_TAY_E_DW+1-1:0] e_op1,
			input [LAMP_FLOAT_TAY_F_DW+1-1:0] f_op2, input [LAMP_FLOAT_TAY_E_DW+1-1:0] e_op2
	);
		logic 		e_op1_GT_op2, e_op1_EQ_op2;
		logic 		f_op1_GT_op2;
		logic 		op1_GT_op2, op1_EQ_op2;

		e_op1_GT_op2 	= (e_op1 > e_op2);
		e_op1_EQ_op2 	= (e_op1 == e_op2);

		f_op1_GT_op2 	= (f_op1 > f_op2);

		op1_GT_op2		= e_op1_GT_op2 | (e_op1_EQ_op2 & f_op1_GT_op2);

		return	op1_GT_op2;
	endfunction

	function automatic logic [LAMP_FLOAT_TAY_DW-1:0] FUNC_lut_factorial(input [2:0] counter);
		case (counter)
            3'd0 : return 'b0__0111_1110__0000_0000_0000_0; //1/(2!)= 1/2=    0,5
            3'd1 : return 'b0__0111_1100__0101_0101_0101_1; //1/(3!)= 1/6=    0.166666...  approx 0.166687011719
            3'd2 : return 'b0__0111_1010__0101_0101_0101_1; //1/(4!)= 1/24=   0.041666...  approx 0.0416717529297
            3'd3 : return 'b0__0111_1000__0001_0001_0001_0; //1/(5!)= 1/120=  0.008333...  approx 0.00833511352539
            3'd4 : return 'b0__0111_0101__0110_1100_0001_1; //1/(6!)= 1/720=  0.001388...  approx 0.00138902664185
            3'd5 : return 'b0__0111_0010__1010_0000_0001_1; //1/(7!)= 1/5040= 0.0001984127 approx 0.000198423862457
            default : return 'b0__0000_0000__0000_0000_0000_0;
		endcase
	endfunction


	function automatic logic [$clog2(1+1+LAMP_FLOAT_TAY_F_DW+3)-1:0] FUNC_TAY_AddSubPostNorm_numLeadingZeros(input [1+1+LAMP_FLOAT_TAY_F_DW+3-1:0] f_initial_res);
		casez(f_initial_res)
			 18'b1?????????????????: return  'd0;
             18'b01????????????????: return  'd0;
             18'b001???????????????: return  'd1;
             18'b0001??????????????: return  'd2;
             18'b00001?????????????: return  'd3;
             18'b000001????????????: return  'd4;
             18'b0000001???????????: return  'd5;
             18'b00000001??????????: return  'd6;
             18'b000000001?????????: return  'd7;
             18'b0000000001????????: return  'd8;
             18'b00000000001???????: return  'd9;
             18'b000000000001??????: return  'd10;
             18'b0000000000001?????: return  'd11;
             18'b00000000000001????: return  'd12;
             18'b000000000000001???: return  'd13;
             18'b0000000000000001??: return  'd14;
             18'b00000000000000001?: return  'd15;
             18'b000000000000000001: return  'd16;
             18'b000000000000000000: return  'd0; // zero result
		endcase
	endfunction


	function automatic logic [$clog2(LAMP_FLOAT_TAY_F_DW+1)-1:0] FUNC_TAY_numLeadingZeros(input logic [(LAMP_FLOAT_TAY_F_DW+1)-1:0] f_i);
		casez(f_i)
            14'b1?????????????: return 'd0;
            14'b01????????????: return 'd1;
            14'b001???????????: return 'd2;
            14'b0001??????????: return 'd3;
            14'b00001?????????: return 'd4;
            14'b000001????????: return 'd5;
            14'b0000001???????: return 'd6;
            14'b00000001??????: return 'd7;
            14'b000000001?????: return 'd8;
            14'b0000000001????: return 'd9;
            14'b00000000001???: return 'd10;
            14'b000000000001??: return 'd11;
            14'b0000000000001?: return 'd12;
            14'b00000000000001: return 'd13;
            14'b00000000000000: return 'd0; // zero result
		endcase
	endfunction


	function automatic logic FUNC_TAY_addsub_calcStickyBit(input logic [(1+LAMP_FLOAT_TAY_F_DW+3)-1:0] f_i, input logic [(LAMP_FLOAT_TAY_E_DW+1)-1:0] num_shr_i);
		case(num_shr_i)
             5'd0  :		return 1'b0;		// no right shift -> 0 sticky
             5'd1  :        return 1'b0;        // two added zero bits G,R
             5'd2  :        return 1'b0;        // two added zero bits G,R
             5'd3  :        return f_i[3];
             5'd4  :        return |f_i[3+:1];
             5'd5  :        return |f_i[3+:2];
             5'd6  :        return |f_i[3+:3];
             5'd7  :        return |f_i[3+:4];
             5'd8  :        return |f_i[3+:5];
             5'd9  :        return |f_i[3+:6];
             5'd10 :        return |f_i[3+:7];
             5'd11 :        return |f_i[3+:8];
             5'd12 :        return |f_i[3+:9];
             5'd13 :        return |f_i[3+:10];
             5'd14 :        return |f_i[3+:11];
             5'd15 :        return |f_i[3+:12];
             default:    return |f_i[3+:13];
		endcase
	endfunction

	function automatic logic [5-1:0] FUNC_TAY_checkOperand(input [LAMP_FLOAT_TAY_DW-1:0] op);
		logic [LAMP_FLOAT_TAY_S_DW-1:0] s_op;
		logic [LAMP_FLOAT_TAY_E_DW-1:0] e_op;
		logic [LAMP_FLOAT_TAY_F_DW-1:0] f_op;

		logic isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op;
		s_op = op[LAMP_FLOAT_TAY_DW-1];
		e_op = op[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW];
		f_op = op[LAMP_FLOAT_TAY_F_DW-1:0];

		// check deNorm (isDN), +/-inf (isInf), +/-zero (isZ), not a number (isSNaN, isQNaN)
		isInf_op 	= (&e_op) &  ~(|f_op); 				// E==0xFF &&	  f==0x0
		isDN_op 	= ~(|e_op) & (|f_op);					// E==0x0	 && 	f!=0x0
		isZ_op 		= ~(|op[LAMP_FLOAT_TAY_DW-2:0]);	// E==0x0	 && 	f==0x0
		isSNAN_op 	= (&e_op) & ~f_op[6] & (|f_op[5:0]);
		isQNAN_op 	= (&e_op) & f_op[6];

		return {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op};
	endfunction


	function automatic logic[LAMP_FLOAT_TAY_F_DW-1:0] FUNC_TAY_rndToNearestEven(input [(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_TAY_F_DW+3/*G,R,S*/)-1:0] f_res_postNorm);

		localparam NUM_BIT_TO_RND	=	4;

		logic 								isAddOne;
		logic [(1+1+LAMP_FLOAT_TAY_F_DW+3)-1:0] tempF_1;
		logic [(1+1+LAMP_FLOAT_TAY_F_DW+3)-1:0] tempF;
		//
		// Rnd to nearest even
		//	X0.00 -> X0		|	X1.00 -> X1
		//	X0.01 -> X0		|	X1.01 -> X1
		//	X0.10 -> X0		|	X1.10 -> X1. +1
		//	X0.11 -> X1		|	X1.11 -> X1. +1
		//
		tempF_1 = f_res_postNorm;
		case(f_res_postNorm[3:1] /*3 bits X.G(S|R)*/ )
		3'b0_00:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_01:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_10:	begin tempF_1[3] = 0;	isAddOne =0; end
		3'b0_11:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_00:	begin tempF_1[3] = 1;	isAddOne =0; end
		3'b1_01:	begin tempF_1[3] = 1; 	isAddOne =0; end
		3'b1_10:	begin tempF_1[3] = 1;	isAddOne =1; end
		3'b1_11:	begin tempF_1[3] = 1;	isAddOne =1; end
		endcase

		// limit rnd to NUM_BIT_TO_RND LSBs of the f, truncate otherwise
		// this avoid another normalization step, if any
		if(&tempF_1[3+:NUM_BIT_TO_RND])
		tempF =	tempF_1 ;
		else
		tempF =	tempF_1 + (isAddOne<<3);

		return tempF[3+:LAMP_FLOAT_TAY_F_DW];
	endfunction


	function automatic logic[3:0] FUNC_TAY_calcInfNanResAddSub(
		input isOpSub_i,
		input isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
		input isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
		);

		logic realOp2_sign;
		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isInfRes, isNanRes, signRes;
		realOp2_sign 	= sign_op2_i ^ isOpSub_i;

		isValidRes 		= (isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin //sign is not important, since a Nan remains a nan what-so-ever
			isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({sign_op1_i, isInf_op1_i, realOp2_sign, isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b00_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b00_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b00_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b01_00: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_10: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b01_11: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
				4'b10_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b10_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
				4'b10_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
				4'b10_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_00: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_01: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
				4'b11_10: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
				4'b11_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
			endcase
		end
		return {isValidRes, isInfRes, isNanRes, signRes};
	endfunction


	function automatic logic[4:0] FUNC_TAY_calcInfNanZeroResMul(
		input isZero_op1_i, isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
		input isZero_op2_i, isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
		);

		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

		logic isValidRes, isZeroRes, isInfRes, isNanRes, signRes;

		isValidRes	= (isZero_op1_i || isZero_op2_i || isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
		if (isNan_op1)
		begin //sign is not important, since a Nan remains a nan what-so-ever
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
		end
		else if (isNan_op2)
		begin
			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
		end
		else // both are not NaN
		begin
			case({isZero_op1_i, isZero_op2_i, isInf_op1_i,isInf_op2_i})
				4'b00_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end
				4'b00_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b00_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b01_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end	//TODO check sign of zero res
				4'b01_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end	//Impossible
				4'b01_10: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1; 						end	//TODO check sign of zero res
				4'b01_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b10_01: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1;						 	end
				4'b10_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b10_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
				4'b11_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
				4'b11_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
			endcase
		end
		return {isValidRes, isZeroRes, isInfRes, isNanRes, signRes};
	endfunction

endpackage
