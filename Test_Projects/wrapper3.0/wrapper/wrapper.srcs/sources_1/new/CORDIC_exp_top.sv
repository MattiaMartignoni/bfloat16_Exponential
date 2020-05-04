`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Di Fabio, Ferraresi, Martignoni
//
// Create Date: 24.03.2020 23:44:14
// Design Name:
// Module Name: cordic_exp_module
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module CORDIC_exp_top(
    clk, rst,
    padv_i, valid_i, data_i,
    ready_o, data_o, valid_o
    );

    import lampFPU_COR_pkg::*;

    input  clk;
    input  rst;

    input 						padv_i;
    input 						valid_i;
    input [LAMP_FLOAT_DW-1:0]	data_i;

    output logic						ready_o;
    output logic [LAMP_FLOAT_DW-1:0]	data_o;
    output logic						valid_o;


		//--------------- connections with submodules ---------------//
    logic           rst_addsub;
    logic           flush_r;
    rndModeFPU_t    rndMode_r;

	logic   padv_xy = 1'b0, padv_xy_next;
    logic	padv_z = 1'b0, padv_z_next;

    //X
    opcodeFPU_t  opcode_x, opcode_x_next;
    logic  [LAMP_FLOAT_DW-1:0] op1_x, op1_x_next;
    logic  [LAMP_FLOAT_DW-1:0] op2_x, op2_x_next;

    logic  [LAMP_FLOAT_DW-1:0] result_x, result_x_next;
    logic  isResultValid_x;
    logic  isReady_x;

    //Y
    opcodeFPU_t  opcode_y, opcode_y_next;
    logic  [LAMP_FLOAT_DW-1:0] op1_y, op1_y_next;
    logic  [LAMP_FLOAT_DW-1:0] op2_y, op2_y_next;

    logic  [LAMP_FLOAT_DW-1:0] result_y, result_y_next;
    logic  isResultValid_y;
    logic  isReady_y;

    //Z
    opcodeFPU_t  opcode_z, opcode_z_next;
    logic  [LAMP_FLOAT_DW-1:0] op1_z, op1_z_next;
    logic  [LAMP_FLOAT_DW-1:0] op2_z, op2_z_next;

    logic  [LAMP_FLOAT_DW-1:0] result_z, result_z_next;
    logic  isResultValid_z;
    logic  isReady_z;
		//-----------------------------------------------------------//

		//------------------- logic for algorithm -------------------//
    logic  sign_data_i;
    logic  [LAMP_FLOAT_DW-1:0] x, x_next;
    logic  [LAMP_FLOAT_DW-1:0] y, y_next;
    logic  [LAMP_FLOAT_DW-1:0] z, z_next;
    logic [LAMP_FLOAT_DW-1:0] lut_arctanh;
    logic  direction, direction_next; //if direction == 0 then use sign +, else use sign -
    logic  [4:0] counter, counter_next;
    logic  [LAMP_FLOAT_DW-1:0] data_o_next;
    logic valid_o_next;

    typedef enum logic[1:0]
  	{
  		COR_IDLE	    = 2'd0,
  		COR_CALCULATE	= 2'd1,
  		COR_RECEIVE		= 2'd2,
        COR_DONE        = 2'd3
  	} stateCOR_t;

    stateCOR_t  state, state_next;
		//-----------------------------------------------------------//

		///////////////////////////////////////////////////////////////
		//-------------------- sequential logic ---------------------//
    always @(posedge clk)
    begin
        if (rst)
        begin
            state <= COR_IDLE;
            valid_o <= 'd0;
            rst_addsub <= 1'b1;
            padv_xy <= 1'b0;
            padv_z <= 1'b0;
        end
        else
        begin
            rst_addsub <= 1'b0;
            state <= state_next;
            counter <= counter_next;

            x <= x_next;
            y <= y_next;
            z <= z_next;
            direction <= direction_next;
			valid_o <= valid_o_next;
            data_o <= data_o_next;

            padv_xy <= padv_xy_next;
            padv_z <= padv_z_next;

            opcode_x <= opcode_x_next;
            op1_x <= op1_x_next;
            op2_x <= op2_x_next;

            opcode_y <= opcode_y_next;
            op1_y <= op1_y_next;
            op2_y <= op2_y_next;

            opcode_z <= opcode_z_next;
            op1_z <= op1_z_next;
            op2_z <= op2_z_next;
        end
    end
		//-----------------------------------------------------------//
		///////////////////////////////////////////////////////////////

		///////////////////////////////////////////////////////////////
		//------------------- combinational logic -------------------//
    always_comb
    begin
        state_next = state;
        counter_next = counter;

        x_next = x;
        y_next = y;
        z_next = z;
        direction_next = direction;
        valid_o_next = valid_o;
        data_o_next = data_o;

        padv_xy_next = padv_xy;
        padv_z_next = padv_z;

        opcode_x_next = opcode_x;
        op1_x_next = op1_x;
        op2_x_next = op2_x;

        opcode_y_next = opcode_y;
        op1_y_next = op1_y;
        op2_y_next = op2_y;

        opcode_z_next = opcode_z;
        op1_z_next = op1_z;
        op2_z_next = op2_z;

        case (state)
            //--------------------------------------------------------------------IDLE
            COR_IDLE:
            begin
                if (valid_i)
                begin
                    counter_next = 'd0;
                    sign_data_i = data_i[LAMP_FLOAT_DW-1]; //stores input data's sign
                    x_next = X0;
                    y_next = Y0;
                    z_next = {1'b0,data_i[LAMP_FLOAT_DW-2:0]}; //module of input data
                    opcode_x_next = FPU_IDLE;
                    opcode_y_next = FPU_IDLE;
                    opcode_z_next = FPU_IDLE;
					          direction_next = D0;
                    padv_xy_next = 1'b0;
                    padv_z_next = 1'b0;
                    state_next = COR_CALCULATE;
                end
            end

            //--------------------------------------------------------------------CALCULATE
            COR_CALCULATE:
            begin
                if (isReady_x & isReady_y & isReady_z)
                begin
                    padv_xy_next = 1'b0;
                    padv_z_next = 1'b0;

					// after all iterations sum/sub sinh and cosh to have exp result
                    if (counter == CORDIC_ITERATIONS)
                    begin
						// exp(data_i) = cosh(|data_i|) + sign*sinh(|data_i|)
                        op1_z_next = x;
                        op2_z_next = y;
                        if(sign_data_i)
                            opcode_z_next = FPU_SUB;
                        else
                            opcode_z_next = FPU_ADD;
                    end
					//continue iterations
                    else
                    begin
						//Xi + dir*Yi*2^(-i)
                        op1_x_next = x;
                        if (&(~y[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW+1])) //E='b0000_0000_00X (becomes/is denormalized)
                            op2_x_next = {y[LAMP_FLOAT_DW-1], y[LAMP_FLOAT_DW-2:0]>>(counter+1)};
                        else
                            op2_x_next = {y[LAMP_FLOAT_DW-1], y[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]-(counter+1), y[LAMP_FLOAT_F_DW-1:0]};

                        //Xi + dir*Yi*2^(-i)
                        op1_y_next = y;
                        if (&(~x[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW+1])) //E='b0000_0000_00X (becomes/is denormalized)
                            op2_y_next = {x[LAMP_FLOAT_DW-1], x[LAMP_FLOAT_DW-2:0]>>(counter+1)};
                        else
                            op2_y_next = {x[LAMP_FLOAT_DW-1], x[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]-(counter+1), x[LAMP_FLOAT_F_DW-1:0]};

                        //Zi - dir*atanh(2^(-i))
                        op1_z_next = z;
                        op2_z_next = lut_arctanh;

                        if(direction == 0)
                        begin
                            opcode_x_next = FPU_ADD;
                            opcode_y_next = FPU_ADD;
                            opcode_z_next = FPU_SUB;
                        end
                        else
                        begin
                            opcode_x_next = FPU_SUB;
                            opcode_y_next = FPU_SUB;
                            opcode_z_next = FPU_ADD;
                        end
                  	end

                  	state_next = COR_RECEIVE;
                end
            end

            //--------------------------------------------------------------------RECEIVE
            COR_RECEIVE:
            begin
                if(isResultValid_x & isResultValid_y & isResultValid_z)
                begin
                    x_next = result_x;
                    y_next = result_y;
                    z_next = result_z;

                    if (result_z[LAMP_FLOAT_DW-1])
                        direction_next = 1;
                    else
                        direction_next = 0;

                    //exp at output
                    if(counter == CORDIC_ITERATIONS)
                    begin
                        data_o_next = result_z;
                        valid_o_next = 1'b1;
                        state_next = COR_DONE;
                    end
                    else
                    begin
                        //sinh and cosh at output
                        if (counter == (CORDIC_ITERATIONS-1))
                            padv_z_next = 1'b1;
                        //X,Y,Z for next iteration
                        else
                        begin
                            padv_xy_next = 1'b1;
                            padv_z_next = 1'b1;
                        end
                        counter_next = counter + 1;
                        state_next = COR_CALCULATE;
                    end
                end
            end

            //--------------------------------------------------------------------DONE
            COR_DONE:
            begin
                if (padv_i)
                begin
                    valid_o_next = 1'b0;
                    padv_xy_next = 1'b1;
                    padv_z_next = 1'b1;
                    state_next = COR_IDLE;
                end
            end

        endcase

    end
		//-----------------------------------------------------------//
		///////////////////////////////////////////////////////////////

    assign ready_o = (state == COR_IDLE) | valid_o;
    assign flush_r = 1'b0;
    assign rndMode_r = FPU_RNDMODE_NEAREST;

    always_comb
        lut_arctanh = FUNC_lut_arctanh(counter);

		//------------------- internal submodules -------------------//
    lampFPU_COR_top
    lampFPU_COR_top_x(
        .clk    (clk),
        .rst    (rst_addsub),
        .flush_i    (flush_r),
        .padv_i 	(padv_xy),
        .opcode_i 	(opcode_x),
        .rndMode_i  (rndMode_r),
        .op1_i  (op1_x),
        .op2_i  (op2_x),
        .result_o 		    (result_x),
        .isResultValid_o    (isResultValid_x),
        .isReady_o 			(isReady_x)
    );

    lampFPU_COR_top
    lampFPU_COR_top_y(
        .clk    (clk),
        .rst    (rst_addsub),
        .flush_i    (flush_r),
        .padv_i 	(padv_xy),
        .opcode_i 	(opcode_y),
        .rndMode_i  (rndMode_r),
        .op1_i  (op1_y),
        .op2_i  (op2_y),
        .result_o           (result_y),
        .isResultValid_o    (isResultValid_y),
        .isReady_o 			(isReady_y)
    );

    lampFPU_COR_top
    lampFPU_COR_top_z(
        .clk    (clk),
        .rst    (rst_addsub),
        .flush_i    (flush_r),
        .padv_i 	(padv_z),
        .opcode_i  	(opcode_z),
        .rndMode_i  (rndMode_r),
        .op1_i  (op1_z),
        .op2_i  (op2_z),
        .result_o           (result_z),
        .isResultValid_o    (isResultValid_z),
        .isReady_o 			(isReady_z)
    );
		//-----------------------------------------------------------//

endmodule