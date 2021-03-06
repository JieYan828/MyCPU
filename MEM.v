`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    
    input wire [31:0]data_sram_rdata,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [37:0] mem_to_id_bus
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
    wire data_ram_wen;
    wire sel_rf_res;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    wire [31:0] ex_result;
    wire [31:0] mem_result;
    wire [2:0] signal_load;

    assign {
        signal_load,
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;
   
   assign mem_result=data_sram_rdata;

    assign rf_wdata = (signal_load ==3'b001) ? mem_result://lw
  (signal_load ==3'b010) & (ex_result[1:0]==2'b00)? ({{24{mem_result[7]}},mem_result[7:0]}): //lb
  (signal_load ==3'b010) & (ex_result[1:0]==2'b01)? ({{24{mem_result[15]}},mem_result[15:8]}): //lb
  (signal_load ==3'b010) & (ex_result[1:0]==2'b10)? ({{24{mem_result[23]}},mem_result[23:16]}): //lb
  (signal_load ==3'b010) & (ex_result[1:0]==2'b11)? ({{24{mem_result[31]}},mem_result[31:24]}): //lb
  (signal_load ==3'b011) & (ex_result[1:0]==2'b00)? ({24'b0,mem_result[7:0]}): //lbu
  (signal_load ==3'b011) & (ex_result[1:0]==2'b01)? ({24'b0,mem_result[15:8]}): //lbu
  (signal_load ==3'b011) & (ex_result[1:0]==2'b10)? ({24'b0,mem_result[23:16]}): //lbu
  (signal_load ==3'b011) & (ex_result[1:0]==2'b11)? ({24'b0,mem_result[31:24]}): //lbu
  (signal_load ==3'b100) & (ex_result[1:0]==2'b00)? ({{16{mem_result[15]}},mem_result[15:0]})://lh
  (signal_load ==3'b100) & (ex_result[1:0]==2'b10)? ({{16{mem_result[31]}},mem_result[31:16]})://lh
  (signal_load ==3'b101) & (ex_result[1:0]==2'b00)? ({16'b0,mem_result[15:0]})://lhu
  (signal_load ==3'b101) & (ex_result[1:0]==2'b10)? ({16'b0,mem_result[31:16]})://lhu
  ex_result;

    assign mem_to_wb_bus = {
        mem_pc,     // 41:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
    assign mem_to_id_bus = {
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };




endmodule