`include "lib/defines.vh"
module CTRL(
    input wire rst,
    input wire stallreq_for_ex,
    input wire stallreq_for_load,
//    input wire stallreq,

    // output reg flush,
    // output reg [31:0] new_pc,
    output reg [`StallBus-1:0] stall
);  
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;
        end
        else begin
            stall = `StallBus'b0;
        end
    end
    
    always @ (*) begin
        if (stallreq_for_load) begin
//            stall[0]=`Stop; //表示pc值不变
//            stall[1]=`NoStop;
//            stall[2]=`Stop; //ID段暂停
//            stall[`StallBus-1:3]=3'b0; 
            stall[0] = `Stop;
            stall[1] = `Stop;
            stall[2]=`NoStop;
            stall[`StallBus-1:3] = 3'b0;
//            stall[1:0] = `NoStop;
//            stall[2]=`Stop;
//            stall[`StallBus-1:3] = 3'b0;
        end
        else if(stallreq_for_ex) begin
            stall[2] = `Stop;
            stall[1:0] = 2'b1;
            stall[`StallBus-1:3] = 3'b0;
        end
        else begin
            stall = `StallBus'b0;
        end
    end
    
//    always @ (*) begin
//        if (stallreq)begin
//            stall[0] <= 1'b0;
//            stall[1] <= `Stop;
//            stall[`StallBus-1:2] <= `StallBus-2'b0;
//        end
//    end


endmodule