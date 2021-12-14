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
    output wire [64:0] ex_mem_lohi_bus
);
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
        hi_data,
        lo_data,
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
   wire inst_is_move,inst_is_mflo,inst_div,inst_divu;
   assign inst_is_lw=(inst[31:26]==6'b10_0011);
   assign inst_is_move=inst_is_mflo;
   assign inst_is_mflo= (inst[31:26]==6'b00_0000 & inst[5:0]==6'b01_0010);
   assign inst_div = (inst[31:26]==6'b00_0000 &  inst[5:0]==6'b011010);
   
   
   
   assign move_result=lo_rdata;
   assign ex_result = inst_is_move?move_result:alu_result;
   assign data_sram_en=data_ram_en;
   assign data_sram_wen=data_ram_wen ? 4'b1111:4'b0000;
   assign data_sram_addr=ex_result;
   assign data_sram_wdata=rf_rdata2;
   
   
   
    assign ex_to_mem_bus = {//-3
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
    
     // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记

    //mul u_mul(
    //	.clk        (clk            ),
    //    .resetn     (~rst           ),
    //    .mul_signed (mul_signed     ),
    //    .ina        (      ), // 乘法源操作数1
    //    .inb        (      ), // 乘法源操作数2
    //    .result     (mul_result     ) // 乘法结果 64bit
    //);

    // DIV part
    wire [63:0] div_result;//高32位是余数，低32位是商
    wire div_ready_i;
    reg stallreq_for_div;//是否由于除法运算导致流水线暂停
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),//复位
        .clk          (clk          ),//时钟
        .signed_div_i (signed_div_o ),//是否为有符号除法运算，1为有符号
        .opdata1_i    (div_opdata1_o    ),//被除数
        .opdata2_i    (div_opdata2_o    ),//除数
        .start_i      (div_start_o      ),//是否开始除法运算
        .annul_i      (1'b0      ),      //是否取消除法运算，1为取消
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )//除法运算是否结束
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
            case ({inst_div,inst_divu})
                2'b10:begin
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
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
                2'b01:begin
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
   wire whilo_e;
   wire [31:0] hi_rdata;
   wire [31:0] lo_rdata;
   assign {whilo_e,hi_rdata,lo_rdata}=(inst_div|inst_divu) ? { 1'b1,div_result[63:32] ,div_result[31:0] }:
                                        {1'b0,hi_data,lo_data};
   assign ex_mem_lohi_bus={whilo_e ,hi_rdata,lo_rdata};
    // mul_result 和 div_result 可以直接使用
    
endmodule
