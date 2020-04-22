`timescale 1ns / 1ps

module CORDIC_exp_top_tb();

  import lampFPU_COR_pkg::*;

    logic clk;
    logic rst = 1'b0;

    int clk_counter = 0;
    logic count = 1'b0;

    //input
    logic  			padv_i;
    logic 			 valid_i;
    logic [LAMP_FLOAT_DW-1:0]     data_i;

    //output
    logic		     ready_o;
    logic [LAMP_FLOAT_DW-1:0]     data_o;
    logic 			 valid_o;

    int state = 0;

    CORDIC_exp_top dut (
        .clk (clk),
        .rst (rst),

        .padv_i (padv_i),
        .valid_i (valid_i),
        .data_i (data_i),

        .ready_o (ready_o),
        .data_o (data_o),
        .valid_o (valid_o)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @ (posedge clk)
    begin

        if (count)
            clk_counter = clk_counter + 1;

        case (state)

            0:
            begin
                rst = 1'b1;
                state <= 1;
            end

            1:
            begin
                rst <= 1'b0;
                if (ready_o)
                begin
                    data_i <= 'b0__0111_1110__1100_110; //0,8984375
                    valid_i <= 1'b1;
                    count <= 1'b1;
                    state <= 2;
                end
            end

            2:
            begin
                valid_i <= 1'b0;
                if (valid_o)
                begin
                    $display("exp(0.8984375) = 2.455762982");
                    $display("IN  : %b.%b.%b",data_i[LAMP_FLOAT_DW-1],data_i[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_i[LAMP_FLOAT_F_DW-1:0]);
                    $display("OUT : %b.%b.%b",data_o[LAMP_FLOAT_DW-1],data_o[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_o[LAMP_FLOAT_F_DW-1:0]);
                    $display("Number of cc : %d",clk_counter);
                    count <= 1'b0;
                    clk_counter <= 0;
                    state <= 3;
                    padv_i <= 1'b1;
                end
            end

            3:
            begin
                padv_i <= 1'b0;
                if (ready_o)
                begin
                    data_i <= 'b1__0111_1010__1111_111; //-0.062255859375
                    valid_i <= 1'b1;
                    count <= 1'b1;
                    state <= 4;
                end
            end

            4:
            begin
                valid_i <= 1'b0;
                if (valid_o)
                begin
                    $display("exp(-0.062255859375) = 0.93964243970");
                    $display("IN  : %b.%b.%b",data_i[LAMP_FLOAT_DW-1],data_i[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_i[LAMP_FLOAT_F_DW-1:0]);
                    $display("OUT : %b.%b.%b",data_o[LAMP_FLOAT_DW-1],data_o[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_o[LAMP_FLOAT_F_DW-1:0]);
                    $display("Number of cc : %d",clk_counter);
                    count <= 1'b0;
                    clk_counter <= 0;
                    state <= 5;
                end
            end

            default: $finish;
        endcase
    end

endmodule
