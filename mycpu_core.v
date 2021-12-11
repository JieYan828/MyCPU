`include "lib/defines.vh"
module mycpu_core(
    input wire clk,
    input wire rst,
    input wire [5:0] int,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;
    wire [`BR_WD-1:0] br_bus; 
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;
    wire [`StallBus-1:0] stall;
    
    //HILO寄存器
    wire stallreq_for_ex;
    wire [7:0] lo_hi_to_ex_bus;
    wire [31:0] hi_o;
    wire [31:0] lo_o;
    wire [34:0] lo_hi_to_wb_bus;
    wire lo_hi_we;
    wire [31:0] hi_i;
    wire [31:0] lo_i;
    wire [66:0] lo_hi_ex_to_wb_bus;
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    wire [31:0] EX_ID ;//上一条指令的结果
    wire EX_wb_en; //上一条指令的写回使能为高
    wire [4:0] EX_wb_r; //上一条指令的写回寄存器
    wire EX_sel_rf_res; //解决load引起的数据相关
    wire MEM_sel_rf_res;
    //wire stallreq;
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    wire [31:0] MEM_ID;//MEM段手中的运算结果
    wire MEM_wb_en; //写回使能为高
    wire [4:0] MEM_wb_r; //写回寄存器的索引
    wire MEM_sel_rf_res;
    wire stallreq_for_load;
    
    //解决数据相关！！！！！！！！！！！！！！！！！！！！！！！！！！！！
    wire [31:0] WB_ID;//MEM段手中的运算结果
    wire WB_wb_en; //写回使能为高
    wire [4:0] WB_wb_r; //写回寄存器的索引

    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );
    

    ID u_ID(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        //.stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .br_bus          (br_bus          ),
        .EX_ID           (EX_ID),
        .EX_wb_en        (EX_wb_en),
        .EX_wb_r         (EX_wb_r),
        .EX_sel_rf_res   (EX_sel_rf_res),
        .MEM_sel_rf_res   (MEM_sel_rf_res),
        .MEM_ID          ( MEM_ID),
        .MEM_wb_en       (MEM_wb_en),
        .MEM_wb_r        (MEM_wb_r),
        .WB_ID           (WB_ID),
        .WB_wb_en        (WB_wb_en),
        .WB_wb_r         (WB_wb_r),
        .stallreq         (stallreq_for_load),
        .lo_hi_to_ex_bus (lo_hi_to_ex_bus),
        .lo_hi_to_wb_bus (lo_hi_to_wb_bus)
    );

    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata ),
        .EX_ID         (EX_ID),
        .EX_wb_en        (EX_wb_en),
        .EX_wb_r         (EX_wb_r),
        .EX_sel_rf_res   (EX_sel_rf_res),
        .lo_hi_to_ex_bus (lo_hi_to_ex_bus),
        .hi_o              (hi_o),
        .lo_o              (lo_o),
        .lo_hi_ex_to_wb_bus (lo_hi_ex_to_wb_bus),
        .stallreq_for_ex   (stallreq_for_ex)
    );

    MEM u_MEM(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .MEM_ID           (MEM_ID),
        .MEM_wb_en        (MEM_wb_en),
        .MEM_wb_r         (MEM_wb_r),
        .MEM_sel_rf_res   (MEM_sel_rf_res)
    );
    
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata ),
        .WB_ID           (WB_ID),
        .WB_wb_en        (WB_wb_en),
        .WB_wb_r         (WB_wb_r),
        .lo_hi_to_wb_bus (lo_hi_to_wb_bus),
        .lo_hi_we_o       (lo_hi_we),
        .lo_i             (lo_i),
        .hi_i             (hi_i),
        .lo_hi_ex_to_wb_bus (lo_hi_ex_to_wb_bus)
    );

    CTRL u_CTRL(
    	.rst   (rst   ),
        .stall (stall ),
        .stallreq_for_load  (stallreq_for_load),
        .stallreq_for_ex   (stallreq_for_ex)
    );
    
    HILO u_HILO(
        .clk               (clk               ),
        .rst               (rst               ),
        .hi_o              (hi_o),
        .lo_o              (lo_o),
        .we                (lo_hi_we),
        .hi_i              (hi_i),
        .lo_i              (lo_i)
    );
    
endmodule