`timescale 1ns / 1ps


module lampFPU_TAY_basic_top_tb();

    import lampFPU_XXX_pkg::*;

    int clk_counter = 0;
    logic count = 1'b0;

    //input
    logic                       clk;
    logic                       rst;
    logic                       flush_i;
    logic                       padv_i;
    logic 			            valid_i;
    rndModeFPU_t				rndMode_i;
    logic [2:0]					approxLevel_i;
    logic [LAMP_FLOAT_DW-1:0]   data_i;

    //output
    logic		                ready_o;
    logic [LAMP_FLOAT_DW-1:0]   data_o;
    logic 			            valid_o;

    int state;

    lampFPU_TAY_top dut (
        .clk (clk),
        .rst (rst),

        .flush_i (flush_i),
        .padv_i (padv_i),
        .valid_i (valid_i),
        .rndMode_i (rndMode_i),
        .approxLevel_i (approxLevel_i),
        .op_i (data_i),

        .result_o (data_o),
        .isResultValid_o (valid_o),
        .isReady_o (ready_o)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial
    begin
        state = 0;
        rst = 1'b1;
        flush_i = 1'b0;
        rndMode_i = FPU_RNDMODE_NEAREST;
        approxLevel_i = 3'd7;
    end
    always @ (posedge clk)
    begin

        if (count)
            clk_counter = clk_counter + 1;

        case (state)
            0:
            begin
                rst <= 1'b0;
                if (ready_o)
                begin
                    data_i <= 'b0__0111_1010__1001_101; //0.050048828125
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
                    $display("exp(0.050048828125) = 1.051322429225759978082");
                    $display("IN  : %b.%b.%b",data_i[LAMP_FLOAT_DW-1],data_i[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_i[LAMP_FLOAT_F_DW-1:0]);
                    $display("OUT : %b.%b.%b",data_o[LAMP_FLOAT_DW-1],data_o[LAMP_FLOAT_DW-2:LAMP_FLOAT_F_DW],data_o[LAMP_FLOAT_F_DW-1:0]);
                    $display("Number of cc : %d",clk_counter);
                    count <= 1'b0;
                    clk_counter <= 0;
                    padv_i <= 1'b1;
                    state <= 3;
                end
            end

            3:
            begin
                padv_i <= 1'b0;
                if (ready_o)
                begin
                    data_i <= 'b1__0111_1000__0100_100;//-0.010009765625
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
                    $display("exp(-0.010009765625) = 0.9900401653409694480995");
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
