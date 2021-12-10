`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen, //字节写使能，一位控制一个字节的写信号
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    //用于解决数据相关
    output wire [31:0] EX_ID ,//执行后的结果
    output wire EX_wb_en, //写回使能为高
    output wire [4:0] EX_wb_r, //写回寄存器的索引
    
    output wire EX_sel_rf_res,
    
    input wire [2:0] lo_hi_to_ex_bus,
    input wire[31:0] hi_o,
    input wire[31:0] lo_o,
    
    output wire lo_hi_to_mem_bus //待改？？？？？？？？？？？？？？？？？？？？？？？？？
    //用于解决load导致的数据相关
    //input wire MEM_sel_rf_res,
    //input wire [4:0] MEM_wb_r,
    //input wire MEM_wb_en
    //output wire stallreq
    
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    reg [2:0] lo_hi_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0; //EX段暂停，向EX段传入全0
            lo_hi_to_ex_bus_r <= 3'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus; //ID段正常执行了
            lo_hi_to_ex_bus_r <= lo_hi_to_ex_bus;
        end
    end

    //assign stallreq = (sel_alu_src1 == MEM_wb_r && MEM_wb_en && sel_rf_res) ? 1'b1 : 1'b0;

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1; //alu_src1一共有3种可能
    wire [3:0] sel_alu_src2; //alu_src2一共有4中可能
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    
    wire sel_lo_hi; //选择是lo还是hi寄存器
    wire lo_hi_we; //写使能
    wire lo_hi_re; //读使能

    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r; //用ID段传下来的东西给EX段赋值
    
    assign {
    sel_lo_hi, //2
    lo_hi_we, //1
    lo_hi_re //0
    } = lo_hi_to_ex_bus_r;
    
    assign EX_sel_rf_res = sel_rf_res;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend; //立即数符号扩展、立即数0扩展和？？？？？？？？？？？？？？？
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]}; //？？？？？？？？？？

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result; //ALU段存放的结果以及符号扩展的结果

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    //assign ex_result = (rf_waddr==5'b11111) ? ex_pc + 32'h8 : alu_result; 
    assign ex_result = (lo_hi_re & sel_lo_hi==1) ? lo_o: 
                        (lo_hi_re & sel_lo_hi==0) ? hi_o : alu_result;
    
    assign EX_ID = ex_result; //拿到alu的结果！！！！！！！！！！!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    assign EX_wb_en = rf_we;
    assign EX_wb_r = rf_waddr;
    //assign EX_sel_rf_res = sel_rf_res;
    
    //控制读写！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    assign data_sram_en = data_ram_en;
    assign data_sram_wen = data_ram_wen;
    assign data_sram_addr = ex_result;
    assign data_sram_wdata = rf_rdata2;
    assign data_sram_addr = data_sram_en ? ex_result : 32'b0;

    assign ex_to_mem_bus = { 
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    

    
endmodule