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


module range_reduction_tb();

    import lampFPU_ASM_pkg::*;
    
    logic                       clk;
    logic                       rst;
    logic                       padv_i;
    logic                       valid_i;
    logic [LAMP_FLOAT_DW-1:0]   data_i;
    logic                       ready_o;
    logic [LAMP_FLOAT_DW-1:0]   data_o;
    logic                       valid_o;
    
    range_reduction dut(
        .clk        (clk),
        .rst        (rst),
        .padv_i     (padv_i),
        .valid_i    (valid_i),
        .data_i     (data_i),
        .ready_o    (ready_o),
        .data_o     (data_o),
        .valid_o    (valid_o)
    );
    
    always #5 clk = ~clk;
    
    initial
    begin
        clk <= 0;
        rst = 1;
        padv_i = 1'b1;
        
        @(posedge clk);
        begin
            rst <= 1'b0;
            padv_i <= 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = 16'b0__1000_0010__0110_000;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b      (11)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        //////////////////////////////////////////////////
        //                data_i = -11                  //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = 16'b0__1000_0010__0110_000;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b      (-11)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
                
        //////////////////////////////////////////////////
        //              data_i = PLUS_INF               //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = PLUS_INF;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (PLUS_INF)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        //////////////////////////////////////////////////
        //              data_i = MINUS_INF              //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = MINUS_INF;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (MINUS_INF)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
                
        //////////////////////////////////////////////////
        //              data_i = PLUS_ZERO              //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = PLUS_ZERO;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (PLUS_ZERO)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        //////////////////////////////////////////////////
        //              data_i = MINUS_ZERO             //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = MINUS_ZERO;
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (MINUS_ZERO)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        //////////////////////////////////////////////////
        //                data_i = SNaN                 //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = {1'b0, SNAN_E_F};
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (SNAN)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        //////////////////////////////////////////////////
        //                data_i = QNaN                 //              
        //////////////////////////////////////////////////
        
        @(posedge clk);
        begin
            padv_i = 1'b1;
        end
        
        @(posedge clk);
        begin
            padv_i = 1'b0;
        end
        
        @(posedge clk);
        begin
            if(ready_o)
            begin
                data_i = {1'b0, QNAN_E_F};
                valid_i = 1'b1;
            end
        end
        
        @(posedge clk);
        begin
            valid_i = 1'b0;
        end
        
        wait(valid_o == 1)
        $display("INPUT     %b  (QNAN)", data_i);
        $display("OUTPUT    %b", data_o);
        $display(" ");
        repeat(5) @(posedge clk);
        
        $finish;
    end
endmodule













