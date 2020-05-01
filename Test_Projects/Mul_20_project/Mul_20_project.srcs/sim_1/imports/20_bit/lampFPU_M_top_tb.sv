`timescale 1ns / 1ps


module lampFPU_M_top_tb();

    import lampFPU_M_pkg::*;

    logic clk;
    logic rst = 1'b0;
    logic flush = 1'b0;
    logic padv = 1'b0;

    //input
    opcodeFPU_t opcode = FPU_IDLE;
    rndModeFPU_t rndMode;

    logic [LAMP_FLOAT_DW-1:0]	op1;
    logic [LAMP_FLOAT_DW-1:0]	op2;

    //output
    logic [LAMP_FLOAT_DW-1:0]   result;
    logic 					    isResultValid;
    logic 				        isReady;

    int state = 0;

    lampFPU_M_top dut (
        .clk     (clk),
        .rst     (rst),
        .flush_i (flush),
        .padv_i  (padv),

        .opcode_i  (opcode),
        .rndMode_i (rndMode),
        .op1_i     (op1),
        .op2_i     (op2),

        .result_o        (result),
        .isResultValid_o (isResultValid),
        .isReady_o       (isReady)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @ (posedge clk)
    begin

        case (state)
            0:
            begin
                rst <= 1'b1;
                state <= 1;
            end

            1:
            begin
                rst <= 1'b0;
                if (isReady)
                begin
                    op1 <=    20'b1__0111_1011__0001_1110000; //-0.06982421875
                    op2 <=    20'b0__0111_1011__1001_1000000; //0.099609375
                    rndMode <= FPU_RNDMODE_NEAREST;
                    opcode <= FPU_MUL;
                    $display("-0.06982421875*0.099609375 = -0.00695514678955078125");
                    state <= 2;
                end
            end

            2:
            begin
                if (isResultValid)
                begin
                    padv <= 1'b1;
                    $display("IN1 : %b.%b.%b",op1[19],op1[18:11],op1[10:0]);
                    $display("IN2 : %b.%b.%b",op2[19],op2[18:11],op2[10:0]);
                    $display("MUL : %b.%b.%b\n",result[19],result[18:11],result[10:0]);
                    state <= 3;
                end
            end

            3:
            begin
                padv <= 1'b0;
                if (isReady)
                begin
                    op1 <=    20'b0__1000_0010__0110_0000000; //11
                    op2 <=    20'b0__0111_1111__0111_0010000; //1.4453125
                    rndMode <= FPU_RNDMODE_NEAREST;
                    opcode <= FPU_MUL;
                    $display("11*1.4453125 = 15.8984375");
                    state <= 4;
                end
            end

            4:
            begin
                if (isResultValid)
                begin
                    $display("IN1 : %b.%b.%b",op1[19],op1[18:11],op1[10:0]);
                    $display("IN2 : %b.%b.%b",op2[19],op2[18:11],op2[10:0]);
                    $display("MUL : %b.%b.%b\n",result[19],result[18:11],result[10:0]);
                    state <= 6;
                end
            end

            6: state <= 7;
            7: state <= 8;
            8: state <= 9;
            9:
            begin
                padv <= 1'b1;
                state <= 5;
            end
            5:
            begin
                padv <= 1'b0;
                if (isReady)
                begin
                  op1 <=    20'b0__1000_0010__0110_0000000; //11
                  op2 <=    20'b0__0111_1111__0111_0010000; //1.4453125
                  rndMode <= FPU_RNDMODE_NEAREST;
                  opcode <= FPU_MUL;
                  $display("11*1.4453125 = 15.8984375");
                    state <= 10;
                end
            end

            10:
            begin
                if (isResultValid)
                begin
                    $display("IN1 : %b.%b.%b",op1[19],op1[18:11],op1[10:0]);
                    $display("IN2 : %b.%b.%b",op2[19],op2[18:11],op2[10:0]);
                    $display("MUL : %b.%b.%b\n",result[19],result[18:11],result[10:0]);
                    state <= 11;
                end
            end

            default: $finish;

        endcase

    end

endmodule
