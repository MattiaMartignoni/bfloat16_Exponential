`timescale 1ns / 1ps


module lampFPU_AS_top_tb();

    import lampFPU_ASM_pkg::*;

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
    logic [LAMP_FLOAT_DW-1:0]   result = 'd0;
    logic 					    isResultValid = 1'b0;
    logic 				        isReady = 1'b0;

    int state = 0;

    lampFPU_AS_top dut (
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
                rst = 1;
                state <= 1;
            end

            1:
            begin
                rst <= 1'b0;
                if (isReady)
                begin
                    op1 <=    16'b1__0111_1011__0001_111; //-0.06982421875
                    op2 <=    16'b0__0111_1011__1001_100; //0.099609375
                    rndMode <= FPU_RNDMODE_TRUNCATE;
                    opcode <= FPU_ADD;
                    $display("-0.06982421875 + 0.099609375 = +0.02978515625");
                    state <= 2;
                end
            end

            2:
            begin
                if (isResultValid)
                begin
                    padv <= 1'b1;
                    $display("IN1 : %b.%b.%b",op1[15],op1[14:7],op1[6:0]);
                    $display("IN2 : %b.%b.%b",op2[15],op2[14:7],op2[6:0]);
                    $display("SUM : %b.%b.%b\n",result[15],result[14:7],result[6:0]);
                    state <= 3;
                end
            end

            3:
            begin
                padv <= 1'b0;
                if (isReady)
                begin
                    op1 <=    16'b1__0111_1011__0001_111; //-0.06982421875
                    op2 <=    16'b0__0111_1011__1001_100; //0.099609375
                    rndMode <= FPU_RNDMODE_TRUNCATE;
                    opcode <= FPU_SUB;
                    $display("-0.06982421875 - 0.099609375 = -0.16943359375");
                    state <= 4;
                end
            end

            4:
            begin
                if (isResultValid)
                begin
                    $display("IN1 : %b.%b.%b",op1[15],op1[14:7],op1[6:0]);
                    $display("IN2 : %b.%b.%b",op2[15],op2[14:7],op2[6:0]);
                    $display("SUB : %b.%b.%b\n",result[15],result[14:7],result[6:0]);
                    state <= 5;
                end
            end

            default: $finish;

        endcase

    end

endmodule
