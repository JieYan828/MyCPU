`include "lib/defines.vh"
module WB(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
        //���ڽ���������
    output wire [31:0] WB_ID ,//ִ�к�Ľ��
    output wire WB_wb_en, //д��ʹ��Ϊ��
    output wire [4:0] WB_wb_r, //д�ؼĴ��������� 
    
    //lo_hi�Ĵ���
    input wire [34:0] lo_hi_to_wb_bus,
    input wire [66:0] lo_hi_ex_to_wb_bus,
    
    output lo_hi_we_o,
    output [31:0] lo_i,
    output [31:0] hi_i
);

    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;
    reg [34:0] lo_hi_to_wb_bus_r;
    reg [66:0] lo_hi_ex_to_wb_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        // else if (flush) begin
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
            lo_hi_to_wb_bus_r <= 35'b0;
            lo_hi_ex_to_wb_bus_r <= 67'b0;
        end
        else if (stall[4]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;
            lo_hi_to_wb_bus_r <= lo_hi_to_wb_bus;
            lo_hi_ex_to_wb_bus_r <= lo_hi_ex_to_wb_bus;
        end
    end

    wire [31:0] wb_pc;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
    
    wire [1:0] sel_lo_hi;
    wire lo_hi_we;
    wire [31:0] lo_hi_wdata;
    wire [63:0] mult_div_result;

    assign {
        wb_pc,
        rf_we,
        rf_waddr,
        rf_wdata
    } = mem_to_wb_bus_r;
    
    assign {
    sel_lo_hi,
    lo_hi_we,
    lo_hi_wdata
    } = lo_hi_to_wb_bus_r;
    
    assign {
    mult_div_result
    } = lo_hi_ex_to_wb_bus_r;
    
    //д31�żĴ���
    //wire [31:0] sel_rf_wdata;
    //assign sel_rf_wdata = (rf_waddr==5'b11111) ? wb_pc +32'h8 : rf_wdata;//////////////////////////////

    // assign wb_to_rf_bus = mem_to_wb_bus_r[`WB_TO_RF_WD-1:0];
    assign wb_to_rf_bus = {
        rf_we,
        rf_waddr,
        rf_wdata
    };
    
    //дhi_lo�Ĵ���
    assign lo_hi_we_o = lo_hi_we;
    assign lo_i = (sel_lo_hi==2'b01) ? lo_hi_wdata : mult_div_result[31:0];
                  //(sel_lo_hi==2'b10||sel_lo_hi==2'b11) ? mult_div_result[0:31] : 32'b0;
    assign hi_i = (sel_lo_hi==2'b00) ? lo_hi_wdata : mult_div_result[63:32];
                  //(sel_lo_hi==2'b10||sel_lo_hi==2'b11) ? mult_div_result[63:32] : 32'b0;
    
    assign WB_ID = rf_wdata; //�õ�alu�Ľ����������������������!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    assign WB_wb_en = rf_we;
    assign WB_wb_r = rf_waddr;

    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wen = {4{rf_we}};
    assign debug_wb_rf_wnum = rf_waddr;
    assign debug_wb_rf_wdata = rf_wdata;

    
endmodule