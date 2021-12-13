`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    output wire stallreq_for_ex,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen, //�ֽ�дʹ�ܣ�һλ����һ���ֽڵ�д�ź�
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    //���ڽ���������
    output wire [31:0] EX_ID ,//ִ�к�Ľ��
    output wire EX_wb_en, //д��ʹ��Ϊ��
    output wire [4:0] EX_wb_r, //д�ؼĴ���������
    
    output wire EX_sel_rf_res,
    
    input wire [7:0] lo_hi_to_ex_bus,
    input wire[31:0] hi_o,
    input wire[31:0] lo_o,
    
    output wire [66:0] lo_hi_ex_to_wb_bus, //���ģ�������������������������������������������������
    output wire [31:0] EX_pc,//�������div������������
    input wire WB_lo_hi_we
    //���ڽ��load���µ��������
    //input wire MEM_sel_rf_res,
    //input wire [4:0] MEM_wb_r,
    //input wire MEM_wb_en
    //output wire stallreq
    
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;
    reg [`ID_TO_EX_WD-1:0] store_id_to_ex_bus_r;
    reg [7:0] lo_hi_to_ex_bus_r;
    reg [7:0] store_div_bus;

    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        // else if (flush) begin
        //     id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        // end
        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
            lo_hi_to_ex_bus_r <= store_div_bus;
        end
        else if (stall[2]==`NoStop) begin
            store_id_to_ex_bus_r <= id_to_ex_bus;
            id_to_ex_bus_r <= id_to_ex_bus; //EX������ִ��
            lo_hi_to_ex_bus_r <= lo_hi_to_ex_bus;
            store_div_bus <= lo_hi_to_ex_bus;
        end
    end

    //assign stallreq = (sel_alu_src1 == MEM_wb_r && MEM_wb_en && sel_rf_res) ? 1'b1 : 1'b0;

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1; //alu_src1һ����3�ֿ���
    wire [3:0] sel_alu_src2; //alu_src2һ����4�п���
    wire data_ram_en;
    wire [3:0] data_ram_wen;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;
    reg is_in_delayslot;
    
    wire [1:0] sel_lo_hi; //ѡ����lo����hi�Ĵ���
    wire lo_hi_we; //дʹ��
    wire lo_hi_re; //��ʹ��
    wire inst_mult,inst_multu,inst_div, inst_divu; 
    wire [63:0] lo_hi_result;

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
    } = (WB_lo_hi_we) ? 148'd0 : id_to_ex_bus_r; //��ID�δ������Ķ�����EX�θ�ֵ
    
    assign {
    sel_lo_hi, //7:6
    lo_hi_we, //5
    lo_hi_re, //4
    inst_mult,//3
    inst_multu,//2
    inst_div,//1
    inst_divu//0
    } = lo_hi_to_ex_bus_r;
    
    assign EX_sel_rf_res = sel_rf_res;
    assign EX_pc = ex_pc;

    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend; //������������չ��������0��չ�ͣ�����������������������������
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]}; 

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result; //ALU�δ�ŵĽ���Լ�������չ�Ľ��

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
    assign ex_result = (lo_hi_re & sel_lo_hi[0]==1) ? lo_o: 
                        (lo_hi_re & sel_lo_hi[0]==0) ? hi_o : alu_result;
                        
    //assign ex_result = alu_result;
    assign EX_ID = ex_result; //�õ�alu�Ľ����������������������!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    assign EX_wb_en = rf_we;
    assign EX_wb_r = rf_waddr;
    //assign EX_sel_rf_res = sel_rf_res;
    
    //���ƶ�д������������������������������������������������������������������
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
    
// MUL part
    wire [63:0] mul_result;
    wire mul_signed; // �з��ų˷����

    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),
        .mul_signed (mul_signed     ),
        .ina        (      ), // �˷�Դ������1
        .inb        (      ), // �˷�Դ������2
        .result     (mul_result     ) // �˷���� 64bit
    );

    // DIV part
    wire [63:0] div_result;
    //wire inst_div, inst_divu; 
    wire div_ready_i;
    reg stallreq_for_div; 
    assign stallreq_for_ex = stallreq_for_div;

    reg [31:0] div_opdata1_o;
    reg [31:0] div_opdata2_o;
    reg div_start_o;
    reg signed_div_o;

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),
        .result_o     (div_result     ), // ������� 64bit
        .ready_o      (div_ready_i      )
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

    // mul_result �� div_result ����ֱ��ʹ��
    assign lo_hi_result = (inst_div | inst_divu) ? div_result : 
                   (inst_mult | inst_multu) ? mul_result : rf_rdata1;
    
    assign lo_hi_ex_to_wb_bus = {
    sel_lo_hi,
    lo_hi_we,
    lo_hi_result
    };
    
endmodule