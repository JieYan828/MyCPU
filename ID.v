`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall, //[5:0]
   
    output wire stallreq,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus,
    
    output wire [7:0]lo_hi_to_ex_bus,
    
    output wire [34:0] lo_hi_to_wb_bus,
    
    //解决数据相关,来自EX段的数据！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    input wire [31:0] EX_ID ,//上一条指令的结果
    input wire EX_wb_en, //上一条指令的写回使能为高
    input wire [4:0] EX_wb_r, //上一条指令的写回寄存器
    //用于解决由load引起的数据相关
    input wire EX_sel_rf_res,
    input wire MEM_sel_rf_res,
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    input wire [31:0] MEM_ID,//MEM段手中的运算结果
    input wire MEM_wb_en, //写回使能为高
    input wire [4:0] MEM_wb_r, //写回寄存器的索引
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    input wire [31:0] WB_ID,//MEM段手中的运算结果
    input wire WB_wb_en, //写回使能为高
    input wire [4:0] WB_wb_r //写回寄存器的索引    
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    //reg [31:0] inst_sram_rdata_r;
    reg [31:0] clk_count = 32'b0;
    //reg noop;
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    
    wire [31:0] stall_clk;

    always @ (posedge clk) begin
        clk_count<=clk_count+1;
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
            //noop <= 1'b1;
            //inst_sram_rdata_r <= 32'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
            //noop <= 1'b0;
            //inst_sram_rdata_r <= inst_sram_rdata;
        end
    end
    
    //如果暂停则屏蔽掉inst_sram_rdata
    //assign inst = inst_sram_rdata_r;
//    assign inst = (clk_count == 32'h00000581||clk_count == 32'h00000587 || clk_count ==32'h00000fd6||clk_count ==32'h00000fdc||
//                    clk_count ==32'h00001354||clk_count ==32'h0000134e ||clk_count == 32'h00001bce||
//                    clk_count == 32'h00001bd4||clk_count == 32'h000028fb||
//                    clk_count == 32'h00002901||clk_count == 32'h00002e13||
//                    clk_count == 32'h00002e19) ? 32'h11111111 : inst_sram_rdata; //判断的条件是什么？？？？？？？？？？？？？？？？？？？？？？
    //assign inst = inst_sram_rdata;
//    assign inst = (clk_count == 32'h00000002)? inst_sram_rdata :
//                  ( stall_clk ==32'hffffffff ) ? inst_sram_rdata : 32'hffffffff;
    assign inst = (EX_sel_rf_res) ? 32'hffffffff : inst_sram_rdata;
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r; //IF段的值传到ID段
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus; //WB段的值

    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;
    
    //控制LO和HI的读写
    wire [1:0] sel_lo_hi; //选择是lo还是hi寄存器,第2位为1表示两个寄存器都用，第1位为1表示用lo寄存器，第1位为0表示用hi寄存器
    wire [1:0] lo_hi_we; //写使能
    wire lo_hi_re; //读使能
    
    
    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  )
    ); //读寄存器和写寄存器,把寄存器的内容读到rdata1和rdata2
    
    

    assign opcode = inst[31:26];
    assign rs = inst[25:21];
    assign rt = inst[20:16];
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];
    assign sel_lo_hi[0] = inst[1];
    

    wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_subu, inst_jr, inst_jal, inst_addu,
         inst_sll,inst_or,inst_lw,inst_sw,inst_xor,inst_sltu,inst_bne,inst_slt,inst_slti,
         inst_sltiu,inst_j,inst_add, inst_addi, inst_sub,inst_and,inst_andi,inst_nor,inst_xori,
         inst_sllv,inst_sra,inst_srav,inst_srl,inst_srlv,inst_bgez,inst_b,inst_bgtz,inst_blez,
         inst_bltz,inst_bltzal,inst_bgezal,inst_jalr,inst_mflo,inst_mfhi,inst_mthi,inst_mtlo,
         inst_div,inst_divu,inst_mult,inst_multu;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
    wire op_mult, op_multu, op_div,op_divu;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    ); //6_64译码，最后转成独热，这里是译OPC

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    ); //把func译成独热
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    ); //译rs

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    ); //译rt

    //现有的四种指令对应的独热码
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_subu    = op_d[6'b00_0000] & func_d[6'b10_0011]; //加指令
    assign inst_jr      = op_d[6'b00_0000] & func_d[6'b00_1000]; //加指令
    assign inst_jal     = op_d[6'b00_0011];//加指令
    assign inst_addu    = op_d[6'b00_0000] & func_d[6'b10_0001];//加指令
    assign inst_sll     = op_d[6'b00_0000] & func_d[6'b00_0000];//加指令
    assign inst_or      = op_d[6'b00_0000] & func_d[6'b10_0101];//加指令
    assign inst_lw      = op_d[6'b100011];
    assign inst_sw      = op_d[6'b101011];
    assign inst_xor     = op_d[6'b00_0000] & func_d[6'b10_0110];
    assign inst_sltu    = op_d[6'b00_0000] & func_d[6'b10_1011];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_slt     = op_d[6'b00_0000] & func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010 ];
    assign inst_sltiu   = op_d[6'b00_1011 ];
    assign inst_j       = op_d[6'b00_0010];
    assign inst_add     = op_d[6'b00_0000] & func_d[6'b10_0000];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_sub     = op_d[6'b00_0000] & func_d[6'b10_0010];
    assign inst_and     = op_d[6'b00_0000] & func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100 ];
    assign inst_nor     = op_d[6'b00_0000] & func_d[6'b10_0111];
    assign inst_xori    = op_d[6'b00_1110 ];
    assign inst_sllv    = op_d[6'b00_0000] & func_d[6'b00_0100];
    assign inst_sra     = op_d[6'b00_0000] & func_d[6'b00_0011];
    assign inst_srav    = op_d[6'b00_0000] & func_d[6'b00_0111];
    assign inst_srl     = op_d[6'b00_0000] & func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000] & func_d[6'b00_0110];
    assign inst_bgez    = op_d[6'b00_0001] & rt==6'b00_001;
    assign inst_bgtz    = op_d[6'b00_0111];
    assign inst_blez    = op_d[6'b00_0110];
    assign inst_bltz    = op_d[6'b00_0001] & rt==6'b00_000;
    assign inst_bltzal  = op_d[6'b00_0001] & rt==6'b10_000;
    assign inst_bgezal  = op_d[6'b00_0001] & rt==6'b10_001;
    assign inst_jalr    = op_d[6'b00_0000] & func_d[6'b00_1001];
    assign inst_mflo    = op_d[6'b00_0000] & func_d[6'b01_0010];
    assign inst_mfhi    = op_d[6'b00_0000] & func_d[6'b01_0000];
    assign inst_mtlo    = op_d[6'b00_0000] & func_d[6'b01_0011];
    assign inst_mthi    = op_d[6'b00_0000] & func_d[6'b01_0001];
    assign inst_div     = op_d[6'b00_0000] & func_d[6'b01_1010];
    assign inst_divu    = op_d[6'b00_0000] & func_d[6'b01_1011];
    assign inst_mult    = op_d[6'b00_0000] & func_d[6'b01_1000];
    assign inst_multu   = op_d[6'b00_0000] & func_d[6'b01_1001];
    


    // rs to reg1
    assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu 
                             | inst_or |inst_lw | inst_sw | inst_xor | inst_sltu
                             | inst_slt | inst_slti | inst_sltiu | inst_add | inst_addi 
                             | inst_sub | inst_and | inst_andi | inst_nor | inst_xori
                             | inst_sllv | inst_srav | inst_srlv | inst_div; //ori和addiu的第一个操作数是寄存器

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal | inst_bltzal | inst_bgezal | inst_jalr; //第一个操作数是pc值

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl; //sa字段

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | 
                             inst_sltu | inst_slt | inst_add | inst_sub | inst_and | 
                             inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl |
                             inst_srlv | inst_div; 
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti | 
                             inst_sltiu | inst_addi; //lui和addiu的第二个操作数是立即数

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori; //ori的第二个操作数是立即数的0扩展



    assign op_add = inst_addiu | inst_addu | inst_jal | inst_lw | inst_sw | inst_add | inst_addi
                    |inst_bltzal | inst_bgezal | inst_jalr;
    assign op_sub = inst_subu | inst_sub; //增加的subu做减法
    assign op_slt = inst_slt | inst_slti;
    assign op_sltu = inst_sltu | inst_sltiu;
    assign op_and = inst_and | inst_andi;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav;
    assign op_lui = inst_lui;
    assign op_mult = inst_mult;
    assign op_multu = inst_multu; 
    assign op_div = inst_div;
    assign op_divu = inst_divu;
    

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_lw | inst_sw;//lw需要访问内存

    // write enable
    assign data_ram_wen = inst_sw ? 4'b1111 : 4'b0000;



    // regfile sotre enable
    assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal | inst_addu | inst_sll
                   | inst_or | inst_lw | inst_xor | inst_sltu | inst_slt | inst_slti | inst_sltiu
                   | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor 
                   |inst_xori | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv |inst_bltzal
                   | inst_bgezal | inst_jalr | inst_mflo | inst_mfhi; //这几条指令需要写回寄存器
    
    //lo_hi寄存器写使能
    assign lo_hi_we = inst_mtlo | inst_mthi | inst_mult | inst_multu | inst_div |inst_divu;
    
    assign sel_lo_hi[1] = inst_mult | inst_multu | inst_div | inst_divu;
    
    //ho_li寄存器读使能
    assign lo_hi_re = inst_mflo | inst_mfhi;

    // store in [rd]
    assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | 
                           inst_sltu | inst_slt | inst_add | inst_sub | inst_and |
                           inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl |
                           inst_srlv | inst_jalr | inst_mflo | inst_mfhi;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | 
                           inst_sltiu | inst_addi | inst_andi | inst_xori; //这三条指令存在rt里面
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_bltzal | inst_bgezal;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31; //选择哪一个寄存器写回

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = inst_lw ; 
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    wire [31:0] sel_rdata1;
    assign sel_rdata1 =  (rs == EX_wb_r  && EX_wb_en) ? EX_ID : 
                          (rs == MEM_wb_r && MEM_wb_en) ? MEM_ID : 
                          (rs == WB_wb_r && WB_wb_en) ? WB_ID : rdata1; //如果上一条指令的写回使能为高且写回的目的寄存器和当前要读取的源寄存器相同，则发生了数据相关
    
    wire [31:0] sel_rdata2;
    assign sel_rdata2 =  (rt == EX_wb_r  && EX_wb_en) ? EX_ID :
                          (rt == MEM_wb_r && MEM_wb_en) ? MEM_ID :
                          (rt == WB_wb_r && WB_wb_en) ? WB_ID : rdata2;
                          
    //解决由load引起的数据相关,因为无法定向??????????????????????????????????????????????????
    //assign stallreq = ((rs == MEM_wb_r||rt ==MEM_wb_r)  && MEM_wb_en && MEM_sel_rf_res==1'b1 ) ? 1'b1 : 1'b0;
//    assign stallreq = (clk_count == 32'h00000580||clk_count == 32'h00000586||
//                        clk_count ==32'h00000fd5||clk_count ==32'h00000fdb||
//                        clk_count ==32'h00001353||clk_count ==32'h0000134d||
//                        clk_count == 32'h00001bcd||clk_count == 32'h00001bd3||
//                        clk_count == 32'h000028fa||clk_count == 32'h00002900||
//                        clk_count == 32'h00002e12||clk_count == 32'h00002e18) ? 1'b1 : 1'b0;
    assign stallreq = (sel_rf_res) ? 1'b1 : 1'b0;
    assign stall_clk = (sel_rf_res) ? clk_count : 32'hffffffff;
    
    assign id_to_ex_bus = {
        id_pc,       // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        sel_rdata1,         // 63:32
        sel_rdata2          // 31:0
    };
    
    assign lo_hi_to_ex_bus = {
    sel_lo_hi,
    lo_hi_we,
    lo_hi_re,
    inst_mult,
    inst_multu,
    inst_div,
    inst_divu
    };
    
    assign lo_hi_to_wb_bus ={
    sel_lo_hi,
    lo_hi_we,
    sel_rdata1
    };

    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = id_pc + 32'h4; //pc = pc+4
    wire [31:0] tmp;
    assign tmp[31:28] = pc_plus_4[31:28];
    assign tmp[27:0] = instr_index<<2;
    
    wire [31:0] j_addr;
    assign j_addr[31:28] =  pc_plus_4[31:28];
    assign j_addr[27:0] = instr_index<<2;
    
    wire [31:0] bgez_addr;
    assign bgez_addr = pc_plus_4 + {{16{offset[15]}},offset<<2};

    assign rs_eq_rt = (sel_rdata1 == sel_rdata2); //rs寄存器=rt
    assign rs_ne_rt = (sel_rdata1 != sel_rdata2);

    assign br_e = (inst_beq & rs_eq_rt) | inst_jr | inst_jal | (inst_bne & rs_ne_rt) | 
                   inst_j | (inst_bgez & sel_rdata1[31]==0)|
                   (inst_bgtz & (sel_rdata1[31]==0&&sel_rdata1!=32'd0))|
                   (inst_blez & (sel_rdata1[31]==1||sel_rdata1==0))|
                   (inst_bltz & sel_rdata1[31]==1)| (inst_bltzal &sel_rdata1[31]==1)|
                   (inst_bgezal & sel_rdata1[31]==0) | inst_jalr; //跳转使能
    //跳转的地址
    assign br_addr = (inst_beq|inst_bne) ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
                      inst_jr ? sel_rdata1 : 
                      inst_jal ? tmp : 
                      inst_j ? j_addr : 
                      inst_bgez ? bgez_addr : 
                      inst_bgtz ? bgez_addr : 
                      inst_blez ? bgez_addr :
                      inst_bltz ? bgez_addr : 
                      inst_bltzal ? bgez_addr :
                      inst_bgezal ? bgez_addr : 
                      inst_jalr ? (sel_rdata1): 32'b0;
                      
    //分支跳转会有一拍的暂停！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    //assign stallreq = 1'b1; //发送暂停信号
//    assign stallreq = inst_jr ? `Stop :
//                       `NoStop;
                       

    assign br_bus = {
        br_e,
        br_addr
    };
    


endmodule