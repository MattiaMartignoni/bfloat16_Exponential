package exponential_pkg_scrap;

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
    //                      cordic                    //
    //////////////////////////////////////////////////

//    parameter LAMP_FLOAT_COR_DW      = 25;
//    parameter LAMP_FLOAT_COR_S_DW =    1;
//    parameter LAMP_FLOAT_COR_E_DW =    8;
//    parameter LAMP_FLOAT_COR_F_DW =    16;

//    parameter X0_ext = 32'b0__0111_1111__0011_0100_1000_0011_1101_000;

//    parameter                         CORDIC_ITERATIONS = 20;

//    const logic [LAMP_FLOAT_COR_DW-1:0] X0 = {X0_ext[31:23], FUNC_COR_rndToNearestEven({1'b0, 1'b1, X0_ext[22:22-LAMP_FLOAT_COR_F_DW-1], | X0_ext[22-LAMP_FLOAT_COR_F_DW-2:0]})};
//    const logic [LAMP_FLOAT_COR_DW-1:0] Y0 = {LAMP_FLOAT_COR_DW{1'b0}};
//    const logic [LAMP_FLOAT_COR_DW-1:0] Z0 = {LAMP_FLOAT_COR_DW{1'b0}};
//    const logic                         D0 = 1'b0;

//    parameter INF_COR_E_F  = {8'b1, {LAMP_FLOAT_COR_F_DW{1'b0}}};
//    parameter SNAN_COR_E_F = {8'b1, 1'b0, {LAMP_FLOAT_COR_F_DW-1{1'b1}}};
//    parameter QNAN_COR_E_F = {9'b1, {LAMP_FLOAT_COR_F_DW-1{1'b0}}};
//    parameter ZERO_COR_E_F = {LAMP_FLOAT_COR_DW-1{1'b0}};


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

//  THIS FUNCTION IS NOT IMPLEMENTED HERE SINCE IT DOESN'T DEPEND DIRECTILY ON THE NUMBER OF BITS OF THE MULTIPLIER
//	function automatic logic[4:0] FUNC_MUL_calcInfNanZeroResMul(
//		input isZero_op1_i, isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
//		input isZero_op2_i, isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
//		);

//		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
//		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

//		logic isValidRes, isZeroRes, isInfRes, isNanRes, signRes;

//		isValidRes	= (isZero_op1_i || isZero_op2_i || isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
//		if (isNan_op1)
//		begin //sign is not important, since a Nan remains a nan what-so-ever
//			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
//		end
//		else if (isNan_op2)
//		begin
//			isZeroRes = 0; isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
//		end
//		else // both are not NaN
//		begin
//			case({isZero_op1_i, isZero_op2_i, isInf_op1_i,isInf_op2_i})
//				4'b00_00: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end
//				4'b00_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
//				4'b00_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
//				4'b00_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 1; signRes = sign_op1_i ^ sign_op2_i; 	end
//				4'b01_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end	//TODO check sign of zero res
//				4'b01_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end	//Impossible
//				4'b01_10: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1; 						end	//TODO check sign of zero res
//				4'b01_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//				4'b10_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
//				4'b10_01: begin isNanRes = 1; isZeroRes = 0; isInfRes = 0; signRes = 1;						 	end
//				4'b10_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//				4'b10_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//				4'b11_00: begin isNanRes = 0; isZeroRes = 1; isInfRes = 0; signRes = sign_op1_i ^ sign_op2_i; 	end
//				4'b11_01: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//				4'b11_10: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//				4'b11_11: begin isNanRes = 0; isZeroRes = 0; isInfRes = 0; signRes = 0; 						end //Impossible
//			endcase
//		end
//		return {isValidRes, isZeroRes, isInfRes, isNanRes, signRes};
//	endfunction


	function automatic logic [LAMP_FLOAT_MUL_S_DW+LAMP_FLOAT_MUL_E_DW+LAMP_FLOAT_MUL_F_DW-1:0] FUNC_MUL_splitOperand(input [LAMP_FLOAT_MUL_DW-1:0] op); //MODIFICARE I NOMI IN
		return op;
	endfunction


	function automatic logic [LAMP_FLOAT_MUL_E_DW+1-1:0] FUNC_MUL_extendExp(input [LAMP_FLOAT_MUL_E_DW-1:0] e_op, input isDN);
		return	{ 1'b0, e_op[7:1], (e_op[0] | isDN) };
	endfunction


	function automatic logic [LAMP_FLOAT_MUL_F_DW+1-1:0] FUNC_MUL_extendFrac(input [LAMP_FLOAT_MUL_F_DW-1:0] f_op, input isDN, input isZ);
		return	{ (~isDN & ~isZ), f_op};
	endfunction


	//##################################################################################################################################################
	//##################################################################################################################################################
	//##################################################################################################################################################
	function automatic logic [$clog2(LAMP_FLOAT_MUL_F_DW+1)-1:0] FUNC_MUL_numLeadingZeros(input logic [(LAMP_FLOAT_MUL_F_DW+1)-1:0] f_i);
		casez(f_i)
		
            //UNCOMMENT THIS FOR MULTIPLICATION 20 BITS
//            12'b1???????????: return 'd0;
//            12'b01??????????: return 'd1;
//            12'b001?????????: return 'd2;
//            12'b0001????????: return 'd3;
//            12'b00001???????: return 'd4;
//            12'b000001??????: return 'd5;
//            12'b0000001?????: return 'd6;
//            12'b00000001????: return 'd7;
//            12'b000000001???: return 'd8;
//            12'b0000000001??: return 'd9;
//            12'b00000000001?: return 'd10;
//            12'b000000000001: return 'd11;
//            12'b000000000000: return 'd0; // zero result
            
            //UNCOMMENT THIS FOR MULTIPLICATION 21 BITS
//            13'b1????????????: return 'd0;
//            13'b01???????????: return 'd1;
//            13'b001??????????: return 'd2;
//            13'b0001?????????: return 'd3;
//            13'b00001????????: return 'd4;
//            13'b000001???????: return 'd5;
//            13'b0000001??????: return 'd6;
//            13'b00000001?????: return 'd7;
//            13'b000000001????: return 'd8;
//            13'b0000000001???: return 'd9;
//            13'b00000000001??: return 'd10;
//            13'b000000000001?: return 'd11;
//            13'b0000000000001: return 'd12;
//            13'b0000000000000: return 'd0; // zero result
		
		    //UNCOMMENT THIS FOR MULTIPLICATION 22 BITS
//		    14'b1?????????????: return 'd0;
//            14'b01????????????: return 'd1;
//            14'b001???????????: return 'd2;
//            14'b0001??????????: return 'd3;
//            14'b00001?????????: return 'd4;
//            14'b000001????????: return 'd5;
//            14'b0000001???????: return 'd6;
//            14'b00000001??????: return 'd7;
//            14'b000000001?????: return 'd8;
//            14'b0000000001????: return 'd9;
//            14'b00000000001???: return 'd10;
//            14'b000000000001??: return 'd11;
//            14'b0000000000001?: return 'd12;
//            14'b00000000000001: return 'd13;
//            14'b00000000000000: return 'd0; // zero result

		    //UNCOMMENT THIS FOR MULTIPLICATION 23 BITS
//		    15'b1??????????????: return 'd0;
//            15'b01?????????????: return 'd1;
//            15'b001????????????: return 'd2;
//            15'b0001???????????: return 'd3;
//            15'b00001??????????: return 'd4;
//            15'b000001?????????: return 'd5;
//            15'b0000001????????: return 'd6;
//            15'b00000001???????: return 'd7;
//            15'b000000001??????: return 'd8;
//            15'b0000000001?????: return 'd9;
//            15'b00000000001????: return 'd10;
//            15'b000000000001???: return 'd11;
//            15'b0000000000001??: return 'd12;
//            15'b00000000000001?: return 'd13;
//            15'b000000000000001: return 'd14;
//            15'b000000000000000: return 'd0; // zero result
            
		    //UNCOMMENT THIS FOR MULTIPLICATION 24 BITS
//            16'b1???????????????: return 'd0;
//            16'b01??????????????: return 'd1;
//            16'b001?????????????: return 'd2;
//            16'b0001????????????: return 'd3;
//            16'b00001???????????: return 'd4;
//            16'b000001??????????: return 'd5;
//            16'b0000001?????????: return 'd6;
//            16'b00000001????????: return 'd7;
//            16'b000000001???????: return 'd8;
//            16'b0000000001??????: return 'd9;
//            16'b00000000001?????: return 'd10;
//            16'b000000000001????: return 'd11;
//            16'b0000000000001???: return 'd12;
//            16'b00000000000001??: return 'd13;
//            16'b000000000000001?: return 'd14;
//            16'b0000000000000001: return 'd15;
//            16'b0000000000000000: return 'd0; // zero result
                                                  
            //UNCOMMENT THIS FOR MULTIPLICATION 25 BITS             
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

            //UNCOMMENT THIS FOR MULTIPLICATION 26 BITS             
//			18'b1?????????????????: return 'd0;
//			18'b01????????????????: return 'd1;
//			18'b001???????????????: return 'd2;
//			18'b0001??????????????: return 'd3;
//			18'b00001?????????????: return 'd4;
//			18'b000001????????????: return 'd5;
//			18'b0000001???????????: return 'd6;
//			18'b00000001??????????: return 'd7;
//			18'b000000001?????????: return 'd8;
//			18'b0000000001????????: return 'd9;
//			18'b00000000001???????: return 'd10;
//			18'b000000000001??????: return 'd11;
//			18'b0000000000001?????: return 'd12;
//			18'b00000000000001????: return 'd13;
//			18'b000000000000001???: return 'd14;
//			18'b0000000000000001??: return 'd15;
//			18'b00000000000000001?: return 'd16;
//            18'b000000000000000001: return 'd17;
//			18'b000000000000000000: return 'd0; // zero result

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
		'd9:	return {mantissa[LAMP_FLOAT_MUL_F_DW-11:0], 10'b0};//20 bit  //uncomment all up to bit used
		'd10:	return {mantissa[LAMP_FLOAT_MUL_F_DW-12:0], 11'b0};//21 bit
		'd11:	return {mantissa[LAMP_FLOAT_MUL_F_DW-13:0], 12'b0};//22 bit
		'd12:	return {mantissa[LAMP_FLOAT_MUL_F_DW-14:0], 13'b0};//23 bit
		'd13:	return {mantissa[LAMP_FLOAT_MUL_F_DW-15:0], 14'b0};//24 bit
		'd14:	return {mantissa[LAMP_FLOAT_MUL_F_DW-16:0], 15'b0};//25 bit
//		'd15:	return {mantissa[LAMP_FLOAT_MUL_F_DW-17:0], 16'b0};//26 bit
//		'd10:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//20                       //uncomment only the one of bit used
//		'd11:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//21
//		'd12:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//22
//		'd13:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//23
//		'd14:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//24
		'd15:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//25
//		'd16:	return {LAMP_FLOAT_MUL_F_DW{1'b0}};//26
		endcase
	endfunction
	//##################################################################################################################################################
    //##################################################################################################################################################
    //##################################################################################################################################################

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

	//##################################################################################################################################################
	//##################################################################################################################################################
	//##################################################################################################################################################

	function automatic logic [LAMP_FLOAT_TAY_DW-1:0] FUNC_lut_factorial(input [2:0] counter);
		case (counter)
			//UNCOMMENT THIS FOR TAYLOR 16 BITS
			/* 3'd0 : return 'b0__0111_1110__0000_000; //1/(2!)= 1/2=    0,5
			3'd1 : return 'b0__0111_1100__0101_011; //1/(3!)= 1/6=    0,166666...  approx 0.1669921875
			3'd2 : return 'b0__0111_1010__0101_011; //1/(4!)= 1/24=   0,041666...  approx 0.041748046875
			3'd3 : return 'b0__0111_1000__0001_001; //1/(5!)= 1/120=  0,008333...  approx 0.00836181640625
			3'd4 : return 'b0__0111_0101__0110_110; //1/(6!)= 1/720=  0.001388...  approx 0.00138854980469
			3'd5 : return 'b0__0111_0010__1010_000; //1/(7!)= 1/5040= 0.0001984127 approx 0.000198364257812
			default : return 'b0__0000_0000__0000_000; */

			//UNCOMMENT THIS FOR TAYLOR 20 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_000; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_011; //1/(3!)= 1/6=    0.166666...  approx 0.166687011719
//			3'd2 : return 'b0__0111_1010__0101_0101_011; //1/(4!)= 1/24=   0.041666...  approx 0.0416717529297
//			3'd3 : return 'b0__0111_1000__0001_0001_001; //1/(5!)= 1/120=  0.008333...  approx 0.00833511352539
//			3'd4 : return 'b0__0111_0101__0110_1100_001; //1/(6!)= 1/720=  0.001388...  approx 0.00138902664185
//			3'd5 : return 'b0__0111_0010__1010_0000_001; //1/(7!)= 1/5040= 0.0001984127 approx 0.000198423862457
//			default : return 'b0__0000_0000__0000_0000_000;

            //UNCOMMENT THIS FOR TAYLOR 21 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_0000; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_0101; //1/(3!)= 1/6=    0.1666666666...
//			3'd2 : return 'b0__0111_1010__0101_0101_0101; //1/(4!)= 1/24=   0.0416666666...
//			3'd3 : return 'b0__0111_1000__0001_0001_0001; //1/(5!)= 1/120=  0.0083333333...
//			3'd4 : return 'b0__0111_0101__0110_1100_0001; //1/(6!)= 1/720=  0.0013888888...
//			3'd5 : return 'b0__0111_0010__1010_0000_0010; //1/(7!)= 1/5040= 0.0001984126984
//			default : return 'b0__0000_0000__0000_0000_0000_0;

            //UNCOMMENT THIS FOR TAYLOR 22 BITS
            3'd0 : return 'b0__0111_1110__0000_0000_0000_0; //1/(2!)= 1/2=    0,5
            3'd1 : return 'b0__0111_1100__0101_0101_0101_1; //1/(3!)= 1/6=    0.166666...  approx 0.166687011719
            3'd2 : return 'b0__0111_1010__0101_0101_0101_1; //1/(4!)= 1/24=   0.041666...  approx 0.0416717529297
            3'd3 : return 'b0__0111_1000__0001_0001_0001_0; //1/(5!)= 1/120=  0.008333...  approx 0.00833511352539
            3'd4 : return 'b0__0111_0101__0110_1100_0001_1; //1/(6!)= 1/720=  0.001388...  approx 0.00138902664185
            3'd5 : return 'b0__0111_0010__1010_0000_0001_1; //1/(7!)= 1/5040= 0.0001984127 approx 0.000198423862457
            default : return 'b0__0000_0000__0000_0000_0000_0;

            //UNCOMMENT THIS FOR TAYLOR 23 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_0000_00; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_0101_01; //1/(3!)= 1/6=    0.1666666666...
//			3'd2 : return 'b0__0111_1010__0101_0101_0101_01; //1/(4!)= 1/24=   0.0416666666...
//			3'd3 : return 'b0__0111_1000__0001_0001_0001_00; //1/(5!)= 1/120=  0.0083333333...
//			3'd4 : return 'b0__0111_0101__0110_1100_0001_10; //1/(6!)= 1/720=  0.0013888888...
//			3'd5 : return 'b0__0111_0010__1010_0000_0001_11; //1/(7!)= 1/5040= 0.0001984126984
//			default : return 'b0__0000_0000__0000_0000_0000_0;

            //UNCOMMENT THIS FOR TAYLOR 24 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_0000_000; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_0101_011; //1/(3!)= 1/6=    0.1666666666...
//			3'd2 : return 'b0__0111_1010__0101_0101_0101_011; //1/(4!)= 1/24=   0.0416666666...
//			3'd3 : return 'b0__0111_1000__0001_0001_0001_001; //1/(5!)= 1/120=  0.0083333333...
//			3'd4 : return 'b0__0111_0101__0110_1100_0001_011; //1/(6!)= 1/720=  0.0013888888...
//			3'd5 : return 'b0__0111_0010__1010_0000_0001_101; //1/(7!)= 1/5040= 0.0001984126984
//			default : return 'b0__0000_0000__0000_0000_0000_0;

			//UNCOMMENT THIS FOR TAYLOR 25 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_0000_0000; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_0101_0101; //1/(3!)= 1/6=    0.1666666666...
//			3'd2 : return 'b0__0111_1010__0101_0101_0101_0101; //1/(4!)= 1/24=   0.0416666666...
//			3'd3 : return 'b0__0111_1000__0001_0001_0001_0001; //1/(5!)= 1/120=  0.0083333333...
//			3'd4 : return 'b0__0111_0101__0110_1100_0001_0111; //1/(6!)= 1/720=  0.0013888888...
//			3'd5 : return 'b0__0111_0010__1010_0000_0001_1010; //1/(7!)= 1/5040= 0.0001984126984
//			default : return 'b0__0000_0000__0000_0000_0000_0000;

            //UNCOMMENT THIS FOR TAYLOR 26 BITS
//			3'd0 : return 'b0__0111_1110__0000_0000_0000_0000_0; //1/(2!)= 1/2=    0,5
//			3'd1 : return 'b0__0111_1100__0101_0101_0101_0101_1; //1/(3!)= 1/6=    0.1666666666...
//			3'd2 : return 'b0__0111_1010__0101_0101_0101_0101_1; //1/(4!)= 1/24=   0.0416666666...
//			3'd3 : return 'b0__0111_1000__0001_0001_0001_0001_0; //1/(5!)= 1/120=  0.0083333333...
//			3'd4 : return 'b0__0111_0101__0110_1100_0001_0111_0; //1/(6!)= 1/720=  0.0013888888...
//			3'd5 : return 'b0__0111_0010__1010_0000_0001_1010_0; //1/(7!)= 1/5040= 0.0001984126984
//			default : return 'b0__0000_0000__0000_0000_0000_0;


		endcase
	endfunction


	function automatic logic [$clog2(1+1+LAMP_FLOAT_TAY_F_DW+3)-1:0] FUNC_TAY_AddSubPostNorm_numLeadingZeros(input [1+1+LAMP_FLOAT_TAY_F_DW+3-1:0] f_initial_res);
		casez(f_initial_res)
			//UNCOMMENT THIS FOR TAYLOR 16 BITS
			/* 12'b1???????????: return  'd0;
			12'b01??????????: return  'd0;
			12'b001?????????: return  'd1;
			12'b0001????????: return  'd2;
			12'b00001???????: return  'd3;
			12'b000001??????: return  'd4;
			12'b0000001?????: return  'd5;
			12'b00000001????: return  'd6;
			12'b000000001???: return  'd7;
			12'b0000000001??: return  'd8;
			12'b00000000001?: return  'd9;
			12'b000000000001: return  'd10;
			12'b000000000000: return  'd0; // zero result */

			//UNCOMMENT THIS FOR TAYLOR 20 BITS
//			16'b1???????????????: return  'd0;
//			16'b01??????????????: return  'd0;
//			16'b001?????????????: return  'd1;
//			16'b0001????????????: return  'd2;
//			16'b00001???????????: return  'd3;
//			16'b000001??????????: return  'd4;
//			16'b0000001?????????: return  'd5;
//			16'b00000001????????: return  'd6;
//			16'b000000001???????: return  'd7;
//			16'b0000000001??????: return  'd8;
//			16'b00000000001?????: return  'd9;
//			16'b000000000001????: return  'd10;
//			16'b0000000000001???: return  'd11;
//			16'b00000000000001??: return  'd12;
//			16'b000000000000001?: return  'd13;
//			16'b0000000000000001: return  'd14;
//			16'b0000000000000000: return  'd0; // zero result

            //UNCOMMENT THIS FOR TAYLOR 21 BITS
//            17'b1????????????????: return  'd0;
//            17'b01???????????????: return  'd0;
//            17'b001??????????????: return  'd1;
//            17'b0001?????????????: return  'd2;
//            17'b00001????????????: return  'd3;
//            17'b000001???????????: return  'd4;
//            17'b0000001??????????: return  'd5;
//            17'b00000001?????????: return  'd6;
//            17'b000000001????????: return  'd7;
//            17'b0000000001???????: return  'd8;
//            17'b00000000001??????: return  'd9;
//            17'b000000000001?????: return  'd10;
//            17'b0000000000001????: return  'd11;
//            17'b00000000000001???: return  'd12;
//            17'b000000000000001??: return  'd13;
//            17'b0000000000000001?: return  'd14;
//            17'b00000000000000001: return  'd15;
//            17'b00000000000000000: return  'd0; // zero result

            //UNCOMMENT THIS FOR TAYLOR 22 BITS
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

            //UNCOMMENT THIS FOR TAYLOR 23 BITS             
//             19'b1??????????????????: return  'd0;
//             19'b01?????????????????: return  'd0;
//             19'b001????????????????: return  'd1;
//             19'b0001???????????????: return  'd2;
//             19'b00001??????????????: return  'd3;
//             19'b000001?????????????: return  'd4;
//             19'b0000001????????????: return  'd5;
//             19'b00000001???????????: return  'd6;
//             19'b000000001??????????: return  'd7;
//             19'b0000000001?????????: return  'd8;
//             19'b00000000001????????: return  'd9;
//             19'b000000000001???????: return  'd10;
//             19'b0000000000001??????: return  'd11;
//             19'b00000000000001?????: return  'd12;
//             19'b000000000000001????: return  'd13;
//             19'b0000000000000001???: return  'd14;
//             19'b00000000000000001??: return  'd15;
//             19'b000000000000000001?: return  'd16;
//             19'b0000000000000000001: return  'd17;
//             19'b0000000000000000000: return  'd0; // zero result
             
            //UNCOMMENT THIS FOR TAYLOR 24 BITS             
//            20'b1???????????????????: return  'd0;
//            20'b01??????????????????: return  'd0;
//            20'b001?????????????????: return  'd1;
//            20'b0001????????????????: return  'd2;
//            20'b00001???????????????: return  'd3;
//            20'b000001??????????????: return  'd4;
//            20'b0000001?????????????: return  'd5;
//            20'b00000001????????????: return  'd6;
//            20'b000000001???????????: return  'd7;
//            20'b0000000001??????????: return  'd8;
//            20'b00000000001?????????: return  'd9;
//            20'b000000000001????????: return  'd10;
//            20'b0000000000001???????: return  'd11;
//            20'b00000000000001??????: return  'd12;
//            20'b000000000000001?????: return  'd13;
//            20'b0000000000000001????: return  'd14;
//            20'b00000000000000001???: return  'd15;
//            20'b000000000000000001??: return  'd16;
//            20'b0000000000000000001?: return  'd17;
//            20'b00000000000000000001: return  'd18;
//            20'b00000000000000000000: return  'd0; // zero result

			//UNCOMMENT THIS FOR TAYLOR 25 BITS
//			21'b1????????????????????: return  'd0;
//			21'b01???????????????????: return  'd0;
//			21'b001??????????????????: return  'd1;
//			21'b0001?????????????????: return  'd2;
//			21'b00001????????????????: return  'd3;
//			21'b000001???????????????: return  'd4;
//			21'b0000001??????????????: return  'd5;
//			21'b00000001?????????????: return  'd6;
//			21'b000000001????????????: return  'd7;
//			21'b0000000001???????????: return  'd8;
//			21'b00000000001??????????: return  'd9;
//			21'b000000000001?????????: return  'd10;
//			21'b0000000000001????????: return  'd11;
//			21'b00000000000001???????: return  'd12;
//			21'b000000000000001??????: return  'd13;
//			21'b0000000000000001?????: return  'd14;
//			21'b00000000000000001????: return  'd15;
//			21'b000000000000000001???: return  'd16;
//			21'b0000000000000000001??: return  'd17;
//			21'b00000000000000000001?: return  'd18;
//			21'b000000000000000000001: return  'd19;
//			21'b000000000000000000000: return  'd0; // zero result

			//UNCOMMENT THIS FOR TAYLOR 26 BITS            
//			22'b1?????????????????????: return  'd0;
//			22'b01????????????????????: return  'd0;
//			22'b001???????????????????: return  'd1;
//			22'b0001??????????????????: return  'd2;
//			22'b00001?????????????????: return  'd3;
//			22'b000001????????????????: return  'd4;
//			22'b0000001???????????????: return  'd5;
//			22'b00000001??????????????: return  'd6;
//			22'b000000001?????????????: return  'd7;
//			22'b0000000001????????????: return  'd8;
//			22'b00000000001???????????: return  'd9;
//			22'b000000000001??????????: return  'd10;
//			22'b0000000000001?????????: return  'd11;
//			22'b00000000000001????????: return  'd12;
//			22'b000000000000001???????: return  'd13;
//			22'b0000000000000001??????: return  'd14;
//			22'b00000000000000001?????: return  'd15;
//			22'b000000000000000001????: return  'd16;
//			22'b0000000000000000001???: return  'd17;
//			22'b00000000000000000001??: return  'd18;
//			22'b000000000000000000001?: return  'd19;
//			22'b0000000000000000000001: return  'd20;
//			22'b0000000000000000000000: return  'd0; // zero result

		endcase
	endfunction


	function automatic logic [$clog2(LAMP_FLOAT_TAY_F_DW+1)-1:0] FUNC_TAY_numLeadingZeros(input logic [(LAMP_FLOAT_TAY_F_DW+1)-1:0] f_i);
		casez(f_i)
			//UNCOMMENT THIS FOR TAYLOR 16 BITS
			/* 8'b1???????: return 'd0;
			8'b01??????: return 'd1;
			8'b001?????: return 'd2;
			8'b0001????: return 'd3;
			8'b00001???: return 'd4;
			8'b000001??: return 'd5;
			8'b0000001?: return 'd6;
			8'b00000001: return 'd7;
			8'b00000000: return 'd0; // zero result */

            //UNCOMMENT THIS FOR MULTIPLICATION 20 BITS
//            12'b1???????????: return 'd0;
//            12'b01??????????: return 'd1;
//            12'b001?????????: return 'd2;
//            12'b0001????????: return 'd3;
//            12'b00001???????: return 'd4;
//            12'b000001??????: return 'd5;
//            12'b0000001?????: return 'd6;
//            12'b00000001????: return 'd7;
//            12'b000000001???: return 'd8;
//            12'b0000000001??: return 'd9;
//            12'b00000000001?: return 'd10;
//            12'b000000000001: return 'd11;
//            12'b000000000000: return 'd0; // zero result
            
            //UNCOMMENT THIS FOR MULTIPLICATION 21 BITS
//            13'b1????????????: return 'd0;
//            13'b01???????????: return 'd1;
//            13'b001??????????: return 'd2;
//            13'b0001?????????: return 'd3;
//            13'b00001????????: return 'd4;
//            13'b000001???????: return 'd5;
//            13'b0000001??????: return 'd6;
//            13'b00000001?????: return 'd7;
//            13'b000000001????: return 'd8;
//            13'b0000000001???: return 'd9;
//            13'b00000000001??: return 'd10;
//            13'b000000000001?: return 'd11;
//            13'b0000000000001: return 'd12;
//            13'b0000000000000: return 'd0; // zero result
        
            //UNCOMMENT THIS FOR MULTIPLICATION 22 BITS
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

            //UNCOMMENT THIS FOR MULTIPLICATION 23 BITS
//            15'b1??????????????: return 'd0;
//            15'b01?????????????: return 'd1;
//            15'b001????????????: return 'd2;
//            15'b0001???????????: return 'd3;
//            15'b00001??????????: return 'd4;
//            15'b000001?????????: return 'd5;
//            15'b0000001????????: return 'd6;
//            15'b00000001???????: return 'd7;
//            15'b000000001??????: return 'd8;
//            15'b0000000001?????: return 'd9;
//            15'b00000000001????: return 'd10;
//            15'b000000000001???: return 'd11;
//            15'b0000000000001??: return 'd12;
//            15'b00000000000001?: return 'd13;
//            15'b000000000000001: return 'd14;
//            15'b000000000000000: return 'd0; // zero result
            
            //UNCOMMENT THIS FOR MULTIPLICATION 24 BITS
//            16'b1???????????????: return 'd0;
//            16'b01??????????????: return 'd1;
//            16'b001?????????????: return 'd2;
//            16'b0001????????????: return 'd3;
//            16'b00001???????????: return 'd4;
//            16'b000001??????????: return 'd5;
//            16'b0000001?????????: return 'd6;
//            16'b00000001????????: return 'd7;
//            16'b000000001???????: return 'd8;
//            16'b0000000001??????: return 'd9;
//            16'b00000000001?????: return 'd10;
//            16'b000000000001????: return 'd11;
//            16'b0000000000001???: return 'd12;
//            16'b00000000000001??: return 'd13;
//            16'b000000000000001?: return 'd14;
//            16'b0000000000000001: return 'd15;
//            16'b0000000000000000: return 'd0; // zero result
                                                  
            //UNCOMMENT THIS FOR MULTIPLICATION 25 BITS             
//            17'b1????????????????: return 'd0;
//            17'b01???????????????: return 'd1;
//            17'b001??????????????: return 'd2;
//            17'b0001?????????????: return 'd3;
//            17'b00001????????????: return 'd4;
//            17'b000001???????????: return 'd5;
//            17'b0000001??????????: return 'd6;
//            17'b00000001?????????: return 'd7;
//            17'b000000001????????: return 'd8;
//            17'b0000000001???????: return 'd9;
//            17'b00000000001??????: return 'd10;
//            17'b000000000001?????: return 'd11;
//            17'b0000000000001????: return 'd12;
//            17'b00000000000001???: return 'd13;
//            17'b000000000000001??: return 'd14;
//            17'b0000000000000001?: return 'd15;
//            17'b00000000000000001: return 'd16;
//            17'b00000000000000000: return 'd0; // zero result

            //UNCOMMENT THIS FOR MULTIPLICATION 26 BITS             
//            18'b1?????????????????: return 'd0;
//            18'b01????????????????: return 'd1;
//            18'b001???????????????: return 'd2;
//            18'b0001??????????????: return 'd3;
//            18'b00001?????????????: return 'd4;
//            18'b000001????????????: return 'd5;
//            18'b0000001???????????: return 'd6;
//            18'b00000001??????????: return 'd7;
//            18'b000000001?????????: return 'd8;
//            18'b0000000001????????: return 'd9;
//            18'b00000000001???????: return 'd10;
//            18'b000000000001??????: return 'd11;
//            18'b0000000000001?????: return 'd12;
//            18'b00000000000001????: return 'd13;
//            18'b000000000000001???: return 'd14;
//            18'b0000000000000001??: return 'd15;
//            18'b00000000000000001?: return 'd16;
//            18'b000000000000000001: return 'd17;
//            18'b000000000000000000: return 'd0; // zero result

		endcase
	endfunction


	function automatic logic FUNC_TAY_addsub_calcStickyBit(input logic [(1+LAMP_FLOAT_TAY_F_DW+3)-1:0] f_i, input logic [(LAMP_FLOAT_TAY_E_DW+1)-1:0] num_shr_i);
		case(num_shr_i)
			//UNCOMMENT THIS FOR TAYLOR 16 BITS
			/* 5'd0 :		return 1'b0;		// no right shift -> 0 sticky
			5'd1 :		return 1'b0;		// two added zero bits G,R
			5'd2 :		return 1'b0;		// two added zero bits G,R
			5'd3 :		return f_i[3];
			5'd4 :		return |f_i[3+:1];
			5'd5 :		return |f_i[3+:2];
			5'd6 :		return |f_i[3+:3];
			5'd7 :		return |f_i[3+:4];
			5'd8 :		return |f_i[3+:5];
			5'd9 :		return |f_i[3+:6];
			default:	return |f_i[3+:7]; */
		
			//UNCOMMENT THIS FOR TAYLOR 20 BITS
//			5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//            5'd1  :		return 1'b0;		// two added zero bits G,R
//            5'd2  :		return 1'b0;		// two added zero bits G,R
//            5'd3  :		return f_i[3];
//            5'd4  :		return |f_i[3+:1];
//            5'd5  :		return |f_i[3+:2];
//            5'd6  :		return |f_i[3+:3];
//            5'd7  :		return |f_i[3+:4];
//            5'd8  :		return |f_i[3+:5];
//            5'd9  :		return |f_i[3+:6];
//			5'd10 :		return |f_i[3+:7];
//			5'd11 :		return |f_i[3+:8];
//			5'd12 :		return |f_i[3+:9];
//			5'd13 :		return |f_i[3+:10];
//            default:	return |f_i[3+:11];

			//UNCOMMENT THIS FOR TAYLOR 21 BITS
//            5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//            5'd1  :		return 1'b0;		// two added zero bits G,R
//            5'd2  :		return 1'b0;		// two added zero bits G,R
//            5'd3  :		return f_i[3];
//            5'd4  :		return |f_i[3+:1];
//            5'd5  :		return |f_i[3+:2];
//            5'd6  :		return |f_i[3+:3];
//            5'd7  :		return |f_i[3+:4];
//            5'd8  :		return |f_i[3+:5];
//            5'd9  :		return |f_i[3+:6];
//            5'd10 :		return |f_i[3+:7];
//            5'd11 :		return |f_i[3+:8];
//            5'd12 :		return |f_i[3+:9];
//            5'd13 :		return |f_i[3+:10];
//            5'd14 :		return |f_i[3+:11];
//            default:	return |f_i[3+:12];

            //UNCOMMENT THIS FOR TAYLOR 22 BITS
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

            //UNCOMMENT THIS FOR TAYLOR 23 BITS
//             5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//             5'd1  :        return 1'b0;        // two added zero bits G,R
//             5'd2  :        return 1'b0;        // two added zero bits G,R
//             5'd3  :        return f_i[3];
//             5'd4  :        return |f_i[3+:1];
//             5'd5  :        return |f_i[3+:2];
//             5'd6  :        return |f_i[3+:3];
//             5'd7  :        return |f_i[3+:4];
//             5'd8  :        return |f_i[3+:5];
//             5'd9  :        return |f_i[3+:6];
//             5'd10 :        return |f_i[3+:7];
//             5'd11 :        return |f_i[3+:8];
//             5'd12 :        return |f_i[3+:9];
//             5'd13 :        return |f_i[3+:10];
//             5'd14 :        return |f_i[3+:11];
//             5'd15 :        return |f_i[3+:12];
//             5'd16 :        return |f_i[3+:13];
//             default:    return |f_i[3+:14];

            //UNCOMMENT THIS FOR TAYLOR 24 BITS
//             5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//             5'd1  :        return 1'b0;        // two added zero bits G,R
//             5'd2  :        return 1'b0;        // two added zero bits G,R
//             5'd3  :        return f_i[3];
//             5'd4  :        return |f_i[3+:1];
//             5'd5  :        return |f_i[3+:2];
//             5'd6  :        return |f_i[3+:3];
//             5'd7  :        return |f_i[3+:4];
//             5'd8  :        return |f_i[3+:5];
//             5'd9  :        return |f_i[3+:6];
//             5'd10 :        return |f_i[3+:7];
//             5'd11 :        return |f_i[3+:8];
//             5'd12 :        return |f_i[3+:9];
//             5'd13 :        return |f_i[3+:10];
//             5'd14 :        return |f_i[3+:11];
//             5'd15 :        return |f_i[3+:12];
//             5'd16 :        return |f_i[3+:13];
//             5'd17 :        return |f_i[3+:14];
//             default:    return |f_i[3+:15];

			//UNCOMMENT THIS FOR TAYLOR 25 BITS
//			5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//            5'd1  :		return 1'b0;		// two added zero bits G,R
//            5'd2  :		return 1'b0;		// two added zero bits G,R
//            5'd3  :		return f_i[3];
//            5'd4  :		return |f_i[3+:1];
//            5'd5  :		return |f_i[3+:2];
//            5'd6  :		return |f_i[3+:3];
//            5'd7  :		return |f_i[3+:4];
//            5'd8  :		return |f_i[3+:5];
//            5'd9  :		return |f_i[3+:6];
//			5'd10 :		return |f_i[3+:7];
//			5'd11 :		return |f_i[3+:8];
//			5'd12 :		return |f_i[3+:9];
//			5'd13 :		return |f_i[3+:10];
//			5'd14 :		return |f_i[3+:11];
//			5'd15 :		return |f_i[3+:12];
//			5'd16 :		return |f_i[3+:13];
//			5'd17 :		return |f_i[3+:14];
//			5'd18 :		return |f_i[3+:15];
//            default:	return |f_i[3+:16];

			//UNCOMMENT THIS FOR TAYLOR 26 BITS
//			5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//            5'd1  :		return 1'b0;		// two added zero bits G,R
//            5'd2  :		return 1'b0;		// two added zero bits G,R
//            5'd3  :		return f_i[3];
//            5'd4  :		return |f_i[3+:1];
//            5'd5  :		return |f_i[3+:2];
//            5'd6  :		return |f_i[3+:3];
//            5'd7  :		return |f_i[3+:4];
//            5'd8  :		return |f_i[3+:5];
//            5'd9  :		return |f_i[3+:6];
//			5'd10 :		return |f_i[3+:7];
//			5'd11 :		return |f_i[3+:8];
//			5'd12 :		return |f_i[3+:9];
//			5'd13 :		return |f_i[3+:10];
//			5'd14 :		return |f_i[3+:11];
//			5'd15 :		return |f_i[3+:12];
//			5'd16 :		return |f_i[3+:13];
//			5'd17 :		return |f_i[3+:14];
//			5'd18 :		return |f_i[3+:15];
//			5'd19 :		return |f_i[3+:16];
//            default:	return |f_i[3+:17];

		endcase
	endfunction

	//##################################################################################################################################################
	//##################################################################################################################################################
	//##################################################################################################################################################

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


	//////////////////////////////////////////////////
	//				cordic functions				//
	//////////////////////////////////////////////////

//	function automatic logic [LAMP_FLOAT_COR_S_DW+LAMP_FLOAT_COR_E_DW+LAMP_FLOAT_COR_F_DW-1:0] FUNC_COR_splitOperand(input [LAMP_FLOAT_COR_DW-1:0] op); //MODIFICARE I NOMI IN
//		return op;
//	endfunction

//	function automatic logic [LAMP_FLOAT_COR_E_DW+1-1:0] FUNC_COR_extendExp(input [LAMP_FLOAT_COR_E_DW-1:0] e_op, input isDN);
//		return	{ 1'b0, e_op[7:1], (e_op[0] | isDN) };
//	endfunction

//	function automatic logic [LAMP_FLOAT_COR_F_DW+1-1:0] FUNC_COR_extendFrac(input [LAMP_FLOAT_COR_F_DW-1:0] f_op, input isDN, input isZ);
//		return	{ (~isDN & ~isZ), f_op};
//	endfunction

//	function automatic logic FUNC_COR_op1_GT_op2(
//			input [LAMP_FLOAT_COR_F_DW+1-1:0] f_op1, input [LAMP_FLOAT_COR_E_DW+1-1:0] e_op1,
//			input [LAMP_FLOAT_COR_F_DW+1-1:0] f_op2, input [LAMP_FLOAT_COR_E_DW+1-1:0] e_op2
//	);
//		logic 		e_op1_GT_op2, e_op1_EQ_op2;
//		logic 		f_op1_GT_op2;
//		logic 		op1_GT_op2, op1_EQ_op2;

//		e_op1_GT_op2 	= (e_op1 > e_op2);
//		e_op1_EQ_op2 	= (e_op1 == e_op2);

//		f_op1_GT_op2 	= (f_op1 > f_op2);

//		op1_GT_op2		= e_op1_GT_op2 | (e_op1_EQ_op2 & f_op1_GT_op2);

//		return	op1_GT_op2;
//	endfunction

//	function automatic logic [LAMP_FLOAT_COR_DW-1:0] FUNC_lut_arctanh(input [4:0] counter);
//		case(counter)
//			5'd0  : return 'b0__0111_1110__0001_1001_0011_1111; //arctanh(1/2)       = 0.54930614433405 --- approx ---> 0.54931640625
//			5'd1  : return 'b0__0111_1101__0000_0101_1000_1011; //arctanh(1/4)       = 0.25541281188299 --- approx ---> 0.255401611328
//			5'd2  : return 'b0__0111_1100__0000_0001_0101_1001; //arctanh(1/8)       = 0.12565721414045 --- approx ---> 0.12565612793
//			5'd3  : return 'b0__0111_1011__0000_0000_0101_0110; //arctanh(1/16)      = 0.06258157147700 --- approx ---> 0.0625839233398
//			5'd4  : return 'b0__0111_1010__0000_0000_0001_0101; //arctanh(1/32)      = 0.03126017849066 --- approx ---> 0.0312614440918
//			5'd5  : return 'b0__0111_1001__0000_0000_0000_0101; //arctanh(1/64)      = 0.01562627175205 --- approx ---> 0.0156269073486
//			5'd6  : return 'b0__0111_1000__0000_0000_0000_0001; //arctanh(1/128)     = 0.00781265895154 --- approx ---> 0.0078125
//			5'd7  : return 'b0__0111_0111__0000_0000_0000_0000; //arctanh(1/256)     = 0.00390626986839 --- approx ---> 0.00390625
//			5'd8  : return 'b0__0111_0110__0000_0000_0000_0000; //arctanh(1/512)     = 0.00195312748353 --- approx ---> 0.001953125
//			5'd9  : return 'b0__0111_0101__0000_0000_0000_0000; //arctanh(1/1024)    = 0.00097656281044 --- approx ---> 0.0009765625
//			5'd10 : return 'b0__0111_0100__0000_0000_0000_0000; //arctanh(1/2048)    = 0.00048828128881 --- approx ---> 0.00048828125
//			5'd11 : return 'b0__0111_0011__0000_0000_0000_0000; //arctanh(1/4096)    = 0.00024414062985 --- approx ---> 0.000244140625
//			5'd12 : return 'b0__0111_0010__0000_0000_0000_0000; //arctanh(1/8192)    = 0.00012207031311 --- approx ---> 0.0001220703125
//			5'd13 : return 'b0__0111_0001__0000_0000_0000_0000; //arctanh(1/16384)   = 0.00006103515633 --- approx ---> 0.00006103515625
//			5'd14 : return 'b0__0111_0000__0000_0000_0000_0000; //arctanh(1/32768)   = 0.00003051757813 --- approx ---> 0.000030517578125
//			5'd15 : return 'b0__0110_1111__0000_0000_0000_0000; //arctanh(1/65536)   = 0.00001525878906 --- approx ---> 0.0000152587890625
//			5'd16 : return 'b0__0110_1110__0000_0000_0000_0000; //arctanh(1/131072)  = 0.00000762939453 --- approx ---> 0.00000762939453125
//			5'd17 : return 'b0__0110_1101__0000_0000_0000_0000; //arctanh(1/262144)  = 0.00000381469765 --- approx ---> 0.000003814697265625
//			5'd18 : return 'b0__0110_1100__0000_0000_0000_0000; //arctanh(1/524288)  = 0.00000190734863 --- approx ---> 0.0000019073486328125
//			5'd19 : return 'b0__0110_1011__0000_0000_0000_0000; //arctanh(1/1048576) = 0.00000095367432 --- approx ---> 0.00000095367431640625
//			default : return 'b0__0000_0000__0000_0000_0000_0000;
//		endcase
//	endfunction

//	function automatic logic [$clog2(1+1+LAMP_FLOAT_COR_F_DW+3)-1:0] FUNC_COR_AddSubPostNorm_numLeadingZeros(input [1+1+LAMP_FLOAT_COR_F_DW+3-1:0] f_initial_res); //MODIFICARE IL NOME DELLA FUNZIONE IN LAMPFPU_COR_ADDSUB
//		casez(f_initial_res)
//			21'b1????????????????????: return  'd0;
//			21'b01???????????????????: return  'd0;
//			21'b001??????????????????: return  'd1;
//			21'b0001?????????????????: return  'd2;
//			21'b00001????????????????: return  'd3;
//			21'b000001???????????????: return  'd4;
//			21'b0000001??????????????: return  'd5;
//			21'b00000001?????????????: return  'd6;
//			21'b000000001????????????: return  'd7;
//			21'b0000000001???????????: return  'd8;
//			21'b00000000001??????????: return  'd9;
//			21'b000000000001?????????: return  'd10;
//			21'b0000000000001????????: return  'd11;
//			21'b00000000000001???????: return  'd12;
//			21'b000000000000001??????: return  'd13;
//			21'b0000000000000001?????: return  'd14;
//			21'b00000000000000001????: return  'd15;
//			21'b000000000000000001???: return  'd16;
//			21'b0000000000000000001??: return  'd17;
//			21'b00000000000000000001?: return  'd18;
//			21'b000000000000000000001: return  'd19; // zero result
//			21'b000000000000000000000: return  'd0; // zero result
//		endcase
//	endfunction

//	function automatic logic [$clog2(LAMP_FLOAT_COR_F_DW+1)-1:0] FUNC_COR_numLeadingZeros(input logic [(LAMP_FLOAT_COR_F_DW+1)-1:0] f_i);
//		casez(f_i)
//			17'b1????????????????: return 'd0;
//			17'b01???????????????: return 'd1;
//			17'b001??????????????: return 'd2;
//			17'b0001?????????????: return 'd3;
//			17'b00001????????????: return 'd4;
//			17'b000001???????????: return 'd5;
//			17'b0000001??????????: return 'd6;
//			17'b00000001?????????: return 'd7;
//			17'b000000001????????: return 'd8;
//			17'b0000000001???????: return 'd9;
//			17'b00000000001??????: return 'd10;
//			17'b000000000001?????: return 'd11;
//			17'b0000000000001????: return 'd12;
//			17'b00000000000001???: return 'd13;
//			17'b000000000000001??: return 'd14;
//			17'b0000000000000001?: return 'd15;
//			17'b00000000000000001: return 'd16;
//			17'b00000000000000: return 'd0; // zero result
//		endcase
//	endfunction

//	function automatic logic [LAMP_FLOAT_COR_F_DW-1:0] FUNC_COR_shiftMantissa(input logic [LAMP_FLOAT_COR_F_DW-1:0] mantissa, input logic [$clog2(LAMP_FLOAT_COR_F_DW+1)-1:0] shCount);
//		case(shCount)
//		'd0:	return {mantissa[LAMP_FLOAT_COR_F_DW-2:0], 1'b0};
//		'd1:	return {mantissa[LAMP_FLOAT_COR_F_DW-3:0], 2'b0};
//		'd2:	return {mantissa[LAMP_FLOAT_COR_F_DW-4:0], 3'b0};
//		'd3:	return {mantissa[LAMP_FLOAT_COR_F_DW-5:0], 4'b0};
//		'd4:	return {mantissa[LAMP_FLOAT_COR_F_DW-6:0], 5'b0};
//		'd5:	return {mantissa[LAMP_FLOAT_COR_F_DW-7:0], 6'b0};
//		'd6:	return {mantissa[LAMP_FLOAT_COR_F_DW-8:0], 7'b0};
//		'd7:	return {mantissa[LAMP_FLOAT_COR_F_DW-9:0], 8'b0};
//		'd8:	return {mantissa[LAMP_FLOAT_COR_F_DW-10:0], 9'b0};
//		'd9:	return {mantissa[LAMP_FLOAT_COR_F_DW-11:0], 10'b0};
//		'd10:	return {mantissa[LAMP_FLOAT_COR_F_DW-12:0], 11'b0};
//		'd11:	return {mantissa[LAMP_FLOAT_COR_F_DW-13:0], 12'b0};
//		'd12:	return {mantissa[LAMP_FLOAT_COR_F_DW-14:0], 13'b0};
//		'd13:	return {mantissa[LAMP_FLOAT_COR_F_DW-15:0], 14'b0};
//		'd14:	return {mantissa[LAMP_FLOAT_COR_F_DW-16:0], 15'b0};
//		'd15:	return {LAMP_FLOAT_COR_F_DW{1'b0}};
//		//'d16:	impossible
//		endcase
//	endfunction


//	function automatic logic [5-1:0] FUNC_COR_checkOperand(input [LAMP_FLOAT_COR_DW-1:0] op);
//		logic [LAMP_FLOAT_COR_S_DW-1:0] s_op;
//		logic [LAMP_FLOAT_COR_E_DW-1:0] e_op;
//		logic [LAMP_FLOAT_COR_F_DW-1:0] f_op;

//		logic isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op;
//		s_op = op[LAMP_FLOAT_COR_DW-1];
//		e_op = op[LAMP_FLOAT_COR_DW-2:LAMP_FLOAT_COR_F_DW];
//		f_op = op[LAMP_FLOAT_COR_F_DW-1:0];

//		// check deNorm (isDN), +/-inf (isInf), +/-zero (isZ), not a number (isSNaN, isQNaN)
//		isInf_op 	= (&e_op) &  ~(|f_op); 				// E==0xFF &&	  f==0x0
//		isDN_op 	= ~(|e_op) & (|f_op);					// E==0x0	 && 	f!=0x0
//		isZ_op 		= ~(|op[LAMP_FLOAT_COR_DW-2:0]);	// E==0x0	 && 	f==0x0
//		isSNAN_op 	= (&e_op) & ~f_op[6] & (|f_op[5:0]);
//		isQNAN_op 	= (&e_op) & f_op[6];

//		return {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op};
//	endfunction

//	function automatic logic FUNC_COR_addsub_calcStickyBit(input logic [(1+LAMP_FLOAT_COR_F_DW+3)-1:0] f_i, input logic [(LAMP_FLOAT_COR_E_DW+1)-1:0] num_shr_i);
//		case(num_shr_i)
//			5'd0  :		return 1'b0;		// no right shift -> 0 sticky
//			5'd1  :		return 1'b0;		// two added zero bits G,R
//			5'd2  :		return 1'b0;		// two added zero bits G,R
//			5'd3  :		return f_i[3];
//			5'd4  :		return |f_i[3+:1];
//			5'd5  :		return |f_i[3+:2];
//			5'd6  :		return |f_i[3+:3];
//			5'd7  :		return |f_i[3+:4];
//			5'd8  :		return |f_i[3+:5];
//			5'd9  :		return |f_i[3+:6];
//			5'd10 :		return |f_i[3+:7];
//			5'd11 :		return |f_i[3+:8];
//			5'd12 :		return |f_i[3+:9];
//			5'd13 :		return |f_i[3+:10];
//			5'd14 :		return |f_i[3+:11];
//			5'd15 :		return |f_i[3+:12];
//			5'd16 :		return |f_i[3+:13];
//			5'd17 :		return |f_i[3+:14];
//			5'd18 :		return |f_i[3+:15];
//			default:	return |f_i[3+:16];
//		endcase
//	endfunction

//	function automatic logic[LAMP_FLOAT_COR_F_DW-1:0] FUNC_COR_rndToNearestEven(input [(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_COR_F_DW+3/*G,R,S*/)-1:0] f_res_postNorm);

//		localparam NUM_BIT_TO_RND	=	4;

//		logic 									isAddOne;
//		logic [(1+1+LAMP_FLOAT_COR_F_DW+3)-1:0]	tempF_1;
//		logic [(1+1+LAMP_FLOAT_COR_F_DW+3)-1:0] tempF;
//		//
//		// Rnd to nearest even
//		//	X0.00 -> X0		|	X1.00 -> X1
//		//	X0.01 -> X0		|	X1.01 -> X1
//		//	X0.10 -> X0		|	X1.10 -> X1. +1
//		//	X0.11 -> X1		|	X1.11 -> X1. +1
//		//
//		tempF_1 = f_res_postNorm;
//		case(f_res_postNorm[3:1] /*3 bits X.G(S|R)*/ )
//		3'b0_00:	begin tempF_1[3] = 0;	isAddOne =0; end
//		3'b0_01:	begin tempF_1[3] = 0;	isAddOne =0; end
//		3'b0_10:	begin tempF_1[3] = 0;	isAddOne =0; end
//		3'b0_11:	begin tempF_1[3] = 1;	isAddOne =0; end
//		3'b1_00:	begin tempF_1[3] = 1;	isAddOne =0; end
//		3'b1_01:	begin tempF_1[3] = 1; 	isAddOne =0; end
//		3'b1_10:	begin tempF_1[3] = 1;	isAddOne =1; end
//		3'b1_11:	begin tempF_1[3] = 1;	isAddOne =1; end
//		endcase

//		// limit rnd to NUM_BIT_TO_RND LSBs of the f, truncate otherwise
//		// this avoid another normalization step, if any
//		if(&tempF_1[3+:NUM_BIT_TO_RND])
//		tempF =	tempF_1 ;
//		else
//		tempF =	tempF_1 + (isAddOne<<3);

//		return tempF[3+:LAMP_FLOAT_COR_F_DW];
//	endfunction

//	function automatic logic[3:0] FUNC_COR_calcInfNanResAddSub(
//		input isOpSub_i,
//		input isInf_op1_i, input sign_op1_i, input isSNan_op1_i, input isQNan_op1_i,
//		input isInf_op2_i, input sign_op2_i, input isSNan_op2_i, input isQNan_op2_i
//		);

//		logic realOp2_sign;
//		logic isNan_op1 = isSNan_op1_i || isQNan_op1_i;
//		logic isNan_op2 = isSNan_op2_i || isQNan_op2_i;

//		logic isValidRes, isInfRes, isNanRes, signRes;
//		realOp2_sign 	= sign_op2_i ^ isOpSub_i;

//		isValidRes 		= (isInf_op1_i || isInf_op2_i || isNan_op1 || isNan_op2) ? 1 : 0;
//		if (isNan_op1)
//		begin //sign is not important, since a Nan remains a nan what-so-ever
//			isInfRes = 0; isNanRes = 1; signRes = sign_op1_i;
//		end
//		else if (isNan_op2)
//		begin
//			isInfRes = 0; isNanRes = 1; signRes = sign_op2_i;
//		end
//		else // both are not NaN
//		begin
//			case({sign_op1_i, isInf_op1_i, realOp2_sign, isInf_op2_i})
//				4'b00_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
//				4'b00_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
//				4'b00_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
//				4'b00_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
//				4'b01_00: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
//				4'b01_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
//				4'b01_10: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
//				4'b01_11: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
//				4'b10_00: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
//				4'b10_01: begin isNanRes = 0; isInfRes = 1; signRes = 0; end
//				4'b10_10: begin isNanRes = 0; isInfRes = 0; signRes = 0; end
//				4'b10_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
//				4'b11_00: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
//				4'b11_01: begin isNanRes = 1; isInfRes = 0; signRes = 1; end //Nan - NOTE sign goes neg if one of the operands is neg
//				4'b11_10: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
//				4'b11_11: begin isNanRes = 0; isInfRes = 1; signRes = 1; end
//			endcase
//		end
//		return {isValidRes, isInfRes, isNanRes, signRes};
//	endfunction

endpackage
