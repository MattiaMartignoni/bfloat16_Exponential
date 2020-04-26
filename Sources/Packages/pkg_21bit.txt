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

package lampFPU_XXX_pkg;

	parameter LAMP_FLOAT_DW		=	21;
	parameter LAMP_FLOAT_S_DW 	=	1;
	parameter LAMP_FLOAT_E_DW 	=	8;
	parameter LAMP_FLOAT_F_DW 	=	12;

	parameter LAMP_FLOAT_E_BIAS	=	(2 ** (LAMP_FLOAT_E_DW - 1)) - 1;
	parameter LAMP_FLOAT_E_MAX	=	(2 ** LAMP_FLOAT_E_DW) - 1;

	// contants for Cordic algorithm
	parameter CORDIC_ITERATIONS		= 13;
	const logic [LAMP_FLOAT_DW-1:0] X0 = 21'b0__0111_1111__0011_0100_1000; //should be 1.20513635844646... and is rounded to 1.205078125 to use only 11 bits (reciproco)
	const logic [LAMP_FLOAT_DW-1:0] Y0 = 21'b0__0000_0000__0000_0000_0000;
	const logic [LAMP_FLOAT_DW-1:0] Z0 = 21'b0__0000_0000__0000_0000_0000;
	const logic 										D0 = 1'b0;

	// constants for Taylor
	parameter TAYLOR_APPROX			= 'd4;				//level of opprox. of taylor series, referst to the max power of x (min 1, max 6 -> 1+x + (x^2)/(2!) + (x^3)/(3!) + ...
	const logic [LAMP_FLOAT_DW-1:0] ONE_CONST = 21'b0_0111_1111_0000_0000_0000;

	parameter INF				 =	20'b1111_1111__0000_0000_0000;
	parameter ZERO				=	20'b0000_0000__0000_0000_0000;
	parameter SNAN				=	20'b1111_1111__0111_1111_1111;
	parameter QNAN				=	20'b1111_1111__1000_0000_0000;

	//	used in TB only
	// parameter PLUS_INF			=	16'h7f80;
	// parameter MINUS_INF			=	16'hff80;
	// parameter PLUS_ZERO			=	16'h0000;
	// parameter MINUS_ZERO		=	16'h8000;

	parameter INF_E_F				=	20'b11111111000000000000; // w/o sign
	parameter SNAN_E_F			=	20'b11111111011111111111; // w/o sign
	parameter QNAN_E_F			=	20'b11111111100000000000; // w/o sign
	parameter ZERO_E_F			=	20'b00000000000000000000; // w/o sign

	typedef enum logic
	{
		FPU_RNDMODE_NEAREST		=	'd0,
		FPU_RNDMODE_TRUNCATE	=	'd1
	} rndModeFPU_t;

	typedef enum logic[1:0]
	{
		FPU_IDLE	= 2'd0,

		FPU_ADD		= 2'd1,
		FPU_SUB		= 2'd2,
		FPU_MUL		= 2'd3
	} opcodeFPU_t;

	function automatic logic [LAMP_FLOAT_S_DW+LAMP_FLOAT_E_DW+LAMP_FLOAT_F_DW-1:0] FUNC_splitOperand(input [LAMP_FLOAT_DW-1:0] op);
		return op;
	endfunction

	function automatic logic [LAMP_FLOAT_E_DW+1-1:0] FUNC_extendExp(input [LAMP_FLOAT_E_DW-1:0] e_op, input isDN);
		return	{ 1'b0, e_op[7:1], (e_op[0] | isDN) };
	endfunction

	function automatic logic [LAMP_FLOAT_F_DW+1-1:0] FUNC_extendFrac(input [LAMP_FLOAT_F_DW-1:0] f_op, input isDN, input isZ);
		return	{ (~isDN & ~isZ), f_op};
	endfunction

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

		function automatic logic [LAMP_FLOAT_DW-1:0] FUNC_lut_factorial(input [2:0] counter);

			case (counter)
				3'd0 : return 'b0__0111_1110__0000_0000_0000; //1/(2!)= 1/2=    0,5
				3'd1 : return 'b0__0111_1100__0101_0101_0101; //1/(3!)= 1/6=    0.166666...  approx 0.166687011719
				3'd2 : return 'b0__0111_1010__0101_0101_0101; //1/(4!)= 1/24=   0.041666...  approx 0.0416717529297
				3'd3 : return 'b0__0111_1000__0001_0001_0001; //1/(5!)= 1/120=  0.008333...  approx 0.00833511352539
				3'd4 : return 'b0__0111_0101__0110_1100_0001; //1/(6!)= 1/720=  0.001388...  approx 0.00138902664185
				3'd5 : return 'b0__0111_0010__1010_0000_0010; //1/(7!)= 1/5040= 0.0001984127 approx 0.000198423862457
				default : return 'b0__0000_0000__0000_0000_0000;
			endcase

		endfunction

  function automatic logic [LAMP_FLOAT_DW-1:0] FUNC_lut_arctanh(input [4:0] counter);

      case(counter)
          5'd0  : return 'b0__0111_1110__0001_1001_0100; //arctanh(1/2)       = 0.54930614433405 --- approx ---> 0.54931640625
          5'd1  : return 'b0__0111_1101__0000_0101_1001; //arctanh(1/4)       = 0.25541281188299 --- approx ---> 0.255432128906
          5'd2  : return 'b0__0111_1100__0000_0001_0110; //arctanh(1/8)       = 0.12565721414045 --- approx ---> 0.125671386719
          5'd3  : return 'b0__0111_1011__0000_0000_0101; //arctanh(1/16)      = 0.06258157147700 --- approx ---> 0.0625762939453
          5'd4  : return 'b0__0111_1010__0000_0000_0001; //arctanh(1/32)      = 0.03126017849066 --- approx ---> 0.0312576293945
          5'd5  : return 'b0__0111_1001__0000_0000_0000; //arctanh(1/64)      = 0.01562627175205 --- approx ---> 0.015625
          5'd6  : return 'b0__0111_1000__0000_0000_0000; //arctanh(1/128)     = 0.00781265895154 --- approx ---> 0.0078125
          5'd7  : return 'b0__0111_0111__0000_0000_0000; //arctanh(1/256)     = 0.00390626986839 --- approx ---> 0.00390625
          5'd8  : return 'b0__0111_0110__0000_0000_0000; //arctanh(1/512)     = 0.00195312748353 --- approx ---> 0.001953125
          5'd9  : return 'b0__0111_0101__0000_0000_0000; //arctanh(1/1024)    = 0.00097656281044 --- approx ---> 0.0009765625
          5'd10 : return 'b0__0111_0100__0000_0000_0000; //arctanh(1/2048)    = 0.00048828128881 --- approx ---> 0.00048828125
          5'd11 : return 'b0__0111_0011__0000_0000_0000; //arctanh(1/4096)    = 0.00024414062985 --- approx ---> 0.000244140625
          5'd12 : return 'b0__0111_0010__0000_0000_0000; //arctanh(1/8192)    = 0.00012207031311 --- approx ---> 0.0001220703125
          5'd13 : return 'b0__0111_0001__0000_0000_0000; //arctanh(1/16384)   = 0.00006103515633 --- approx ---> 0.00006103515625
          5'd14 : return 'b0__0111_0000__0000_0000_0000; //arctanh(1/32768)   = 0.00003051757813 --- approx ---> 0.000030517578125
          5'd15 : return 'b0__0110_1111__0000_0000_0000; //arctanh(1/65536)   = 0.00001525878906 --- approx ---> 0.0000152587890625
          5'd16 : return 'b0__0110_1110__0000_0000_0000; //arctanh(1/131072)  = 0.00000762939453 --- approx ---> 0.00000762939453125
          5'd17 : return 'b0__0110_1101__0000_0000_0000; //arctanh(1/262144)  = 0.00000381469765 --- approx ---> 0.000003814697265625
          5'd18 : return 'b0__0110_1100__0000_0000_0000; //arctanh(1/524288)  = 0.00000190734863 --- approx ---> 0.0000019073486328125
          5'd19 : return 'b0__0110_1011__0000_0000_0000; //arctanh(1/1048576) = 0.00000095367432 --- approx ---> 0.00000095367431640625
          default : return 'b0__0000_0000__0000_0000_0000;
      endcase

  endfunction

	function automatic logic [$clog2(1+1+LAMP_FLOAT_F_DW+3)-1:0] FUNC_AddSubPostNorm_numLeadingZeros( input [1+1+LAMP_FLOAT_F_DW+3-1:0] f_initial_res);

		casez(f_initial_res)
			17'b1????????????????: return  'd0;
			17'b01???????????????: return  'd0;
			17'b001??????????????: return  'd1;
			17'b0001?????????????: return  'd2;
			17'b00001????????????: return  'd3;
			17'b000001???????????: return  'd4;
			17'b0000001??????????: return  'd5;
			17'b00000001?????????: return  'd6;
			17'b000000001????????: return  'd7;
			17'b0000000001???????: return  'd8;
			17'b00000000001??????: return  'd9;
			17'b000000000001?????: return  'd10;
			17'b0000000000001????: return  'd11;
			17'b00000000000001???: return  'd12;
			17'b000000000000001??: return  'd13;
			17'b0000000000000001?: return  'd14;
			17'b00000000000000001: return  'd15;
			17'b00000000000000000: return  'd0; // zero result
		endcase
	endfunction

	function automatic logic [$clog2(LAMP_FLOAT_F_DW+1)-1:0] FUNC_numLeadingZeros(
					input logic [(LAMP_FLOAT_F_DW+1)-1:0] f_i
				);
				    casez(f_i)
				      13'b1????????????: return 'd0;
				      13'b01???????????: return 'd1;
				      13'b001??????????: return 'd2;
				      13'b0001?????????: return 'd3;
				      13'b00001????????: return 'd4;
				      13'b000001???????: return 'd5;
				      13'b0000001??????: return 'd6;
				      13'b00000001?????: return 'd7;
							13'b000000001????: return 'd8;
							13'b0000000001???: return 'd9;
							13'b00000000001??: return 'd10;
							13'b000000000001?: return 'd11;
							13'b0000000000001: return 'd11;
				      13'b0000000000000: return 'd0; // zero result
    				endcase
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

	/*
	* FUNC_addsub_calcStickyBit:
	*
	* Calculate the sticky bit in add sub operations.
	*
	* Input: the f mantissa extended with 3 LSB, i.e., G,R,S, one
	* hidden bit, i.e., MSB-1, and an extra MSB for ovf or 2'complement.
	*
	* Output: the computed sticky bit
	*/
	function automatic logic FUNC_addsub_calcStickyBit( ///////////////////////////////////////////////////////////////////////////
        input logic [(1+LAMP_FLOAT_F_DW+3)-1:0] f_i,
        input logic [(LAMP_FLOAT_E_DW+1)-1:0] num_shr_i
        );
        case(num_shr_i)
            5'd0  :		return 1'b0;		// no right shift -> 0 sticky
            5'd1  :		return 1'b0;		// two added zero bits G,R
            5'd2  :		return 1'b0;		// two added zero bits G,R
            5'd3  :		return f_i[3];
            5'd4  :		return |f_i[3+:1];
            5'd5  :		return |f_i[3+:2];
            5'd6  :		return |f_i[3+:3];
            5'd7  :		return |f_i[3+:4];
            5'd8  :		return |f_i[3+:5];
            5'd9  :		return |f_i[3+:6];
						5'd10 :		return |f_i[3+:7];
						5'd11 :		return |f_i[3+:8];
						5'd12 :		return |f_i[3+:9];
						5'd13 :		return |f_i[3+:10];
						5'd14 :		return |f_i[3+:11];
            default:	return |f_i[3+:12];
        endcase
    endfunction

	/* FUNC_rndToNearestEven (Round-to-nearest-even):
	*
	* Description: performs the round to nearest even required by the IEEE 754-SP standard
	* with a minor modification to trade performance/area with precision.
	* instead of adding .1 in some scenarios with a possible 23bit carry chain
	* the number of bit in the carry chain is configurable. This way if the
	* considered LSB of the f are all 1 a truncation is performed instead of
	* a rnd. This removes the possible normalization stage after rounding.
	*/
	function automatic logic[LAMP_FLOAT_F_DW-1:0] FUNC_rndToNearestEven(
				input [(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_F_DW+3/*G,R,S*/)-1:0]		f_res_postNorm
			);

		localparam NUM_BIT_TO_RND	=	4;

		logic 															isAddOne;
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
			3'b1_01:	begin tempF_1[3] = 1; isAddOne =0; end
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

	/*
	* Nan +/- X	  -> Nan
	* X   +/- Nan -> Nan
	* +inf + +inf -> +inf
	* +inf - -inf -> +inf
	* -inf - +inf -> -inf
	* -inf + -inf -> -inf
	* +inf - inf -> NAN
	* -inf + inf -> NAN
	*/
	function automatic logic[3:0] FUNC_calcInfNanResAddSub(
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

	/*
	* 		Nan 	x 			X		-> 		 Nan
	* 		X 		x 			Nan 	-> 		 Nan
	* (+/-) inf 	x 	(+/-) 	inf 	-> (+/-) inf
	* (+/-) inf 	x 			0		-> 		 Nan
	* (+/-) inf		x 	(+/-)	X		-> (+/-) inf
	*/
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

endpackage
