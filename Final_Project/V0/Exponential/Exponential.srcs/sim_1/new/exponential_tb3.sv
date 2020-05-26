`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 29.04.2020 12:43:52
// Design Name:
// Module Name: range_reduction_tb
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


module exponential_tb3();

    //import exponential_pkg::*;
    import exponential_pkg_scrap::*;

    logic                       clk;
    logic                       rst;
    logic                       padv_i;
    logic                       valid_i;
    logic [LAMP_FLOAT_DW-1:0]   data_i;
    logic                       ready_o;
    logic [LAMP_FLOAT_DW-1:0]   data_o;
    logic                       valid_o;

    exponential_top dut(
        .clk        (clk),
        .rst        (rst),
        .padv_i     (padv_i),
        .valid_i    (valid_i),
        .data_i     (data_i),
        .ready_o    (ready_o),
        .data_o     (data_o),
        .valid_o    (valid_o)
    );

    int state = 0;
    int data_file;
    int wrong_data_file;
    
    string data_file_path = "C:/Users/matti/Desktop/PPP/data_file.csv";
    //string data_file_path = "C:/Users/federico/Desktop/embedded_systems_verilog_tutorials/exponential_only_taylor_tests/data_file_neg.csv";
    //string data_file_path = "C:/Users/matti/Desktop/TEST/data_file_neg.csv";
    string wrong_data_file_path = "C:/Users/matti/Desktop/PPP/wrong_data_file.csv";
    
    shortreal e = 2.7182818284590;
    //shortreal e16 = 2.71875;
    
    shortreal err_perc;
    //shortreal err_perc16;
    
    shortreal correct_result;
    //shortreal correct_result16;
    
    logic[31:0] correct_result_bits;
    //logic[31:0] correct_result_bits16;
    
    logic[(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_F_DW+3/*G,R,S*/)-1:0] result_to_round;
    logic[LAMP_FLOAT_F_DW-1:0] correct_result_mantissa_rounded;
    logic[LAMP_FLOAT_DW-1:0]    correct_result_rounded_bits;
    shortreal                   correct_result_rounded;                   
    shortreal data_o_real;
    shortreal data_i_real;

    int data_count = 0, wrong_count = 0;

    always #5 clk = ~clk;

    initial
    begin
        data_file = $fopen(data_file_path, "w");
        if(data_file)
        begin
            $display("file was reset succesfully: %d", data_file);
            $fclose(data_file);
        end
        else
            $display("file was NOT reset succesfully: %d", data_file);
            
            wrong_data_file = $fopen(wrong_data_file_path, "w");
        if(data_file)
        begin
            $display("file was reset succesfully: %d", wrong_data_file);
            $fclose(wrong_data_file);
        end
        else
            $display("file was NOT reset succesfully: %d", wrong_data_file);

        clk <= 0;
        rst = 1;
        padv_i = 1'b1;
        data_i = 16'b0_0000_0000_000_0000;
        //data_i = 16'b1_0000_0000_000_0000;

        @(posedge clk);
        begin
            rst <= 1'b0;
            padv_i <= 1'b0;
        end
    end


        always @(posedge clk)
        begin
            case(state)
                0:
                begin
                    if(ready_o)
                    begin
                        if(data_i <= 16'b0_1111_1111_000_0000)
                        //if(data_i <= 16'b1_1111_1111_000_0000)
                        begin
                            data_i = data_i + 1;
                            valid_i = 1'b1;
                            state = 1;
                        end
                        else            //0000000000000000
                        begin
                            wrong_data_file = $fopen(wrong_data_file_path, "a");
                            if(wrong_data_file)
                            begin
                                $display("file was opened succesfully: %d", wrong_data_file);
                                $fdisplay(wrong_data_file, "tot data : %d    tot wrong : %d", data_count, wrong_count);
                                $fclose(wrong_data_file);
                            end
                            else
                            begin
                                $display("file was NOT opened succesfully: %d", data_file);
                            end
                            $finish;
                        end
                    end
                end
                1:
                begin
                    valid_i = 1'b0;
                    state = 2;
                end
                2:
                begin
                    if(valid_o)
                    begin
                        data_count = data_count + 1;
                    
                        data_i_real = $bitstoshortreal({data_i, 16'b0});
                        
                        correct_result = e**data_i_real;
                        //correct_result16 = e16**data_i_real;
                        
                        correct_result_bits = $shortrealtobits(correct_result);
                        //correct_result_bits16 = $shortrealtobits(correct_result16);
                        
                        result_to_round = {1'b0, 1'b1, correct_result_bits[22:14], | correct_result_bits[13:0]};
                        correct_result_mantissa_rounded = FUNC_rndToNearestEven(result_to_round);
                        correct_result_rounded_bits = {correct_result_bits[31:23], correct_result_mantissa_rounded};
                        
                        correct_result_rounded = $bitstoshortreal({correct_result_rounded_bits, 16'b0});
                        
                        data_o_real = $bitstoshortreal({data_o, 16'b0});
                        
                        if(correct_result_rounded_bits == 16'b0111111110000000 && data_o == 16'b0111111110000000)
                        begin
                            err_perc = 0;
                            //err_perc16 = 0;
                        end
                        else if(correct_result_rounded_bits == 16'b1111111110000000 && data_o == 16'b1111111110000000)
                        begin
                            err_perc = 0;
                            //err_perc16 = 0;
                        end
                        else if(correct_result_rounded_bits == 16'b0000000000000000 && data_o == 16'b0000000000000000)
                        begin
                            err_perc = 0;
                            //err_perc16 = 0;
                        end
                        else
                        begin
                            err_perc = (correct_result_rounded-data_o_real)/correct_result_rounded*100;
                            //err_perc16 = (correct_result16-data_o_real)/correct_result16*100;
                        end

                        data_file = $fopen(data_file_path, "a");
                        if(data_file)
                        begin
                            $display("file was opened succesfully: %d", data_file);
                            //$fdisplay(data_file, "%b,%e,%b,%e,%b,%e,%e,%b,%e,%e", data_i, data_i_real, data_o, data_o_real, correct_result_bits, correct_result, err_perc, correct_result_bits16, correct_result16, err_perc16);
                            $fdisplay(data_file, "%b,%e,%b,%e,%b,%e,%e", data_i, data_i_real, data_o, data_o_real, correct_result_rounded_bits, correct_result_rounded, err_perc);
                            $fclose(data_file);
                        end
                        else
                        begin
                            $display("file was NOT opened succesfully: %d", data_file);
                        end
                        
                        wrong_data_file = $fopen(wrong_data_file_path, "a");
                        if(wrong_data_file)
                        begin
                            $display("file was opened succesfully: %d", wrong_data_file);
                            
                            if(data_o != correct_result_rounded_bits)
                            begin
                                wrong_count = wrong_count + 1;
                                $fdisplay(wrong_data_file, "IN  : %b\nOUT : %b\nREAL: %b\nerror : %f", data_i, data_o, correct_result_rounded_bits, err_perc);
                            end
                            $fclose(wrong_data_file);
                        end
                        else
                        begin
                            $display("file was NOT opened succesfully: %d", data_file);
                        end
                        
                        state = 3;
                    end
                end
                3:
                begin
                    padv_i = 1'b1;
                    state = 4;
                end
                4:
                begin
                    padv_i = 1'b0;
                    state = 0;
                end
            endcase
        end

endmodule