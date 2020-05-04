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


module range_reduction(
    clk, rst,
    padv_i, valid_i, data_i,
    ready_o, data_o, valid_o
    );
    
    import lampFPU_ASM_pkg::*;
    
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
    
    logic                               rst_top;
    logic                               flush_top;
    logic                               padv_top, padv_top_next;
    opcodeFPU_t                         opcode_top, opcode_top_next;
    rndModeFPU_t                        rndMode_top;
    logic           [LAMP_FLOAT_DW-1:0] op1_top, op1_top_next;
    logic           [LAMP_FLOAT_DW-1:0] op2_top, op2_top_next;
    logic           [LAMP_FLOAT_DW-1:0] result_top;
    logic                               isResultValid_top;
    logic                               isReady_top;
    
    logic                       rst_cor;
    logic                       padv_cor, padv_cor_next;
    logic                       valid_i_cor, valid_i_cor_next;
    logic [LAMP_FLOAT_DW-1:0]   data_i_cor, data_i_cor_next; //IF WE USE CORDIC WITH MORE THAN 16 BITS DOES A CONFLICT ARISE FOR LAMP_FLOAT_DW?
    logic                       ready_o_cor;
    logic [LAMP_FLOAT_DW-1:0]   data_o_cor; //IF WE USE CORDIC WITH MORE THAN 16 BITS DOES A CONFLICT ARISE FOR LAMP_FLOAT_DW?
    logic                       valid_o_cor;
    
    //////////////////////////////////////////////////
    //              logic for algorithm             //              
    //////////////////////////////////////////////////
    
    parameter log2e =       32'b0_01111111_0111000_1010101000111011; //1.44269502162933349609375 (already approx)
    parameter inv_log2e =   32'b0_01111110_0110001_0111001000011000; //0.693147182464599609375 (already approx)
    
    logic [LAMP_FLOAT_DW-1:0]   Z, Z_next;
    logic [LAMP_FLOAT_E_DW-1:0] Ez, Ez_next;
    logic [LAMP_FLOAT_E_DW-1:0] Zi, Zi_next;
    logic [LAMP_FLOAT_DW-1:0]   Zf, Zf_next;
    logic [7:0]                 shCount, shCount_next; //counter for the shifts of Zf mantissa
    
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
    
    logic [5-1:0] checkInput; //UPDATE 1.2
    
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
            
            rst_cor <= 1'b1;
            padv_cor <= 1'b0;
            valid_i_cor <= 1'b0; //IS THIS CORRECT? //M// YES AND SHOULD BE ADDED ALSO TO OTHER MODULES
        end
            
        else
        begin
            state <= state_next;
            
            rst_top <= 1'b0;
            padv_top <= padv_top_next;
            opcode_top <= opcode_top_next;
            op1_top <= op1_top_next;
            op2_top <= op2_top_next;
            
            rst_cor <= 1'b0;
            padv_cor <= padv_cor_next;
            valid_i_cor <= valid_i_cor_next;
            data_i_cor <= data_i_cor_next;
            
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
        
        padv_cor_next = padv_cor;
        valid_i_cor_next = valid_i_cor;
        data_i_cor_next = data_i_cor;
        
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
                    checkInput = FUNC_checkOperand(data_i_r_next); //UPDATE 1.2 {isInf_op, isDN_op, isZ_op, isSNAN_op, isQNAN_op}
                    //M// SHOULD IT BE MOVED IN A SEPARATE ALWAYSCOMB (?)
                    //IF WE CONTROL HERE, WE CAN REMOVE THE CONTROL FROM TOP MODULES (?) 
                    //M// PROBABLY NO BECAUSE THE OTHER OPERATIONS COULD BRING TO THESE EXCEPTIONS
                    if(checkInput == 'b00000) //MAYBE WE CAN USE ~checkInput
                    begin
                        opcode_top_next = FPU_IDLE;
                        padv_top_next = 1'b0;
                        state_next = STATE1;
                        shCount_next = 'd0;
                    end
                    
                    else
                    begin
                        valid_o_next = 1'b1;
                        state_next = STATE8;
                        case(checkInput)
                            5'b10000:
                            begin
                                if(data_i_r_next == PLUS_INF)
                                    data_o_next = PLUS_INF;
                                else if(data_i_r_next == MINUS_INF)
                                    data_o_next = ZERO;
                            end
                            5'b01000:
                            begin
                                //WHAT SHOULD WE DO IF THE NUMBER IS DENORMALIZED? MAYBE WE HAVE TO MOVE OUT OF THE CASE THIS CONDITION
                                //M// IT SHOULD BE IN THE CASE OF TOO SMALL NUMBER SO RESULT IS 1 (MAYBE WE CAN MODIFY CHECKINPUT FUNCTION)
                            end
                            5'b00100: begin data_o_next = 'b0011111110000000;   end
                            5'b00010: begin data_o_next = {1'b0, SNAN};         end
                            5'b00001: begin data_o_next = {1'b0, QNAN};         end
                        endcase
                    end
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 1                   //              
            //////////////////////////////////////////////////
            STATE1:
            begin
                padv_top_next = 1'b0; //UPDATE 1.2: MOVED OUTSIDE THE IF STATEMENT
                if(isReady_top)
                begin
                    op1_top_next = data_i_r;
                    $display("op1_top_next      %b", op1_top_next);
                    //op2_top_next = log2e[31:16]; //UPDATE 1.2: MADE IT PARAMETRIC AND WITH THE CORRECT ROUNDING PROCEDURE
                    op2_top_next = {log2e[31:23], FUNC_rndToNearestEven({1'b0, 1'b1, log2e[22:22-LAMP_FLOAT_F_DW-1], | log2e[22-LAMP_FLOAT_F_DW-2:0]})};
                    //M// THIS CAN BE MOVED AS A CONSTANT IN PKG (TO SAVE FUNCTION'S AREA) (?)
                    $display("op2_top_next      %b", op2_top_next);
                    opcode_top_next = FPU_MUL;
                    state_next = STATE2;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 2                   //              
            //////////////////////////////////////////////////
            STATE2:
            begin
                if(isResultValid_top)
                begin
                    Z_next = result_top;
                    //CONSIDERARE ESPONENTE < 127 E PASSARE DIRETTAMENTE A CORDIC O TAYLOR IL NUMERO
                    padv_top_next = 1'b1; //IS THIS CORRECT? SPOSTARE IN STATE3 ---> UPDATE 1.2: CANNOT MOVE BECAUSE IF result_top < 1 WE GO DIRECTLY TO STATE4
                    
                    $display("result_top        %b", Z_next);
                    if(Z_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] < 'd127) //UPDATE 1.2: ADDED SITUATION IN WHICH result_top < 1
                    begin
                       Zf_next = result_top;
                       state_next = STATE4;
                    end
                    
                    else
                    begin
                        Ez_next = result_top[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] - 'd127;
                        state_next = STATE3;
                        case(Ez_next)
                            'd0:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-1{1'b0}}, 1'b1}; //SEVEN 0, ONE 1 (HIDDEN BIT)
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = result_top[LAMP_FLOAT_F_DW-1:0]; //ALL SEVEN BIT OF THE MANTISSA ARE COPIED
                            end
                            'd1:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-2{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-1]}; //SIX 0, ONE 1(HIDDEN BIT), 7TH BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-2:0], 1'b0}; //THE FIRST 6 BITS OF THE MANTISSA, ONE 0
                            end
                            'd2:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-3{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-2]}; //FIVE 0, ONE 1 (HIDDEN BIT), 7TH AND 6TH BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-3:0], 2'b0}; //THE FIRST 5 BITS OF THE MANTISSA, TWO 0
                            end
                            'd3:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-4{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-3]}; //FOUR 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-4:0], 3'b0}; //THE FIRST 4 BITS OF THE MANTISSA, THREE 0
                            end
                            'd4:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-5{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-4]}; //THREE 0, ONE 1(HIDDEN BIT), 7TH 6TH 5TH 4TH BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-5:0], 4'b0}; //THE FIRST 3 BITS OF THE MANTISSA, FOUR 0
                            end
                            'd5:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-6{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-5]}; //TWO 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-6:0], 5'b0}; //THE FIRST 2 BITS OF THE MANTISSA, FIVE 0
                            end
                            'd6:
                            begin
                                Zi_next = {{LAMP_FLOAT_E_DW-7{1'b0}}, 1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_F_DW-6]}; //ONE 0, ONE 1 (HIDDEN BIT), 7TH 6TH 5TH 4TH 3RD 2ND BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {result_top[LAMP_FLOAT_F_DW-7:0], 6'b0}; //THE FIRST 1 BIT OF THE MANTISSA, SIX 0
                            end
                            'd7:
                            begin
                                Zi_next = {1'b1, result_top[LAMP_FLOAT_F_DW-1:LAMP_FLOAT_E_DW-7]}; //ONE 1, 7TH 6TH 5TH 4TH 3RD 2ND 1ST BIT OF MANTISSA
                                Zf_next[LAMP_FLOAT_F_DW-1:0] = {7'b0}; //SEVEN 0
                            end
                            //ADD THE OTHER CASES AND MODIFY CASE 7 IF MORE BITS ARE USED. THE OTHERS SHOULD WORK ANYWAY
                            //default: ; //CANNOT SHIFT MORE THAN 7 BITS IN THE 16 BIT CASE, THIS SHOULD BE HANDLED SOMEWHERE ELSE MAYBE (?).
                        endcase
                    end
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 3                   //              
            //////////////////////////////////////////////////
            STATE3:
            begin
                if(Zf[LAMP_FLOAT_F_DW-1])
                begin
                    Zf_next[LAMP_FLOAT_F_DW-1:0] = {Zf[LAMP_FLOAT_F_DW-2:0], 1'b0};
                    Zf_next[LAMP_FLOAT_DW-1] = Z[LAMP_FLOAT_DW-1];        //UPDATE 1.2: WE HAVE TO CONSIDER THE SIGN OF THE INCOMING DATA
                    Zf_next[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] = 8'd127 - (shCount + 1);
                    state_next = STATE4;
                end
                else
                begin
                    Zf_next[LAMP_FLOAT_F_DW-1:0] = {Zf[LAMP_FLOAT_F_DW-2:0], 1'b0};
                    shCount_next = shCount + 1;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 4                   //              
            //////////////////////////////////////////////////
            STATE4:
            //at this point we have separated Zi and Zf.
            //Zf must be multiplied by inv_log2e and then sent to cordic or taylor
            //Zi must be saved for later
            begin
                               padv_top_next = 1'b0;
                if(isReady_top)
                begin
 
                    op1_top_next = Zf;
                    //op2_top_next = inv_log2e[31:16]; //UPDATE 1.2: MADE IT PARAMETRIC AND WITH THE CORRECT ROUNDING PROCEDURE
                    op2_top_next = {inv_log2e[31:23], FUNC_rndToNearestEven({1'b0, 1'b1, inv_log2e[22:22-LAMP_FLOAT_F_DW-1], | inv_log2e[22-LAMP_FLOAT_F_DW-2:0]})};
                    opcode_top_next = FPU_MUL;
                    state_next = STATE5;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 5                   //              
            //////////////////////////////////////////////////
            STATE5:
            begin
                if(isResultValid_top)
                //now we can feed the cordic with the result obtained
                begin
                //if(result_top > xxx) //send to cordic //MAYBE WE CAN EXPLOIT THEIR GT FUNCTION HERE
                //begin
                    padv_top_next = 1'b1;
                    data_i_cor_next = result_top;
                    state_next = STATE6;
                //end
                
                //else //send to taylor
                //begin
                //end
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 6                   //              
            //////////////////////////////////////////////////
            STATE6:
            begin
                if(ready_o_cor)
                begin
                    valid_i_cor_next = 1'b1;
                    padv_cor_next = 1'b0;
                    state_next = STATE7;
                end
            end
            //////////////////////////////////////////////////
            //                    STATE 7                   //              
            //////////////////////////////////////////////////
            STATE7:
            begin
                if(valid_o_cor)
                begin
                    padv_cor_next = 1'b1;
                    valid_o_next = 1'b1;
                    state_next = STATE8;
                    //WE SHOULD VERIFY INF, NaN ETC. CONDITIONS HERE, BEFORE THE IF STATEMENT
                    //M// SHOULD NOT BE NECESSARY IF WE DO THE RIGHT VERIFICATIONS AT BEGGINNING

                    if(Z[LAMP_FLOAT_DW-1] == 1'b1) //UPDATE 1.2: IN CASE THE ORIGINAL INPUT NUMBER WAS NEGATIVE WE HAVE TO SUBTRACT Zi INSTEAD OF SUMMING IT
                    begin
                        if(data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] - Zi < data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]) //no underflow
                        begin
                            data_o_next = {data_o_cor[LAMP_FLOAT_DW-1], data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] - Zi, data_o_cor[LAMP_FLOAT_F_DW-1:0]};
                        end
                        
                        else //WHAT TO DO IN CASE OF UNDERFLOW?
                        begin
                        end
                    end
                    
                    else
                    begin
                        if(data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] + Zi > data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW]) //no overflow
                        begin
                            data_o_next = {data_o_cor[LAMP_FLOAT_DW-1], data_o_cor[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW] + Zi, data_o_cor[LAMP_FLOAT_F_DW-1:0]};
                        end
                        
                        else //WHAT TO DO IN CASE OF OVERFLOW?
                        begin
                        end
                    end
                end
                //else if(valid_o_tay)
                //begin
                //end
            end
            //////////////////////////////////////////////////
            //                    STATE 8                   //              
            //////////////////////////////////////////////////
            STATE8:
            begin
                if(padv_i)
                begin
                    valid_o_next = 1'b0;
                    padv_top_next = 1'b1;
                    padv_cor_next = 1'b1;
                    state_next = IDLE;
                end
            end
            
        endcase
    end
    
    assign ready_o = (state == IDLE) | valid_o; 
    assign flush_top = 1'b0;
    assign rndMode_top = FPU_RNDMODE_NEAREST;
    
    //////////////////////////////////////////////////
    //                  submodules                  //              
    //////////////////////////////////////////////////

    lampFPU_ASM_top lampFPU_ASM_top_0(
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
    
    CORDIC_exp_top CORDIC_exp_top_0(
        .clk        (clk),
        .rst        (rst_cor),
        .padv_i     (padv_cor),
        .valid_i    (valid_i_cor),
        .data_i     (data_i_cor),
        .ready_o    (ready_o_cor),
        .data_o     (data_o_cor),
        .valid_o    (valid_o_cor)
    );

endmodule




