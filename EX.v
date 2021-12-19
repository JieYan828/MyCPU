`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire [37:0] ex_to_id_bus,
    output wire inst_is_lw,
    
    output wire data_sram_en,
    output wire  [3:0]data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    //div新增
    
    output wire stallreq_for_ex,
    output wire [65:0] ex_hilo
);
///////////////////////////////////////////////////////记得去github上搞div和mul的使用
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire data_ram_en;
    wire data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    wire [31:0] lo_rdata;
    reg is_in_delayslot;//延迟槽

    assign {
        hilo_data,
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
    } = id_to_ex_bus_r;
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result,move_result;

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
   wire inst_is_move,inst_is_mflo,inst_is_mfhi,inst_div,inst_divu,
        inst_mult,inst_multu,inst_mthi,inst_mtlo,inst_lw,inst_lb,
        inst_sw,inst_lbu,inst_lh,inst_lhu,inst_sb,inst_sh;
   //inst_is_lw代表的是load这个类
   
   assign inst_lw = (inst[31:26]==6'b10_0011);
   assign inst_sw = (inst[31:26]==6'b10_1011);
   assign inst_lb = (inst[31:26]==6'b10_0000);
   assign inst_lbu = (inst[31:26]==6'b10_0100);
   assign inst_lh = (inst[31:26]==6'b10_0001);
   assign inst_lhu = (inst[31:26]==6'b10_0101);
   assign inst_sb = (inst[31:26]==6'b10_1000);
   assign inst_sh = (inst[31:26]==6'b10_1001);
   
   assign inst_is_lw=inst_lw|inst_lb|inst_lbu|inst_lh|inst_lhu;
   assign inst_is_move=inst_is_mflo|inst_is_mfhi|inst_mthi|inst_mtlo;
   assign inst_is_mflo= (inst[31:26]==6'b00_0000 & inst[5:0]==6'b01_0010);
   assign inst_is_mfhi= (inst[31:26]==6'b00_0000 & inst[5:0]==6'b01_0000);
   assign inst_div = (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b011010);
   assign inst_divu = (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b011011);
   assign inst_mult =  (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b011000);
   assign inst_multu =  (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b011001);
   assign inst_mthi =  (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b010001);
   assign inst_mtlo =  (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b010011);
   
   
   
   assign move_result=inst_is_move ? rf_rdata1:32'b0;
   assign ex_result = inst_is_move ? move_result : alu_result;
   assign data_sram_en=data_ram_en;
   //load指令全用0000，
   assign data_sram_wen=(data_ram_wen && inst_sw) ? 4'b1111:
                         (data_ram_wen && inst_sb && ex_result[1:0] == 2'b00) ? 4'b0001:
                         (data_ram_wen && inst_sb && ex_result[1:0] == 2'b01) ? 4'b0010:
                         (data_ram_wen && inst_sb && ex_result[1:0] == 2'b10) ? 4'b0100:
                         (data_ram_wen && inst_sb && ex_result[1:0] == 2'b11) ? 4'b1000:
                         (data_ram_wen && inst_sh && ex_result[1:0] == 2'b00) ? 4'b0011:
                         (data_ram_wen && inst_sh && ex_result[1:0] == 2'b10) ? 4'b1100:
                                              4'b0000;
   assign data_sram_addr=ex_result;
   assign data_sram_wdata=(data_sram_wen==4'b1111) ? rf_rdata2: 
                           (data_sram_wen==4'b0001) ? {24'b0,rf_rdata2[7:0]}:
                           (data_sram_wen==4'b0010) ? {16'b0,rf_rdata2[7:0],8'b0}:
                           (data_sram_wen==4'b0100) ? {8'b0,rf_rdata2[7:0],16'b0}:
                           (data_sram_wen==4'b1000) ? {rf_rdata2[7:0],24'b0}:
                           (data_sram_wen==4'b0011) ? {16'b0,rf_rdata2[15:0]}:
                           (data_sram_wen==4'b1100) ? {rf_rdata2[15:0],16'b0}:
                           32'b0;
   
   wire [2:0] signal_load;
   assign signal_load = inst_lw  ? 3'b001: 
                       inst_lb    ? 3'b010:
                       inst_lbu   ? 3'b011:
                       inst_lh    ? 3'b100:
                       inst_lhu   ? 3'b101:
                                  3'b000; 
             
   
    assign ex_to_mem_bus = {//-3+3
        signal_load,
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    assign ex_to_id_bus = {
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };
    
//     // MUL part
//    wire [63:0] mul_result;
//    wire mul_signed; // 有符号乘法标记
//    assign mul_signed=inst_mult;
//    wire [31:0] mul_data1;
//    wire [31:0] mul_data2;
//    assign mul_data1 =(inst_mult|inst_multu)?rf_rdata1:32'b0;
//    assign mul_data2 =(inst_mult|inst_multu)?rf_rdata2:32'b0;
//    mul u_mul(
//    	.clk        (clk            ),
//        .resetn     (~rst           ),
//        .mul_signed (mul_signed     ),
//        .ina        (mul_data1    ), // 乘法源操作数1
//        .inb        (mul_data2   ), // 乘法源操作数2
//        .result     (mul_result     ) // 乘法结果 64bit
//    );

    // MULT_DIV part
    wire [63:0] div_result;//高32位是余数，低32位是商
    wire div_ready_i;
    reg stallreq_for_div;//是否由于除法运算导致流水线暂停
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;
    wire sel_mul_div;
    assign sel_mul_div = (inst_mult|inst_multu) ? 1'b1 : 1'b0; //选择是乘法还是除法运算

    mul_div u_mul_div(
    	.rst          (rst          ),//复位
        .clk          (clk          ),//时钟
        .signed_i (signed_div_o ),//是否为有符号除法运算，1为有符号
        .opdata1_i    (div_opdata1_o    ),//被除数
        .opdata2_i    (div_opdata2_o    ),//除数
        .start_i      (div_start_o      ),//是否开始除法运算
        .annul_i      (1'b0      ),      //是否取消除法运算，1为取消
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      ),//除法运算是否结束
        .sel_mul_div  (sel_mul_div)
    );

    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu,inst_mult,inst_multu})
                4'b1000:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1; //1为有符号
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                4'b0100:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                4'b0010:begin //有符号乘法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1; //1为有符号
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                4'b0001:begin //无符号乘法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end
   wire hi_we;
   wire lo_we;
   wire [31:0] hi_rdata;
   wire [31:0] lo_rdata;
    assign hi_we =inst_div|inst_divu|inst_mult|inst_multu|inst_mthi;
    assign lo_we =inst_div|inst_divu|inst_mult|inst_multu|inst_mtlo;
//    assign hi_rdata =(inst_div|inst_divu)?div_result[63:32]:
//                      (inst_mult|inst_multu)?mul_result[63:32]:
//                      inst_mthi?move_result:32'b0;
//    assign lo_rdata =(inst_div|inst_divu)?div_result[31:0]:
//                      (inst_mult|inst_multu)?mul_result[31:0]:
//                      inst_mtlo?move_result:32'b0;
    assign hi_rdata = inst_mthi ? move_result : div_result[63:32];
    assign lo_rdata = inst_mtlo ? move_result : div_result[31:0];
    assign ex_hilo ={
        hi_we,
        lo_we,
        hi_rdata,
        lo_rdata
        };   

    // mul_result 和 div_result 可以直接使用
    
endmodule