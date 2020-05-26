`timescale 1ns / 1ps

module exponenial_tb4();

	parameter REAL_LENGHT = 32;

	import exponential_pkg_scrap::*;

	logic	clk;
	logic	rst;

	logic							padv_i;
	logic							valid_i;
	logic	[LAMP_FLOAT_DW-1:0]	    data_i;

	logic							ready_o;
	logic	[LAMP_FLOAT_DW-1:0]	    data_o;
	logic							valid_o;

	// logic	[2:0]					approx;

	int		wrong_data_file;
	int		data_file;
	int		err_perc_file;
	string	wrong_data_file_path	=	"C:/Users/matti/Desktop/AAAAA/wrong_data_file.csv";
	string	data_file_path			=	"C:/Users/matti/Desktop/AAAAA/data_file.csv";
	string	err_perc_file_path		=	"C:/Users/matti/Desktop/AAAAA/err_perc_file.csv";

	const shortreal     e       = 2.71828174591064453125;  //e = 2.7182818284590452353... => 32'b0__1000_0000__0101_1011_1111_0000_1010_100
	const logic [REAL_LENGHT-1:0] 	zero 	= 'd0;

	const logic [LAMP_FLOAT_DW-1:0]	d_init_n	=	16'b1_1000_0101_011_1000; //-92
	const logic [LAMP_FLOAT_DW-1:0]	d_max_n		=	16'b1_0111_0111_000_0000; //-0.00390625     1849 neg + 1849 pos
	const logic [LAMP_FLOAT_DW-1:0]	d_init_p	=	16'b0_0111_0111_000_0000; //0.00390625      tot data = 3692 + 1
	const logic [LAMP_FLOAT_DW-1:0]	d_max_p		=	16'b0_1000_0101_011_0010; //89
//	const logic [LAMP_FLOAT_DW-1:0]	d_init_n	=    16'b1_0111_1111_000_0000; //-1
//    const logic [LAMP_FLOAT_DW-1:0] d_max_n     =    16'b1_0111_1010_000_0000; //-0.03125
//    const logic [LAMP_FLOAT_DW-1:0] d_init_p    =    16'b0_0111_1010_000_0000; //+0.03125
//    const logic [LAMP_FLOAT_DW-1:0] d_max_p     =    16'b0_0111_1111_000_0000; //+1

	// const logic [2:0]				approx_init =	;
	// const logic [2:0]				approx_max  =	;

	int 	state = 0;

	logic	pos	= 1'b0;
	logic	isWrong = 1'b0;

	logic	[LAMP_FLOAT_DW-1:0]		data_temp;

	shortreal							r_correct_result;
	logic	[REAL_LENGHT-1:0]			r_correct_result_bits;
	logic	[LAMP_FLOAT_DW-1:0] 		correct_result_bits;
	shortreal							correct_result;
	shortreal							r_data_o;

	shortreal	err_perc, err_perc_approx;

	shortreal	tot_err = 0, tot_err_approx = 0;
	shortreal	mean_err, mean_err_approx;
	shortreal	totdata = 0, totwrong = 0;


	initial
	begin
		clk = 1'b0;

		data_file = $fopen(data_file_path, "w");
		if(data_file) begin
			$display("file was reset succesfully: %d", data_file); $fclose(data_file);
		end else
			$display("file was NOT reset succesfully: %d", data_file);

		wrong_data_file = $fopen(wrong_data_file_path, "w");
		if(wrong_data_file) begin
			$display("file was reset succesfully: %d", wrong_data_file); $fclose(wrong_data_file);
		end else
			$display("file was NOT reset succesfully: %d", wrong_data_file);

		err_perc_file = $fopen(err_perc_file_path, "w");
		if(err_perc_file) begin
			$display("file was reset succesfully: %d", err_perc_file); $fclose(err_perc_file);
		end else
			$display("file was NOT reset succesfully: %d", err_perc_file);
	end
	always #5 clk = ~clk;

	initial
	begin
		rst <= 1'b1;
		state <= 0;
		padv_i <= 1'b0;
		data_temp = d_init_n;
		// approx <= approx_init;
	end
	always @ (posedge clk)
	begin
		case (state)
			0:
			begin
				rst <= 1'b0;
				state <= 1;
			end

			1:
			begin
				padv_i <= 1'b0;
				if(ready_o)
				begin
					if((pos == 1'b1) && (data_temp > d_max_p)) // end of all input data per approx
					begin
						// if(approx < approx_max) // not end of all iterations
						// begin
						// 	approx = approx + 'd1;
						// 	data_temp = d_init_n;
						// 	pos = 0;
						// 	totwrong = 0;
						// 	totdata = 0;
						// end
						// else
							state = 3;
					end
					else
					begin
						data_i = data_temp;
						valid_i <= 1'b1;
						state <= 2;
					end
				end
			end

			2:
			begin
				valid_i <= 1'b0;
				if(valid_o)
				begin
					r_correct_result = e**$bitstoshortreal({data_i, zero[(REAL_LENGHT-16)-1:0]});
					r_correct_result_bits = $shortrealtobits(r_correct_result);
					correct_result_bits = {r_correct_result_bits[(REAL_LENGHT-1)-:(1+8)], FUNC_rndToNearestEven({2'b01, r_correct_result_bits[(REAL_LENGHT-9-1)-:(7+2)], | r_correct_result_bits[(REAL_LENGHT-9-7-2)-1:0]})};
					correct_result = $bitstoshortreal({correct_result_bits, zero[(REAL_LENGHT-16)-1:0]});

					r_data_o = $bitstoshortreal({data_o, zero[(REAL_LENGHT-16)-1:0]});

					err_perc = 100*(r_correct_result-r_data_o)/r_correct_result;
					err_perc_approx = 100*(correct_result-r_data_o)/correct_result;

					totdata = totdata + 1;
					if(err_perc < 0)
						tot_err = tot_err - err_perc;
					if(err_perc > 0)
						tot_err = tot_err + err_perc;
					if(err_perc_approx < 0)
						tot_err_approx = tot_err_approx - err_perc_approx;
					if(err_perc_approx > 0)
						tot_err_approx = tot_err_approx + err_perc_approx;

					isWrong = | (correct_result_bits ^ data_o);

					//############################################################################################
					data_file = $fopen(data_file_path, "a");
                    if(data_file)
                    begin
						$display("File was opened successfully : %0d", data_file);
						$fdisplay(data_file, "%b,%b,%b", data_i, data_o, correct_result_bits);
						if(data_i == d_max_p)
							$fdisplay(data_file, "%b,%b,%b", 16'd0, 16'd0, 16'd0);
						$fclose(data_file);
					end
					else
					begin
						$display("DataFile was NOT opened successfully : %0d", data_file);
//						$finish;
					end
					//############################################################################################

					//############################################################################################
					err_perc_file = $fopen(err_perc_file_path, "a");
					if(err_perc_file)
					begin
						$fdisplay(err_perc_file, "%f,%f", err_perc, err_perc_approx);
						if(data_temp == d_max_p)
						   $fdisplay(err_perc_file, "%f,%f", 5, 5);
						$fclose(err_perc_file);
					end
					else
					begin
						$display("ErrFile was NOT opened successfully : %0d", err_perc_file);
//						$finish;
					end
					//############################################################################################

					//############################################################################################
                    wrong_data_file = $fopen(wrong_data_file_path, "a");
                    if(wrong_data_file)
                    begin
                        if(isWrong)
                        begin
                            totwrong = totwrong + 1;
                            $fdisplay(wrong_data_file, "IN DATA  : %b  :  %f\nOUT DATA : %b    REAL RESULT: %b\nreal error : %f    16 bit error : %f\n", data_i, $bitstoshortreal({data_i, zero[REAL_LENGHT-16-1:0]}), data_o, correct_result_bits, err_perc, err_perc_approx);
                        end
                        if(data_temp == d_max_p)
                        begin
                            mean_err = tot_err/totwrong;
                            mean_err_approx = tot_err_approx/totwrong;
                            $fdisplay(wrong_data_file, "total number of results = %f    total wrong = %f", totdata, totwrong);
                            $fdisplay(wrong_data_file, "mean real error = %f    mean 16 bit error = %f", mean_err, mean_err_approx);
                        end
                        $fclose(wrong_data_file);
                    end
                    else
                    begin
                        $display("WrongFile was NOT opened successfully : %0d", wrong_data_file);
//							$finish;
                    end
					//############################################################################################

					if(pos)
						data_temp = data_temp + 16'b0__0000_0000__0000_001;
					else
					begin
						if(data_temp > d_max_n)
							data_temp = data_temp - 16'b0__0000_0000__0000_001;
						else
						begin
							pos = 1'b1;
							data_temp = d_init_p;
						end
					end

					padv_i <= 1'b1;
					state <= 1;
				end
			end

			3:
			begin
                $finish;
			end

			default: ;
		endcase
	end


	exponential_top dut (
        .clk (clk),
        .rst (rst),

        .padv_i (padv_i),
        .valid_i (valid_i),
        .data_i (data_i),

        .ready_o (ready_o),
        .data_o (data_o),
        .valid_o (valid_o)

		// .approx (approx),
    );

endmodule
