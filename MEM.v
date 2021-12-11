`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,
    

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    output wire [31:0] MEM_ID,//MEM段手中的运算结果
    output wire MEM_wb_en, //写回使能为高
    output wire [4:0] MEM_wb_r, //写回寄存器的索引
    output wire MEM_sel_rf_res
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;
        end
    end

    wire [31:0] mem_pc;
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;

    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;
    
    
    //访存操作！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    assign mem_result = data_sram_rdata;
    assign rf_wdata = sel_rf_res ? mem_result : ex_result;
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    assign MEM_ID = rf_wdata;
    assign MEM_wb_en = rf_we;
    assign MEM_wb_r = rf_waddr;
    assign MEM_sel_rf_res = sel_rf_res;

    assign mem_to_wb_bus = {
        mem_pc,     // 41:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

    


endmodule