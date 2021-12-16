#移位综合乘除法器
##端口说明
'rst'：输入，复位信号；
'clk'：输入，时钟信号；
'sel_mul_div'：输入，乘除法选择信号；
'signed_i'：输入，符号选择信号；
'opdata1_i'：输入，乘除法源操作数1；
'opdata2_i'：输入，乘除法源操作数2；
'start_i'：输入，开始信号
'annul_i'：输入，取消信号
'result_o'：输出，乘除法结果
'ready_o'：输出，完成信号
##信号说明
'rst'：复位信号，用于复位
'clk'：时钟信号，用于产生时钟信号
'sel_mul_div'：乘除法选择信号，用于选择乘除法器进行除法还是除法
'signed_i'：符号选择信号,用于选择进行乘除法操作的是有符号数还是无符号数
'start_i'：开始信号，用于表示乘除法是否开始
'annul_i'：取消信号，用于取消乘除法操作
'ready_o'：完成信号，用于表示乘除法是否完成运算
##功能模块说明
        实现了复用主要逻辑的移位综合乘除法器，用于进行32位二进制数的乘除法，包括无符号数和有符号的乘除法，
##总体结构图
