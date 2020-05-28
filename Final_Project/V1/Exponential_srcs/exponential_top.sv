`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Di Fabio, Ferraresi, Martignoni
//
// Create Date: 28.04.2020 19:08:24
// Design Name:
// Module Name: range_reduction
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

    import exponential_pkg_scrap::*;

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

    logic           flush_tay;/////
    rndModeFPU_t    rndMode_tay;/////
    logic   [2:0]   approxLevel_tay;/////

    //////////////////////////////////////////////////
    //              logic for algorithm             //
    //////////////////////////////////////////////////

    parameter log2e =       32'b0_01111111_0111000_1010101000111011; //1.44269502162933349609375 (already approx)
    parameter inv_log2e =   32'b0_01111110_0110001_0111001000011000; //0.693147182464599609375 (already approx)

    logic [LAMP_FLOAT_MUL_DW-1:0]   Z, Z_next;
    logic [LAMP_FLOAT_E_DW-1:0]     Ez, Ez_next;
    logic [LAMP_FLOAT_E_DW-1:0]     Zi, Zi_next;
    logic [LAMP_FLOAT_MUL_DW-1:0]   Zf, Zf_next;
    //logic [7:0]                     shCount, shCount_next; //counter for the shifts of Zf mantissa WE CAN REDUCE THIS BECAUSE AT MAXIMUM shCount = 7 (?)
    logic [$clog2(LAMP_FLOAT_MUL_F_DW+1)-1:0] shCount, shCount_next;

    logic [LAMP_FLOAT_DW-1:0]   data_i_r, data_i_r_next;
    logic                       valid_o_next;
    logic [LAMP_FLOAT_DW-1:0]   data_o_next;

    typedef enum logic[3:0]{
        IDLE =      4'd0,
        STATE1 =    4'd1,
        STATE2 =    4'd2,
        STATE3 =    4'd3,
        STATE4 =    4'd4,
        STATE5 =    4'd5,
        STATE6 =    4'd6,
        STATE7 =    4'd7,
        STATE8 =    4'd8
    } state_t;

    state_t  state, state_next;

    logic [5-1:0] checkInput; //UPDATE 1.2: SHOULD WE ADD THE _next VERSION AND ACT ON IT?

    logic [LAMP_FLOAT_E_DW+1-1:0]   e_op1_ext, e_op2_ext; //UPDATE 1.3: SHOULD WE ADD THE _next VERSION AND ACT ON IT?
    logic [LAMP_FLOAT_F_DW+1-1:0]   f_op1_ext, f_op2_ext; //UPDATE 1.3: SHOULD WE ADD THE _next VERSION AND ACT ON IT?
    logic                           directPath; //UPDATE 1.3: IF THE INPUT NUMBER IS BETWEEN 0 AND 1 WE CAN SKIP SOME STATES (directPath = 1'b1 IN THIS CASE)
    //logic                           MUL_use;

    logic [LAMP_FLOAT_DW-1:0]   min_in_pos = 16'b0_0111_0111_000_0000; //0.00390625 ? l'utlimo valore in ingresso che da un'uscita pari a 1 (0.0040 da 1.qualcosa)
    logic [LAMP_FLOAT_DW-1:0]   max_in_pos = 16'b0_1000_0101_011_0010; //89 ? l'ultimo valore in ingresso che da un'uscita con valore non infinito

//    logic [LAMP_FLOAT_DW-1:0]   min_in_neg = 16'b1_0110_0110_000_0001; //-3.003515e-08  (da l'errore dei 100 bassi)
//    logic [LAMP_FLOAT_DW-1:0]   min_in_neg = 16'b1_0111_0111_000_0000; //-0.00390625 (da errore di 1 bit ai bassi)
    logic [LAMP_FLOAT_DW-1:0]   min_in_neg = 16'b1_0110_0111_001_0010; //-6.798655e-08 (errore di 1 bit molto ridotto no 100 bassi)
    logic [LAMP_FLOAT_DW-1:0]   max_in_neg = 16'b1_1000_0101_011_1000; //-92 (da l'errore dei 100 alti)
//    logic [LAMP_FLOAT_DW-1:0]   max_in_neg = 16'b1_1000_0101_010_1110; //-87

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
                $display("idle");
                if(valid_i)
                begin
                    data_i_r_next = data_i;
                    checkInput = FUNC_checkOperand(data_i_r_next); //UPDATE 1.2: {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op}
                                                                    //IF WE CONTROL HERE, WE CAN REMOVE THE CONTROL FROM TOP MODULES (?)
                    if(checkInput == 'b00000)                       //MAYBE WE CAN USE ~checkInput
                    begin
                        opcode_top_next = FPU_IDLE;
                        padv_top_next = 1'b0;
                        shCount_next = 'd0;

                        //#############################################################################################################################################################
                        if(data_i_r_next[LAMP_FLOAT_DW-1]) //INPUT DATA IS NEGATIVE
                        begin
                            e_op2_ext = {1'b0, data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]};
                            f_op2_ext = {1'b1, data_i_r_next[LAMP_FLOAT_F_DW-1:0]};
                            if(FUNC_op1_GT_op2({1'b1, min_in_neg[LAMP_FLOAT_F_DW-1:0]}, {1'b0, min_in_neg[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]}, f_op2_ext, e_op2_ext)) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE 1
                            begin
                                data_o_next = 16'b0_0111_1111_000_0000;
                                valid_o_next = 1'b1;
                                state_next = STATE8;
                            end
                            else if(FUNC_op1_GT_op2(f_op2_ext, e_op2_ext, {1'b1, max_in_neg[LAMP_FLOAT_F_DW-1:0]}, {1'b0, max_in_neg[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]})) //IF VERIFIED THEN WE ALREADY KNOW THE RESULT WILL BE 0
                            begin
                                data_o_next = 16'b0;
                                valid_o_next = 1'b1;
                                state_next = STATE8;
                            end
                            else if(data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] < 'd127)
                            begin
                                Z_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                Zf_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                Zi_next = 'd0;
                                state_next = STATE5;
                                directPath = 1'b1;
                            end
                            else
                            begin
                                state_next = STATE1;
                                directPath = 1'b0;
                                padv_top_next = 1'b1;
                            end
                        end
                        //#############################################################################################################################################################
                        else //INPUT DATA IS POSITIVE
                        begin
                            e_op2_ext = {1'b0, data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]};
                            f_op2_ext = {1'b1, data_i_r_next[LAMP_FLOAT_F_DW-1:0]};
                            if(FUNC_op1_GT_op2({1'b1, min_in_pos[LAMP_FLOAT_F_DW-1:0]}, {1'b0, min_in_pos[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]}, f_op2_ext, e_op2_ext)) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE 1
                            begin
                                data_o_next = 16'b0_0111_1111_000_0000;
                                valid_o_next = 1'b1;
                                state_next = STATE8;
                            end
                            else if(FUNC_op1_GT_op2(f_op2_ext, e_op2_ext, {1'b1, max_in_pos[LAMP_FLOAT_F_DW-1:0]}, {1'b0, max_in_pos[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]})) //IF VERIFIED THEN WE KNOW ALREADY THE RESULT WILL BE INFINITE
                            begin
                                data_o_next = {1'b0, INF};
                                valid_o_next = 1'b1;
                                state_next = STATE8;
                            end
                            else if(data_i_r_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] < 'd127)
                            begin
                                $display("data_i_r_next = %b",data_i_r_next);
                                Z_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                Zf_next = {data_i_r_next, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}};
                                $display("Z_next  = %b",Z_next);
                                $display("Zf_next = %b",Zf_next);
                                Zi_next = 'd0;
                                state_next = STATE5;
                                directPath = 1'b1;
                            end
                            else
                            begin
                                state_next = STATE1;
                                directPath = 1'b0;
                                padv_top_next = 1'b1;
                            end
                        end
                        //#############################################################################################################################################################
                    end

                    else
                    begin
                        valid_o_next = 1'b1;
                        state_next = STATE8;
                        case(checkInput)
                            5'b10000:
                            begin
                                if(data_i_r_next == {1'b0, INF})
                                    data_o_next = {1'b0, INF};
                                else if(data_i_r_next == {1'b1, INF})
                                    data_o_next = {1'b0, ZERO};
                            end
                            5'b01000: begin data_o_next = 16'b0_0111_1111_000_0000; end
                            5'b00100: begin data_o_next = 16'b0_0111_1111_0000000;  end
                            5'b00010: begin data_o_next = {1'b0, SNAN};             end
                            5'b00001: begin data_o_next = {1'b0, QNAN};             end
                        endcase
                    end
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 1                   //
            //////////////////////////////////////////////////
            STATE1:
            begin
                $display("state1");
                if(isReady_top)
                begin
                    padv_top_next = 1'b0;
                    op1_top_next = {data_i_r, {LAMP_FLOAT_MUL_DW-LAMP_FLOAT_DW{1'b0}}}; //UPDATE FOR EXTENSION
                    $display("op1_top_next  = %b",op1_top_next);
                    op2_top_next = {log2e[31:23], FUNC_MUL_rndToNearestEven({1'b0, 1'b1, log2e[22:22-LAMP_FLOAT_MUL_F_DW-1], | log2e[22-LAMP_FLOAT_MUL_F_DW-2:0]})};
                    $display("op2_top_next  = %b",op2_top_next);
                    opcode_top_next = FPU_MUL;
                    state_next = STATE2;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 2                   //
            //////////////////////////////////////////////////
            STATE2:
            begin
                $display("state2");
                if(isResultValid_top)
                begin
                    opcode_top_next = FPU_IDLE;
                    Z_next = result_top;
                    $display("Z_next = %b", Z_next);
                    directPath = 1'b0; //UPDATE 1.3: MAYBE WE CAN REMOVE IT
                    Ez_next = result_top[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW] - 'd127;
                    $display("Ez = %d", Ez_next);
                    state_next = STATE3;
                    case(Ez_next)
                        'd0:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-1{1'b0}}, 1'b1}; //SEVEN 0, ONE 1 (HIDDEN BIT)
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = result_top[LAMP_FLOAT_MUL_F_DW-1:0]; //ALL SEVEN BIT OF THE MANTISSA ARE COPIED (UPDATED FOR EXTENSION)
                        end
                        'd1:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-2{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1]}; //SIX 0, ONE 1(HIDDEN BIT), 7TH BIT OF MANTISSA (UPDATED FOR EXTENSION)
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-2:0], 1'b0}; //THE FIRST 6 BITS OF THE MANTISSA, ONE 0
                        end
                        'd2:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-3{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-2]}; //FIVE 0, ONE 1 (HIDDEN BIT), 7TH AND 6TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-3:0], 2'b0}; //THE FIRST 5 BITS OF THE MANTISSA, TWO 0
                        end
                        'd3:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-4{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-3]}; //FOUR 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-4:0], 3'b0}; //THE FIRST 4 BITS OF THE MANTISSA, THREE 0
                        end
                        'd4:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-5{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-4]}; //THREE 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH 4TH BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-5:0], 4'b0}; //THE FIRST 3 BITS OF THE MANTISSA, FOUR 0
                        end
                        'd5:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-6{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-5]}; //TWO 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-6:0], 5'b0}; //THE FIRST 2 BITS OF THE MANTISSA, FIVE 0
                        end
                        'd6:
                        begin
                            Zi_next = {{LAMP_FLOAT_E_DW-7{1'b0}}, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-6]}; //ONE 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD 2ND BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {result_top[LAMP_FLOAT_MUL_F_DW-7:0], 6'b0}; //THE FIRST 1 BIT OF THE MANTISSA, SIX 0
                        end
                        'd7:
                        begin
                            Zi_next = {1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-7]}; //ONE 1, 7TH 6TH 5TH 4TH 3RD 2ND 1ST BIT OF MANTISSA
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {LAMP_FLOAT_MUL_F_DW{1'b0}}; //SEVEN 0
                        end
                        default:
                        begin
                            Zi_next = {1'b1, 6'b0, 1'b1};
                            Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {LAMP_FLOAT_MUL_F_DW{1'b0}};
                        end
                        //ADD THE OTHER CASES AND MODIFY CASE 7 IF MORE BITS ARE USED. THE OTHERS SHOULD WORK ANYWAY
                        //default: ; //CANNOT SHIFT MORE THAN 7 BITS IN THE 16 BIT CASE, THIS SHOULD BE HANDLED SOMEWHERE ELSE MAYBE (?).
                    endcase
                    $display("Zi_next = %b", Zi_next);
                    $display("Zf_next = %b", Zf_next);
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 3                   //
            //////////////////////////////////////////////////
            STATE3:
            begin
                $display("state3");

                case(Zf[LAMP_FLOAT_MUL_F_DW-1:0])
                    'd0:
                    begin
                        $display("the Zf mantissa is all 0s");
                        if(Z[LAMP_FLOAT_MUL_DW-1] == 1'b1)
                        begin
                            if(8'd127 - Zi <= 8'd127) //no underflow
                            begin
                                $display("NO underflow");
                                Zf_next = {1'b0, 'd127 - Zi, {LAMP_FLOAT_MUL_F_DW-1{1'b0}}};
                                state_next = STATE4;
                                padv_top_next = 1'b1;
                            end

                            else
                            begin
                                $display("YES underflow");
                                data_o_next = 16'b0;
                                state_next = STATE8;
                                valid_o_next = 1'b1;
                            end
                        end

                        else
                        begin
                            if(8'd127 + Zi >= 8'd127) //no overflow
                            begin
                                $display("NO overflow");
                                Zf_next = {1'b0, 'd127 + Zi, {LAMP_FLOAT_MUL_F_DW-1{1'b0}}};
                                state_next = STATE4;
                                padv_top_next = 1'b1;
                            end

                            else
                            begin
                                $display("YES overflow");
                                data_o_next = {1'b0, INF};
                                state_next = STATE8;
                                valid_o_next = 1'b1;
                            end
                        end
                    end

                    default:
                    begin
                        Zf_next[LAMP_FLOAT_MUL_DW-1] = Z[LAMP_FLOAT_MUL_DW-1]; //sign
                        shCount = FUNC_MUL_numLeadingZeros({Zf[LAMP_FLOAT_MUL_F_DW-1:0], 1'b0});
                        $display("shCount = %b CHECK FOR ERRORS IN NUMBER OF BITS!", shCount);
                        Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = FUNC_MUL_shiftMantissa(Zf[LAMP_FLOAT_MUL_F_DW-1:0], shCount);
                        Zf_next[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW] = 8'd127 - (shCount + 1);
                        $display("Zf_next = %b", Zf_next);

                        state_next = STATE4;
                        padv_top_next = 1'b1;
                    end
                endcase









//                if(Zf[LAMP_FLOAT_MUL_F_DW-1])
//                begin
//                    Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {Zf[LAMP_FLOAT_MUL_F_DW-2:0], 1'b0};
//                    Zf_next[LAMP_FLOAT_MUL_DW-1] = Z[LAMP_FLOAT_MUL_DW-1];
//                    Zf_next[LAMP_FLOAT_MUL_DW-2:LAMP_FLOAT_MUL_F_DW] = 8'd127 - (shCount + 1);

//                    state_next = STATE4;
//                    padv_top_next = 1'b1;
//                    $display("Zf_next = %b", Zf_next);
//                end

//                else if(Zf[LAMP_FLOAT_MUL_F_DW-1:0] != 'd0)
//                begin
//                    Zf_next[LAMP_FLOAT_MUL_F_DW-1:0] = {Zf[LAMP_FLOAT_MUL_F_DW-2:0], 1'b0};
//                    shCount_next = shCount + 1;
//                end

//                else
//                begin
//                    $display("the Zf mantissa is all 0s");
//                    if(Z[LAMP_FLOAT_MUL_DW-1] == 1'b1)
//                    begin
//                        if(8'd127 - Zi <= 8'd127) //no underflow
//                        begin
//                            $display("NO underflow");
//                            Zf_next = {1'b0, 'd127 - Zi, {LAMP_FLOAT_MUL_F_DW-1{1'b0}}};
//                            state_next = STATE4;
//                            padv_top_next = 1'b1;
//                        end

//                        else
//                        begin
//                            $display("YES underflow");
//                            data_o_next = 16'b0;
//                            state_next = STATE8;
//                            valid_o_next = 1'b1;
//                        end
//                    end

//                    else
//                    begin
//                        if(8'd127 + Zi >= 8'd127) //no overflow
//                        begin
//                            $display("NO overflow");
//                            Zf_next = {1'b0, 'd127 + Zi, {LAMP_FLOAT_MUL_F_DW-1{1'b0}}};
//                            state_next = STATE4;
//                            padv_top_next = 1'b1;
//                        end

//                        else
//                        begin
//                            $display("YES overflow");
//                            data_o_next = {1'b0, INF};
//                            state_next = STATE8;
//                            valid_o_next = 1'b1;
//                        end
//                    end
//                end
            end
            //////////////////////////////////////////////////
            //                    STATE 4                   //
            //////////////////////////////////////////////////
            STATE4:
            begin
                $display("state4");
                if(isReady_top)
                begin
                    padv_top_next = 1'b0;
                    op1_top_next = Zf;
                    $display("op1_top_next = %b", Zf);
                    op2_top_next = {inv_log2e[31:23], FUNC_MUL_rndToNearestEven({1'b0, 1'b1, inv_log2e[22:22-LAMP_FLOAT_MUL_F_DW-1], | inv_log2e[22-LAMP_FLOAT_MUL_F_DW-2:0]})};
                    opcode_top_next = FPU_MUL;
                    state_next = STATE5;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 5                   //
            //////////////////////////////////////////////////
            STATE5:
            begin
                $display("state5");
                if(isResultValid_top)
                begin
                    //MUL_use = 1'b0;
                    //###########################################################################################################################################################
                    //###########################################################################################################################################################
                    Zf_next = result_top; //and then in state 6 we can avoid checking for directpath and have only one condition
                    //###########################################################################################################################################################
                    //###########################################################################################################################################################
                    padv_tay_next = 1'b1;
                    state_next = STATE6;
                end

                if(directPath)
                begin
                    $display("using taylor");
                    padv_tay_next = 1'b1;
                    //MUL_use = 1'b0;
                    state_next = STATE6;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 6                   //
            //////////////////////////////////////////////////
            STATE6:
            begin
                $display("state6");
                if(ready_o_tay)
                begin
                    $display("taylor is ready");
                    //data_i_tay_next = result_top[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_DW-LAMP_FLOAT_TAY_DW];
                    
                    //if Ntay <= Nmul-3
                    data_i_tay_next = {Zf[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, Zf[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-1], | Zf[LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-2:0]})};
                    //if Ntay = Nmul-2
//                    data_i_tay_next = {Zf[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, Zf[LAMP_FLOAT_MUL_F_DW-1:0], 1'b0})};
                    //if Nay = Nmul-1
//                    data_i_tay_next = {Zf[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, Zf[LAMP_FLOAT_MUL_F_DW-1:0], 2'b00})};
                    //if Nay = Nmul
//                    data_i_tay_next = Zf;

                    $display("result_top   = %b", Zf);
                    $display("taylor input = %b", data_i_tay_next);
                    valid_i_tay_next = 1'b1;
                    padv_tay_next = 1'b0;
                    state_next = STATE7;
                end


//                if(directPath)
//                begin
//                    if(ready_o_tay)
//                    begin
//                        padv_tay_next = 1'b0;
//                        valid_i_tay_next = 1'b1;
//                        data_i_tay_next = {Zf[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, Zf[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-1], | Zf[LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-2:0]})};
//                        $display("Zf             = %b", Zf);
//                        $display("data to taylor = %b", data_i_tay_next);
//                        state_next = STATE7;
//                    end
//                end

//                else
//                begin
//                    if(ready_o_tay)
//                    begin
//                        $display("taylor is ready");
//                        //data_i_tay_next = result_top[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_DW-LAMP_FLOAT_TAY_DW];
//                        data_i_tay_next = {result_top[LAMP_FLOAT_MUL_DW-1:LAMP_FLOAT_MUL_F_DW], FUNC_TAY_rndToNearestEven({1'b0, 1'b1, result_top[LAMP_FLOAT_MUL_F_DW-1:LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-1], | result_top[LAMP_FLOAT_MUL_F_DW-1-LAMP_FLOAT_TAY_F_DW-2:0]})};
//                        $display("result_top   = %b", result_top);
//                        $display("taylor input = %b", data_i_tay_next);
//                        valid_i_tay_next = 1'b1;
//                        padv_tay_next = 1'b0;
//                        state_next = STATE7;
//                    end
//                end
            end
            //////////////////////////////////////////////////
            //                    STATE 7                   //
            //////////////////////////////////////////////////
            STATE7:
            begin
                $display("state7");

                valid_i_tay_next = 1'b0;

                //if(valid_o_tay & MUL_use == 1'b0)
                if(valid_o_tay)
                begin
                    $display("receiving result from taylor");
                    valid_o_next = 1'b1;
                    state_next = STATE8;

					if(Z[LAMP_FLOAT_MUL_DW-1] == 1'b1) //UPDATE FOR EXTENSION
                    begin
                        if(data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] - Zi <= data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW]) //no underflow
                        begin
                            $display("NO underflow");
                            data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] - Zi, FUNC_rndToNearestEven({1'b0, 1'b1, data_o_tay[LAMP_FLOAT_TAY_F_DW-1:LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-1], | data_o_tay[LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-2:0]})};
                            $display("data_o_tay   = %b", data_o_tay);
                            $display("data_o_next  = %b", data_o_next);
                        end

                        else
                        begin
                            $display("YES underflow");
                            data_o_next = 16'b0;
                        end
                    end

                    else
                    begin
                        if(data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] + Zi >= data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW]) //no overflow
                        begin
                            $display("NO overflow");
                            data_o_next = {data_o_tay[LAMP_FLOAT_TAY_DW-1], data_o_tay[LAMP_FLOAT_TAY_DW-2:LAMP_FLOAT_TAY_F_DW] + Zi, FUNC_rndToNearestEven({1'b0, 1'b1, data_o_tay[LAMP_FLOAT_TAY_F_DW-1:LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-1], | data_o_tay[LAMP_FLOAT_TAY_F_DW-1-LAMP_FLOAT_F_DW-2:0]})};
                            $display("data_o_tay   = %b", data_o_tay);
                            $display("data_o_next  = %b", data_o_next);
                        end

                        else
                        begin
                            $display("YES overflow");
                            data_o_next = {1'b0, INF};
                        end
                    end
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 8                   //
            //////////////////////////////////////////////////
            STATE8:
            begin
                $display("state8");
                if(padv_i)
                begin
                    valid_o_next = 1'b0;
                    state_next = IDLE;
                end
            end

        endcase
    end

    assign ready_o = (state == IDLE) | valid_o;
    assign flush_top = 1'b0;
    assign rndMode_top = FPU_RNDMODE_NEAREST;

    assign flush_tay = 1'b0;/////
    assign rndMode_tay = FPU_RNDMODE_NEAREST;/////
    assign approxLevel_tay = TAYLOR_APPROX;/////

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
        .flush_i            (flush_tay),/////
        .padv_i             (padv_tay),
        .valid_i            (valid_i_tay),
        .rndMode_i          (rndMode_tay),/////
        .approxLevel_i      (approxLevel_tay),/////
        .op_i               (data_i_tay),
        .result_o           (data_o_tay),
        .isResultValid_o    (valid_o_tay),
        .isReady_o          (ready_o_tay)
    );

endmodule