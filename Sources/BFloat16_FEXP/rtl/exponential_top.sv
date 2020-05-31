`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Di Fabio, Ferraresi, Martignoni
//
// Create Date: 28.04.2020 19:08:24
// Design Name:
// Module Name: exponential_top
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


module exponential_top(
    clk, rst,
    padv_i, valid_i, data_i,
    ready_o, data_o, valid_o
    );

    import exponential_pkg::*;

    input                               clk;
    input                               rst;
    input                               padv_i;
    input                               valid_i;
    input           [LAMP_FLOAT_DW-1:0] data_i;
    output logic                        ready_o;
    output logic    [LAMP_FLOAT_DW-1:0] data_o;
    output logic                        valid_o;

    //////////////////////////////////////////////////
    //          connection with submodules          //
    //////////////////////////////////////////////////

    logic                                   rst_top;
    logic                                   flush_top;
    logic                                   padv_top, padv_top_next;
    opcodeFPU_t                             opcode_top, opcode_top_next;
    rndModeFPU_t                            rndMode_top;
    logic           [LAMP_FLOAT_MUL_DW-1:0] op1_top, op1_top_next;
    logic           [LAMP_FLOAT_MUL_DW-1:0] op2_top, op2_top_next;
    logic           [LAMP_FLOAT_MUL_DW-1:0] result_top;
    logic                                   isResultValid_top;
    logic                                   isReady_top;

    logic                       	rst_tay;
    logic                       	padv_tay, padv_tay_next;
    logic                       	valid_i_tay, valid_i_tay_next;
    logic [LAMP_FLOAT_TAY_DW-1:0]   data_i_tay, data_i_tay_next;
    logic                       	ready_o_tay;
    logic [LAMP_FLOAT_TAY_DW-1:0]   data_o_tay;
    logic                       	valid_o_tay;

    logic           flush_tay;
    rndModeFPU_t    rndMode_tay;
    logic   [2:0]   approxLevel_tay;

    //////////////////////////////////////////////////
    //              logic for algorithm             //
    //////////////////////////////////////////////////

//    parameter log2e =       32'b0_01111111_0111000_1010101000111011; //1.44269502162933349609375 (already approx)
//    parameter inv_log2e =   32'b0_01111110_0110001_0111001000011000; //0.693147182464599609375 (already approx)

    parameter log2e =       25'b0_01111111_0111000_101010100; //1.44269502162933349609375 (already approx)
    parameter inv_log2e =   25'b0_01111110_0110001_011100100; //0.693147182464599609375 (already approx)

    logic [LAMP_FLOAT_MUL_DW-1:0]   Z, Z_next;
    logic [LAMP_FLOAT_E_DW-1:0]     Ez, Ez_next;
    logic [LAMP_FLOAT_E_DW-1:0]     Zi, Zi_next;
    logic [LAMP_FLOAT_MUL_DW-1:0]   Zf, Zf_next;
    logic [$clog2(LAMP_FLOAT_MUL_F_DW+1)-1:0] shCount, shCount_next;

    logic [LAMP_FLOAT_DW-1:0]   data_i_r, data_i_r_next;
    logic                       valid_o_next;
    logic [LAMP_FLOAT_DW-1:0]   data_o_next;

    typedef enum logic[2:0]{
        IDLE =  3'd0,
        RR1 =   3'd1,
        RR2 =   3'd2,
        TAY =   3'd3,
        RREND = 3'd4,
        DONE =  3'd5
    } state_t;

    state_t  state, state_next;

    logic [5-1:0] checkInput;

    logic [LAMP_FLOAT_E_DW+1-1:0]   e_op1_ext, e_op2_ext;
    logic [LAMP_FLOAT_F_DW+1-1:0]   f_op1_ext, f_op2_ext;
    logic                           directPath;
    logic [LAMP_FLOAT_DW-1:0]   min_in_pos = 16'b0_0111_0111_000_0000; //3.906250e-03 (for lower positive inputs the result is best approximable to 1 with 16 bits)
    logic [LAMP_FLOAT_DW-1:0]   max_in_pos = 16'b0_1000_0101_011_0010; //89 (for higher positive inputs the result is not representable with 16 bits best approximable with +inf)
    logic [LAMP_FLOAT_DW-1:0]   min_in_neg = 16'b1_0111_0110_000_0001; //-1.968384e-03 (for higher negative inputs the result is best approximate by 1 with 16 bits)
    logic [LAMP_FLOAT_DW-1:0]   max_in_neg = 16'b1_1000_0101_011_1001; //-93 (for lower negative inputs the result is not representable with 16 bits best approximable with 0)

    //////////////////////////////////////////////////
    //               sequential logic               //
    //////////////////////////////////////////////////

    always @(posedge clk)
    begin
        if(rst)
        begin
            state <= IDLE;
            valid_o <= 'd0;

            rst_top <= 1'b1;
            padv_top <= 1'b0;
            opcode_top = FPU_IDLE;

            rst_tay <= 1'b1;
            padv_tay <= 1'b0;
            valid_i_tay <= 1'b0;
        end

        else
        begin
            state <= state_next;

            rst_top <= 1'b0;
            padv_top <= padv_top_next;
            opcode_top <= opcode_top_next;
            op1_top <= op1_top_next;
            op2_top <= op2_top_next;

            rst_tay <= 1'b0;
            padv_tay <= padv_tay_next;
            valid_i_tay <= valid_i_tay_next;
            data_i_tay <= data_i_tay_next;

            Z <= Z_next;
            Ez <= Ez_next;
            Zi <= Zi_next;
            Zf <= Zf_next;
            shCount <= shCount_next;

            data_i_r <= data_i_r_next;
            valid_o <= valid_o_next;
            data_o <= data_o_next;
        end
    end

    //////////////////////////////////////////////////
    //              combinational logic             //
    //////////////////////////////////////////////////

    always_comb
    begin
        state_next = state;

        padv_top_next = padv_top;
        opcode_top_next = opcode_top;
        op1_top_next = op1_top;
        op2_top_next = op2_top;

        padv_tay_next = padv_tay;
        valid_i_tay_next = valid_i_tay;
        data_i_tay_next = data_i_tay;

        Z_next = Z;
        Ez_next = Ez;
        Zi_next = Zi;
        Zf_next = Zf;
        shCount_next = shCount;

        data_i_r_next = data_i_r;
        valid_o_next = valid_o;
        data_o_next = data_o;

        case(state)
            //////////////////////////////////////////////////
            //                      IDLE                    //
            //////////////////////////////////////////////////
            IDLE:
            begin
                if(valid_i)
                begin
                    data_i_r_next = data_i;
                    checkInput = FUNC_checkOperand(data_i_r_next); //{isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op}

                    if(checkInput == 'b00000)
                    begin
                        opcode_top_next = FPU_IDLE;
                        padv_top_next = 1'b0;
                        shCount_next = 'd0;

                        //#############################################################################################################################################################
                        if(data_i_r_next[LAMP_FLOAT_DW-1]) //INPUT DATA IS NEGATIVE
                        begin
                            e_op2_ext = {1'b0, data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]};
                            f_op2_ext = {1'b1, data_i_r_next[LAMP_FLOAT_F_DW-1:0]};
                            // |data_i| < |min_in_neg| --> out = 1
                            if(FUNC_op1_GT_op2({1'b1, min_in_neg[LAMP_FLOAT_F_DW-1:0]}, {1'b0, min_in_neg[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]}, f_op2_ext, e_op2_ext)) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE 1
                            begin
                                data_o_next = 16'b0_0111_1111_000_0000;
                                valid_o_next = 1'b1;
                                state_next = DONE;
                            end
                            // |data_i| > |max_in_neg| --> out = 0
                            else if(FUNC_op1_GT_op2(f_op2_ext, e_op2_ext, {1'b1, max_in_neg[LAMP_FLOAT_F_DW-1:0]}, {1'b0, max_in_neg[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]})) //IF VERIFIED THEN WE ALREADY KNOW THE RESULT WILL BE 0
                            begin
                                data_o_next = 16'b0;
                                valid_o_next = 1'b1;
                                state_next = DONE;
                            end
                            // |data| < 1 --> no range reduction only taylor
                            else if(data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] < 'd127)
                            begin
                                Z_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}}; // bit extension to match multiplication bits
                                Zf_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                Zi_next = 'd0;
                                padv_tay_next = 1'b1;
                                state_next = TAY;
                                directPath = 1'b1;
                            end
                            else // |max_in_neg| < |data_i| < 1 --> range reduction + taylor
                            begin
                                if(isReady_top)
                                begin
                                    directPath = 1'b0;
                                    op1_top_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}}; // bit extension to match multiplication bits
                                    op2_top_next = log2e;
                                    opcode_top_next = FPU_MUL; //Z = data_in*log2(e)
                                    state_next = RR1;
                                end
                            end
                        end
                        //#############################################################################################################################################################
                        else //INPUT DATA IS POSITIVE
                        begin
                            e_op2_ext = {1'b0, data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]};
                            f_op2_ext = {1'b1, data_i_r_next[LAMP_FLOAT_F_DW-1:0]};
                            // data_i < min_in_pos --> out = 1
                            if(FUNC_op1_GT_op2({1'b1, min_in_pos[LAMP_FLOAT_F_DW-1:0]}, {1'b0, min_in_pos[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]}, f_op2_ext, e_op2_ext)) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE 1
                            begin
                                data_o_next = 16'b0_0111_1111_000_0000;
                                valid_o_next = 1'b1;
                                state_next = DONE;
                            end
                            // data_i > max_in_pos --> out = +inf
                            else if(FUNC_op1_GT_op2(f_op2_ext, e_op2_ext, {1'b1, max_in_pos[LAMP_FLOAT_F_DW-1:0]}, {1'b0, max_in_pos[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]})) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE INFINITE
                            begin
                                data_o_next = {1'b0, INF};
                                valid_o_next = 1'b1;
                                state_next = DONE;
                            end
                            // data_i < 1 --> no range reduction only taylor
                            else if(data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] < 'd127)
                            begin
                                Z_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}}; // bit extension to match multiplication bits
                                Zf_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                Zi_next = 'd0;
                                padv_tay_next = 1'b1;
                                state_next = TAY;
                                directPath = 1'b1;
                            end
                            else // max_in_pos > data_i > 1 --> range reduction + taylor
                            begin
                                if(isReady_top)
                                begin
                                    directPath = 1'b0;
                                    op1_top_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}}; // bit extension to match multiplication bits
                                    op2_top_next = log2e;
                                    opcode_top_next = FPU_MUL; //Z = data_in*log2(e)
                                    state_next = RR1;
                                end
                            end
                        end
                        //#############################################################################################################################################################
                    end

                    else // excepion input cases
                    begin
                        valid_o_next = 1'b1;
                        state_next = DONE;
                        case(checkInput)
                            5'b10000:
                            begin
                                if(data_i_r_next == {1'b0, INF}) //in = +inf --> out = +inf
                                    data_o_next = {1'b0, INF};
                                else if(data_i_r_next == {1'b1, INF}) //in = -inf --> out = 0
                                    data_o_next = {1'b0, ZERO};
                            end
                            5'b01000: begin data_o_next = 16'b0_0111_1111_0000000;  end //in = denorm --> out = 1
                            5'b00100: begin data_o_next = 16'b0_0111_1111_0000000;  end //in = 0 --> out = 1
                            5'b00010: begin data_o_next = {1'b0, SNAN};             end //in = SNAN --> out = SNAN
                            5'b00001: begin data_o_next = {1'b0, QNAN};             end //in = QNAN --> out = QNAN
                        endcase
                    end
                end
            end
            //////////////////////////////////////////////////
            //                      RR 1                    //
            //////////////////////////////////////////////////
            RR1:
            begin
                if(isResultValid_top)
                begin
                    Z_next = result_top;
                    Ez_next = result_top[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW] - 'd127; //subtracting exponential's bias
                    state_next = RR2;
                    case(Ez_next) //since out = 2^(Zi)*exp(Zf/log2(e)), Z floating point is divided in a fixed point format with interger part Zi and fractional part Zf (considering that Zf will be reconverted in floating point)
                        'd0:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-1{1'b0}}, 1'b1}; //SEVEN 0, ONE 1 (HIDDEN BIT)
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = result_top[LAMP_FLOAT_MUL_F_DW-1:0]; //the bits of mantissa not shifted in the exponential (integer part)
                        end
                        'd1:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-2{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1]}; //SIX 0, ONE 1(HIDDEN BIT), 7TH BIT OF MANTISSA (UPDATED FOR EXTENSION)
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-2:0], 1'b0};
                        end
                        'd2:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-3{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-2]}; //FIVE 0, ONE 1 (HIDDEN BIT), 7TH AND 6TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-3:0], 2'b0};
                        end
                        'd3:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-4{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-3]}; //FOUR 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-4:0], 3'b0};
                        end
                        'd4:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-5{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-4]}; //THREE 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH 4TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-5:0], 4'b0};
                        end
                        'd5:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-6{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-5]}; //TWO 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-6:0], 5'b0};
                        end
                        'd6:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-7{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-6]}; //ONE 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD 2ND BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-7:0], 6'b0};
                        end
                        'd7:
                        begin
                            Zi_next = {1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-7]}; //ONE 1, 7TH 6TH 5TH 4TH 3RD 2ND 1ST BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-8:0], 7'b0};
                        end
                    endcase
                    padv_top_next = 1'b1;
                    opcode_top_next = FPU_IDLE;
                end
            end
            //////////////////////////////////////////////////
            //                      RR 2                    //
            //////////////////////////////////////////////////
            RR2:
            begin
                padv_top_next = 1'b0;
                if(!(|Zf[LAMP_FLOAT_MUL_F_DW-1:0])) // Z's fractional part = 0 --> out = 2^(Zi)*exp(Zf/log2(e)) = 2^Zi (taylor is not used)
                    begin
                        if(Z[LAMP_FLOAT_MUL_DW-1]) //negative
                        begin
                            if(Zi < 8'd127) //Zi is set as the exponent (considering the bias)
                            begin
                                data_o_next = {1'b0, 8'd127 - Zi, 7'd0};
                            end
                            else if(Zi < 8'd134) //the result is denormalized
                            begin
                                case(Zi)
                                8'd127 : data_o_next = {1'b0, 8'b0, 7'b1000000};
                                8'd128 : data_o_next = {1'b0, 8'b0, 7'b0100000};
                                8'd129 : data_o_next = {1'b0, 8'b0, 7'b0010000};
                                8'd130 : data_o_next = {1'b0, 8'b0, 7'b0001000};
                                8'd131 : data_o_next = {1'b0, 8'b0, 7'b0000100};
                                8'd132 : data_o_next = {1'b0, 8'b0, 7'b0000010};
                                8'd133 : data_o_next = {1'b0, 8'b0, 7'b0000001};
                                endcase
                            end
                            else //the result cant be represented with 16 bits --> out = 0
                            begin
                                data_o_next = 16'd0;
                            end
                        end
                        else //positive
                        begin
                            if(Zi < 8'd128) //Zi is set as the exponent (considering the bias)
                            begin
                                data_o_next = {1'b0, 8'd127 + Zi, 7'd0};
                            end
                            else //the result cant be represented with 16 bits --> out = +inf
                            begin
                                data_o_next = {1'b0, INF};
                            end
                        end
                        valid_o_next = 1'b1;
                        state_next = DONE;
                    end

                    else// converts Zf to float (Z's fractional part != 0) and multiplies it with 1/log2(e)
                    begin
                        if(isReady_top)
                        begin
                            Zf_next[LAMP_FLOAT_MUL_DW-1] = Z[LAMP_FLOAT_MUL_DW-1]; //sign
                            shCount = FUNC_MUL_numLeadingZeros({Zf[LAMP_FLOAT_MUL_F_DW-1:0], 1'b0});
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = FUNC_MUL_shiftMantissa(Zf[LAMP_FLOAT_MUL_F_DW-1:0], shCount); //shifted left to normalize (hidden bit)
                            Zf_next[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW] = 8'd127 - (shCount + 1); // number of shifts is the exponent

                            op1_top_next = Zf_next;
                            op2_top_next = inv_log2e;
                            opcode_top_next = FPU_MUL;
                            state_next = TAY;
                            padv_tay_next = 1'b1;
                        end
                    end
            end
            //////////////////////////////////////////////////
            //                      TAY                     //
            //////////////////////////////////////////////////
            TAY:
            begin
                padv_tay_next = 1'b0;
                if(ready_o_tay)
                begin
                    if(directPath)
                    begin
                        data_i_tay_next = {Zf[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, Zf[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-1], | Zf[LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-2:0]})};
                        valid_i_tay_next = 1'b1;
                        state_next = RREND;
                    end
                    else if(isResultValid_top)
                    begin
                        data_i_tay_next = {result_top[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-1], | result_top[LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-2:0]})};
                        valid_i_tay_next = 1'b1;
                        state_next = RREND;
                    end
                end
            end
            //////////////////////////////////////////////////
            //                     RREND                    //
            //////////////////////////////////////////////////
            RREND:
            begin

                valid_i_tay_next = 1'b0;

                if(valid_o_tay)
                begin
                    valid_o_next = 1'b1;
                    state_next = DONE;

                    if(Z[LAMP_FLOAT_MUL_DW-1]) //UPDATE FOR EXTENSION
                    begin
                        if(Zi < data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW]) //no underflow
                        begin
                            data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] - Zi, FUNC_rndToNearestEven({1'b0, 1'b1, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:(LAMP_FLOAT_F_DW+2)], | data_o_tay[LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-2:0]})};
                        end
                        else if(Zi < data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] + 8'd7)
                        begin
                            case(Zi - data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW])                      //0.00000001.0101111_0101
                               'd0: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 1'b1, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:8], | data_o_tay[LAMP_FLOAT_TAY_F_DW-8-1:0]})};
                               'd1: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 2'b01, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:7], | data_o_tay[LAMP_FLOAT_TAY_F_DW-7-1:0]})};
                               'd2: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 3'b001, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:6], | data_o_tay[LAMP_FLOAT_TAY_F_DW-6-1:0]})};
                               'd3: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 4'b0001, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:5], | data_o_tay[LAMP_FLOAT_TAY_F_DW-5-1:0]})};
                               'd4: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 5'b00001, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:4], | data_o_tay[LAMP_FLOAT_TAY_F_DW-4-1:0]})};
                               'd5: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 6'b000001, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:3], | data_o_tay[LAMP_FLOAT_TAY_F_DW-3-1:0]})};
                               'd6: data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], 8'd0, FUNC_rndToNearestEven({1'b0, 1'b1, 7'b0000001, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:2], | data_o_tay[LAMP_FLOAT_TAY_F_DW-2-1:0]})};
                            endcase
                        end
                        else
                        begin
                            data_o_next = 16'b0;
                        end
                        end

                    else
                    begin
                        if(data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] + Zi < 8'd255) //no overflow
                        begin
                            data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] + Zi, FUNC_rndToNearestEven({1'b0, 1'b1, data_o_tay[(LAMP_FLOAT_TAY_F_DW-1)-:LAMP_FLOAT_F_DW+2], | data_o_tay[LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-2:0]})};
                        end
                        else
                        begin
                            data_o_next = {1'b0, INF};
                        end
                    end

                end
            end
            //////////////////////////////////////////////////
            //                      DONE                    //
            //////////////////////////////////////////////////
            DONE:
            begin
                if(padv_i)
                begin
                    valid_o_next = 1'b0;
                    state_next = IDLE;

                    padv_top_next = 1'b1;
                    opcode_top_next = FPU_IDLE;
                end
            end

        endcase
    end

    assign ready_o = (state == IDLE) | valid_o;
    assign flush_top = 1'b0;
    assign rndMode_top = FPU_RNDMODE_NEAREST;

    assign flush_tay = 1'b0;
    assign rndMode_tay = FPU_RNDMODE_NEAREST;
    assign approxLevel_tay = TAYLOR_APPROX;

    //////////////////////////////////////////////////
    //                  submodules                  //
    //////////////////////////////////////////////////

    lampFPU_EXP_top lampFPU_EXP_top_0(
        .clk               (clk),
        .rst               (rst_top),
        .flush_i           (flush_top),
        .padv_i            (padv_top),
        .opcode_i          (opcode_top),
        .rndMode_i         (rndMode_top),
        .op1_i             (op1_top),
        .op2_i             (op2_top),
        .result_o          (result_top),
        .isResultValid_o   (isResultValid_top),
        .isReady_o         (isReady_top)
    );

    lampFPU_TAY_top lampFPU_TAY_top_0(
        .clk                (clk),
        .rst                (rst_tay),
        .flush_i            (flush_tay),
        .padv_i             (padv_tay),
        .valid_i            (valid_i_tay),
        .rndMode_i          (rndMode_tay),
        .approxLevel_i      (approxLevel_tay),
        .op_i               (data_i_tay),
        .result_o           (data_o_tay),
        .isResultValid_o    (valid_o_tay),
        .isReady_o          (ready_o_tay)
    );

endmodule
