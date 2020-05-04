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

module TAYLOR_exp_top(
    clk, rst,
    padv_i, valid_i, data_i,
    ready_o, data_o, valid_o
    );

	import lampFPU_TAY_pkg::*;

    input                               clk;
    input                               rst;
    input                               padv_i;
    input                               valid_i;
    input           [LAMP_FLOAT_DW-1:0] data_i;
    output logic                        ready_o;
    output logic    [LAMP_FLOAT_DW-1:0]	data_o;
    output logic                        valid_o;

    //--------------- connections with submodules ---------------//
    logic                           rst_r;
    logic                           flush_r;
    rndModeFPU_t                    rndMode_r;

    logic                           padv_r, padv_r_next;
    opcodeFPU_t                     opcode_r, opcode_r_next;
    logic       [LAMP_FLOAT_DW-1:0] op1_r, op1_r_next;
    logic		[LAMP_FLOAT_DW-1:0] op2_r, op2_r_next;

    logic		[LAMP_FLOAT_DW-1:0] result_r;
    logic                           isResultValid_r;
    logic                           isReady_r;
    //-----------------------------------------------------------//

    //------------------- logic for algorithm -------------------//
    logic [LAMP_FLOAT_DW-1:0]  factorial;
	logic [LAMP_FLOAT_DW-1:0]  pwr_acc, pwr_acc_next;
	logic [LAMP_FLOAT_DW-1:0]  sum_tot, sum_tot_next;
	logic [LAMP_FLOAT_DW-1:0]  res_temp, res_temp_next;
	logic [LAMP_FLOAT_DW-1:0]  x, x_next;
	logic [LAMP_FLOAT_DW-1:0]  data_o_next;
	logic                      valid_o_next;
	logic [2:0]                counter, counter_next;

	typedef enum logic[3:0]
	{
		IDLE  = 4'd0,
		PRE_0  = 4'd1,
		PRE_1  = 4'd2,
		ITER_0 = 4'd3,
		ITER_1 = 4'd4,
		ITER_2 = 4'd5,
		ITER_3 = 4'd6,
		ITER_4 = 4'd7,
		ITER_5 = 4'd8,
        DONE   = 4'd9
	} stateTAYLOR_t;

	stateTAYLOR_t state, state_next;
  //-----------------------------------------------------------//

  ///////////////////////////////////////////////////////////////
  //-------------------- sequential logic ---------------------//
	always @ (posedge clk)
	begin
		if (rst)
		begin
			state <= IDLE;
			valid_o <= 1'b0;
			rst_r <= 1'b1;
			padv_r <= 1'b0;
		end
		else
		begin
			rst_r <= 1'b0;
			state <= state_next;
			counter <= counter_next;

			padv_r <= padv_r_next;
			opcode_r <= opcode_r_next;
			op1_r <= op1_r_next;
			op2_r <= op2_r_next;

			pwr_acc <= pwr_acc_next;
			sum_tot <= sum_tot_next;
			res_temp <= res_temp_next;
			x <= x_next;

            data_o <= data_o_next;
            valid_o <= valid_o_next;
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

		padv_r_next = padv_r;
		opcode_r_next = opcode_r;
		op1_r_next = op1_r;
		op2_r_next = op2_r;

		pwr_acc_next = pwr_acc;
		sum_tot_next = sum_tot;
		res_temp_next = res_temp;
		x_next = x;

        data_o_next = data_o;
        valid_o_next = valid_o;

		case (state)

			IDLE: //-----------------------------------------------------------------PREPARATION
			begin  // calculates 1 + x which is used in all levels of approximation
				if (valid_i)
				begin
                    padv_r_next = 1'b0;
					x_next = data_i;  // x
					pwr_acc_next = data_i; // x
					opcode_r_next = FPU_IDLE;
					state_next = PRE_0;
				end
			end

			PRE_0:
			begin
				if (isReady_r)
				begin
					op1_r_next = ONE_CONST;  // 1
					op2_r_next = x;     // x
					opcode_r_next = FPU_ADD; // +
					state_next = PRE_1;
				end
			end

			PRE_1:
			begin
				if (isResultValid_r)
				begin
					sum_tot_next = result_r; // 1 + x
					if (TAYLOR_APPROX == 'd1) //stops at first level of approx.
					begin
						valid_o_next = 1'b1;
						data_o_next = result_r;
						state_next = DONE;
					end
					else
					begin
    				    counter_next = 'd0;
						padv_r_next = 1'b1;
						state_next = ITER_0;
					end
				end
			end

			ITER_0: //----------------------------------------------------------------ITERATIONS
			begin   //calculates power of x by accumulating consecutive multiplications with x
				padv_r_next = 1'b0;
				if (isReady_r)
				begin
					op1_r_next = x;       // x
					op2_r_next = pwr_acc;      // x^(counter+1)
					opcode_r_next = FPU_MUL;   // *
					state_next = ITER_1;
				end
			end

			ITER_1:
			begin
				if (isResultValid_r)
				begin
					pwr_acc_next = result_r; // x^(counter+2)
					padv_r_next = 1'b1;
					state_next = ITER_2;
				end
			end

			ITER_2:
			begin   //divides the power of x by the current iteration's factorial
				padv_r_next = 1'b0;
				if (isReady_r)
				begin
					op1_r_next = pwr_acc;   // x^(counter+2)
					op2_r_next = factorial; // 1/(counter+2)!
					opcode_r_next = FPU_MUL;
					state_next = ITER_3;
				end
			end

			ITER_3:
			begin
				if (isResultValid_r)
				begin
					res_temp_next = result_r; // (x^(counter+2))/(counter+2)!
					padv_r_next = 1'b1;
					state_next = ITER_4;
				end
			end

			ITER_4:
			begin   //sums contribution of current iteration with the previous ones
				padv_r_next = 1'b0;
				if (isReady_r)
				begin
					op1_r_next = res_temp; // (x^(counter+1))/(counter+1)!
					op2_r_next = sum_tot;  // 1 + x + previous iterations
					opcode_r_next = FPU_ADD;
					state_next = ITER_5;
				end
			end

			ITER_5:
			begin   //cheks if all iterations were made
				if (isResultValid_r)
				begin
					sum_tot_next = result_r; // 1 + x + all iterations
					if (counter + 2 == TAYLOR_APPROX)
					begin
						valid_o_next = 1'b1;
						data_o_next = result_r;
						state_next = DONE;
					end
					else
					begin
						counter_next = counter + 1;
						padv_r_next = 1'b1;
						state_next = ITER_0;
					end
				end
			end

      DONE:
      begin
          if (padv_i)
          begin
              pwr_acc_next = 'd0;
              sum_tot_next = 'd0;
              valid_o_next = 1'b0;
              padv_r_next = 1'b1;
              state_next = IDLE;
          end
      end

		endcase

	end
  //-----------------------------------------------------------//
  ///////////////////////////////////////////////////////////////

	assign ready_o = (state == IDLE) | valid_o;
    assign flush_r = 1'b0;
    assign rndMode_r = FPU_RNDMODE_NEAREST;

    always_comb
        factorial = FUNC_lut_factorial(counter);


	lampFPU_TAY_top
        lampFPU_TAY_top_0(
        .clk    (clk),
        .rst    (rst_r),
        .flush_i    (flush_r),
        .padv_i 	(padv_r),
        .opcode_i 	(opcode_r),
        .rndMode_i  (rndMode_r),
        .op1_i  (op1_r),
        .op2_i  (op2_r),
        .result_o           (result_r),
        .isResultValid_o    (isResultValid_r),
        .isReady_o 			(isReady_r)
    );

endmodule