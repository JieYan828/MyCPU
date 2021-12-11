//`include "defines.vh"
module HILO(
    input wire clk,
    input wire rst,
    
    //写端口
    input wire we,
    input wire[31:0] hi_i,
    input wire[31:0] lo_i,
    
    //读端口
    output reg[31:0] hi_o,
    output reg[31:0] lo_o
    );
        always @ (posedge clk) begin
            if (rst) begin
                hi_o <= 32'd0;
                lo_o <= 32'd0;
            end else if((we)) begin //写使能信号为高
                hi_o <= hi_i;
                lo_o <=lo_i;
            end
//            else begin
//                hi_o <= 32'd2;
//                lo_o <= 32'd2;
//            end
         end
         
endmodule
