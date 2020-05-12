`timescale 1ns / 1ps

module lampFPU_TAY_top_pro_tb();

    parameter LAMP_FLOAT_DW_16      = 16;
    parameter LAMP_FLOAT_F_DW_16    = 7;
    parameter L_SHORTREAL           = 32;

    import lampFPU_XXX_pkg::*;

    logic clk;
    logic rst = 1'b0;

    //input
    logic                       flush_i = 0;
    logic                       padv_i = 0;
    logic                       valid_i;
    rndModeFPU_t				rndMode_i = FPU_RNDMODE_NEAREST;
    logic [2:0]					approximation;
    logic [LAMP_FLOAT_DW-1:0]   data_i;
    //output
    logic [LAMP_FLOAT_DW-1:0]   data_o;
    logic                       valid_o;
    logic                       ready_o;

    int state = 0;

    const shortreal e = 2.71828174591064453125;  //e = 2.7182818284590452353... => 32'b0__1000_0000__0101_1011_1111_0000_1010_100
    const shortreal reclog2e = 0.693147182464599609375; //1/(log2(e)) = 0.69314718055994... => 32'b0__0111_1110__0110_0010_1110_0100_0011_000
    const logic [L_SHORTREAL-1:0] zero = 'd0;
    int totw1=0,totw2=0,totw3=0,totw4=0,totw5=0,totw6=0,totw7=0;
    int countwrong = 0;
    int countwrong_neg = 0;
    logic neg;
    shortreal errsum = 0;
    shortreal mer1=0,mer2=0,mer3=0,mer4=0,mer5=0,mer6=0,mer7=0;

    logic [LAMP_FLOAT_DW_16-1:0]   data_temp;
    const logic [LAMP_FLOAT_DW_16-1:0]   data_init_neg  = 16'b1__0111_1111__0000_000; //from -1
    const logic[LAMP_FLOAT_DW_16-1:0]    data_max_neg   = 16'b1__0111_0110__0000_000; //to   -0.001953125     --> 1-   (max neg in out < 1)
    const logic [LAMP_FLOAT_DW_16-1:0]   data_init      = 16'b0__0111_0110__1111_111; //from 0.00389099121094 --> 1+   (min pos in out > 1)
    const logic[LAMP_FLOAT_DW_16-1:0]    data_max       = 16'b0__0111_1111__0000_000; //to   1
    logic [L_SHORTREAL-1:0]        data_temp_tornd;
    shortreal                      data_temp_real;
    int diff_bits_file;
    int data_file;
    int err_perc_file;
    string diff_bits_file_path  = "C:/Coding_Projects/ES_project/REPOSITORY/Error_analysis/Taylor_fast/25/diff_bits.csv";
    string data_file_path       = "C:/Coding_Projects/ES_project/REPOSITORY/Error_analysis/Taylor_fast/25/data_file.csv";
    string err_perc_file_path   = "C:/Coding_Projects/ES_project/REPOSITORY/Error_analysis/Taylor_fast/25/err_perc.csv";

    shortreal correct_result;
    shortreal correct_result_rounded_real_16;
    shortreal data_o_real;
    shortreal data_o_real_16;
    shortreal err_perc;
    shortreal err_perc_16;
    shortreal err_max_perc_pos = 0;
    shortreal err_max_perc_neg = 0;
    shortreal errore_perc;

    logic [L_SHORTREAL-1:0]                correct_result_bits;

    logic [(1+1+LAMP_FLOAT_F_DW+3)-1:0]    result_to_round;
    logic [LAMP_FLOAT_F_DW-1:0]            correct_result_f_rounded;
    logic [LAMP_FLOAT_DW-1:0]              correct_result_rounded;

    logic [(1+1+LAMP_FLOAT_F_DW_16+3)-1:0] result_to_round_16;
    logic [LAMP_FLOAT_F_DW_16-1:0]         correct_result_f_rounded_16;
    logic [LAMP_FLOAT_DW_16-1:0]           correct_result_rounded_16;

    logic [(1+1+LAMP_FLOAT_F_DW_16+3)-1:0] data_o_to_round_16;
    logic [LAMP_FLOAT_F_DW_16-1:0]         data_o_mantissa_rounded_16;
    logic [LAMP_FLOAT_DW_16-1:0]           data_o_rounded_16;

    logic[LAMP_FLOAT_DW_16-1:0] xor_result;
    int                         num_different_bits;

    //--------------------------------------------------------------------------------------------FUNCTIONS DEFINITION
    function automatic logic[LAMP_FLOAT_F_DW_16-1:0] FUNC_rndToNearestEven_16(
        input[(1/*ovf*/+1/*hidden*/+LAMP_FLOAT_F_DW_16+3/*G,R,S*/)-1:0]      f_res_postNorm
    );
        localparam NUM_BIT_TO_RND = 4;
        logic isAddOne;
        logic [(1+1+LAMP_FLOAT_F_DW_16+3)-1:0] tempF_1;
        logic [(1+1+LAMP_FLOAT_F_DW_16+3)-1:0] tempF;
        tempF_1 = f_res_postNorm;
        case(f_res_postNorm[3:1] /*3 bits X.G(S|R)*/ )
            3'b0_00:    begin tempF_1[3] = 0;   isAddOne =0; end
            3'b0_01:    begin tempF_1[3] = 0;   isAddOne =0; end
            3'b0_10:    begin tempF_1[3] = 0;   isAddOne =0; end
            3'b0_11:    begin tempF_1[3] = 1;   isAddOne =0; end
            3'b1_00:    begin tempF_1[3] = 1;   isAddOne =0; end
            3'b1_01:    begin tempF_1[3] = 1;   isAddOne =0; end
            3'b1_10:    begin tempF_1[3] = 1;   isAddOne =1; end
            3'b1_11:    begin tempF_1[3] = 1;   isAddOne =1; end
        endcase
        if(&tempF_1[3+:NUM_BIT_TO_RND])
            tempF = tempF_1 ;
        else
            tempF = tempF_1 + (isAddOne<<3);
        return tempF[3+:LAMP_FLOAT_F_DW_16];
    endfunction

    //--------------------------------------------------------------------------------------------CORDIC DEVICE UNDER TEST
    lampFPU_TAY_top dut (
        .clk (clk),
        .rst (rst),

        .flush_i (flush_i),
        .padv_i (padv_i),
        .valid_i (valid_i),
        .rndMode_i (rndMode_i),
        .approxLevel_i (approximation),
        .op_i (data_i),

        .result_o (data_o),
        .isResultValid_o (valid_o),
        .isReady_o (ready_o)
    );

    //--------------------------------------------------------------------------------------------INITIAL
    initial
    begin
        clk = 0;
        data_temp = data_init_neg;
        neg = 1'b1;
        flush_i = 1'b0;
        padv_i = 1'b0;
        valid_i = 1'b0;
        rndMode_i = FPU_RNDMODE_NEAREST;
        approximation = 'd1;
        //------------------------------------------DATA FILE RESET
        data_file = $fopen(data_file_path, "w");
        if(data_file)
        begin
            $display("file was reset succesfully: %d", data_file);
            $fclose(data_file);
        end
        else
            $display("file was NOT reset succesfully: %d", data_file);
        //------------------------------------------ERROR FILE RESET
        err_perc_file = $fopen(err_perc_file_path, "w");
        if(err_perc_file)
        begin
            $display("file was reset succesfully: %d", err_perc_file);
            $fclose(err_perc_file);
        end
        else
            $display("file was NOT reset succesfully: %d", err_perc_file);
        //------------------------------------------DIFFERENCE FILE RESET
        diff_bits_file = $fopen(diff_bits_file_path, "w");
        if(diff_bits_file)
        begin
            $display("file was reset succesfully: %d", diff_bits_file);
            $fclose(diff_bits_file);
        end
        else
            $display("file was NOT reset succesfully: %d", diff_bits_file);

    end
    always #5 clk = ~clk;

    //----------------------------------------------------------------------------------------------------ALWAYS
    always @ (posedge clk)
    begin

        case (state)
            //--------------------------------------------------------------------------------------------STATE 0
            0:
            begin
                rst = 1'b1;
                state <= 1;
            end
            //--------------------------------------------------------------------------------------------STATE 1
            1:
            begin
                rst <= 1'b0;
                padv_i <= 1'b0;
                if (ready_o)
                begin
                    if(data_temp > data_max && neg == 1'b0)
                    begin
                        if(approximation < 'd7)
                        begin
                            approximation = approximation + 'd1;
                            data_temp = data_init_neg;
                            neg = 1'b1;
                            countwrong = 0;
                            countwrong_neg = 0;
                            errsum = 0;
                            state = 0;
                        end
                        else
                            state <= 3;
                    end
                    else
                    begin
                        data_i = {data_temp, zero[(LAMP_FLOAT_DW-LAMP_FLOAT_DW_16)-1:0]};
                        valid_i = 1'b1;
                        state <= 2;
                    end
                end
            end
            //--------------------------------------------------------------------------------------------STATE 2
            2:
            begin
                valid_i <= 1'b0;
                if (valid_o)
                begin
                    //------------------------------------------------------------------------------------DATA FILE WRITING
                    //####################################################################################
                    data_file = $fopen(data_file_path, "a");
                    if(data_file)
                    begin
                        correct_result = e**$bitstoshortreal({data_i, zero[L_SHORTREAL-LAMP_FLOAT_DW-1:0]});
                        correct_result_bits = $shortrealtobits(correct_result);

                        //------------------------------------------N BIT ROUNDING
                        result_to_round = {2'b01, correct_result_bits[(L_SHORTREAL-9)-1-:(LAMP_FLOAT_F_DW+2)], | correct_result_bits[(L_SHORTREAL-LAMP_FLOAT_DW-2)-1:0]};
                        correct_result_f_rounded = FUNC_rndToNearestEven(result_to_round);
                        correct_result_rounded = {correct_result_bits[(L_SHORTREAL-1)-:9], correct_result_f_rounded};

                        //------------------------------------------16 BIT ROUNDING
                        result_to_round_16 = {2'b01, correct_result_bits[(L_SHORTREAL-9)-1-:(LAMP_FLOAT_F_DW_16+2)], | correct_result_bits[(L_SHORTREAL-LAMP_FLOAT_DW_16-2)-1:0]};
                        correct_result_f_rounded_16 = FUNC_rndToNearestEven_16(result_to_round_16);
                        correct_result_rounded_16 = {correct_result_bits[(L_SHORTREAL-1)-:9], correct_result_f_rounded_16};

                        case(LAMP_FLOAT_DW)
                        16: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:0], 3'b000};
                        17: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:0], 2'b00};
                        18: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:0], 1'b0};
                        19: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:0]};
                        20: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:2], | data_o[1:0]};
                        21: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:3], | data_o[2:0]};
                        22: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:4], | data_o[3:0]};
                        25: data_o_to_round_16 = {2'b01, data_o[LAMP_FLOAT_F_DW-1:7], | data_o[6:0]};
                        endcase
                        data_o_mantissa_rounded_16 = FUNC_rndToNearestEven_16(data_o_to_round_16);
                        data_o_rounded_16 = {data_o[LAMP_FLOAT_DW-1-:9], data_o_mantissa_rounded_16};

                        data_o_real = $bitstoshortreal({data_o, zero[L_SHORTREAL-LAMP_FLOAT_DW-1:0]});
                        err_perc = 100*(correct_result-data_o_real)/correct_result;

                        data_o_real_16 = $bitstoshortreal({data_o_rounded_16, 16'b0});
                        correct_result_rounded_real_16 = $bitstoshortreal({correct_result_rounded_16, 16'b0});
                        err_perc_16 = 100*(correct_result_rounded_real_16-data_o_real_16)/correct_result_rounded_real_16;

                        $display("File was opened successfully : %0d", data_file);
                        $fdisplay(data_file, "%b,%b,%b,%b,%b", data_i, data_o, correct_result_rounded, data_o_rounded_16, correct_result_rounded_16);
                        if(data_temp == data_max)
                            $fdisplay(data_file, "%b,%b,%b,%b,%b", data_i, data_o, correct_result_rounded, data_o_rounded_16, correct_result_rounded_16);
                        $fclose(data_file);

                        if(neg)
                        begin
                            if(data_temp > data_max_neg)
                                data_temp <= data_temp - 16'd1;
                            else
                                begin
                                    neg <= 1'b0;
                                    data_temp = data_init;
                                end
                        end
                        else
                            data_temp <= data_temp + 16'd1;

                    end
                    else
                    begin
                        $display("File was NOT opened successfully : %0d", data_file);
                        $finish;
                    end
                    //####################################################################################

                    //------------------------------------------------------------------------------------ERROR FILE WRITING
                    //####################################################################################
                    err_perc_file = $fopen(err_perc_file_path, "a");
                    if(err_perc_file)
                    begin
                         $fdisplay(err_perc_file, "%f,%f", err_perc, err_perc_16);
                         if(data_temp == data_max)
                            $fdisplay(err_perc_file, "%f,%f", 2, 2);
                         $fclose(err_perc_file);
                    end
                    else
                    begin
                        $display("File was NOT opened successfully : %0d", err_perc_file);
                    end
                    //####################################################################################

                    //------------------------------------------------------------------------------------DIFFERENT BIT FILE WRITING
                    //####################################################################################
                    xor_result = data_o_rounded_16 ^ correct_result_rounded_16;
                    num_different_bits = $countones(xor_result);
                    diff_bits_file = $fopen(diff_bits_file_path, "a");
                    if(diff_bits_file)
                    begin
                        if(num_different_bits > 0)
                        begin
                            $fdisplay(diff_bits_file, "diff.bits 16: %d\ndataIN: %b   %f\nN OUT : %b   16OUT : %b\nN REAL: %b   16REAL: %b\nN err : %f               16 err: %f\n", num_different_bits, data_i, $bitstoshortreal({data_i, zero[L_SHORTREAL-LAMP_FLOAT_DW-1:0]}), data_o, data_o_rounded_16, correct_result_rounded, correct_result_rounded_16, err_perc, err_perc_16);
                            if(neg)
                                countwrong_neg = countwrong_neg + 1;
                            else
                                countwrong = countwrong + 1;
                            if(err_perc_16>0)
                                errsum = errsum + err_perc_16;
                            else
                                errsum = errsum - err_perc_16;
                        end
                        if(data_temp == data_max)
                        begin
                            $fdisplay(diff_bits_file, "WRONG POS =   %d\nWRONG NEG =   %d\nTOTAL WRONG = %d",countwrong ,countwrong_neg, countwrong_neg+countwrong);
                            $fdisplay(diff_bits_file, "!!! XXXXXXXXXXXXXXX end of approximation %d wrong values XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", approximation);
                            case(approximation)
                                1: begin totw1 = countwrong_neg + countwrong; mer1 = errsum/(countwrong_neg + countwrong); end
                                2: begin totw2 = countwrong_neg + countwrong; mer2 = errsum/(countwrong_neg + countwrong); end
                                3: begin totw3 = countwrong_neg + countwrong; mer3 = errsum/(countwrong_neg + countwrong); end
                                4: begin totw4 = countwrong_neg + countwrong; mer4 = errsum/(countwrong_neg + countwrong); end
                                5: begin totw5 = countwrong_neg + countwrong; mer5 = errsum/(countwrong_neg + countwrong); end
                                6: begin totw6 = countwrong_neg + countwrong; mer6 = errsum/(countwrong_neg + countwrong); end
                                7: begin totw7 = countwrong_neg + countwrong; mer7 = errsum/(countwrong_neg + countwrong); end
                            endcase
                            if(approximation == 'd7)
                                $fdisplay(diff_bits_file,"TOT approx 1 = %d\n%f\nTOT approx 2 = %d\n%f\nTOT approx 3 = %d\n%f\nTOT approx 4 = %d\n%f\nTOT approx 5 = %d\n%f\nTOT approx 6 = %d\n%f\nTOT approx 7 = %d\n%f\n",totw1,mer1,totw2,mer2,totw3,mer3,totw4,mer4,totw5,mer5,totw6,mer6,totw7,mer7);
                        end
                        $fclose(diff_bits_file);
                    end
                    else
                        $display("file was NOT opened succesfully: %d", diff_bits_file);
                    //####################################################################################

                    padv_i <= 1'b1;
                    state <= 1;
                end
            end
            //--------------------------------------------------------------------------------------------STATE 3
            default:
            begin
                valid_i <= 1'b0;
                $finish;
            end

        endcase

    end

endmodule
