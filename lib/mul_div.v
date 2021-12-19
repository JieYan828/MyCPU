module mul_div(
	input wire rst,							//复位信号
	input wire clk,							//时钟信号
	input wire sel_mul_div,                //选择是乘法还是除法,新增
	input wire signed_i,				//是否是有符号操作数
	input wire[31:0] opdata1_i,				//操作数1
	input wire[31:0] opdata2_i,				//操作数2
	input wire start_i,						//开始信号
	input wire annul_i,						//取消信号
	output reg[63:0] result_o,				//结果
	output reg ready_o						//是否准备好结果
    );

reg [5:0] op_num=6'd0;//记录进行移位的次数
reg [5:0] temp_op_num=6'd0;

reg [63:0] temp_a,temp_b,temp_result; //分别用于存操作数中间结果，存储源操作数，保存中间运算结果
reg [31:0] store_a,store_b;
reg [31:0] abs_a,abs_b;//用于存放a和b的绝对值
reg [63:0] temp_temp_result=64'b0,temp_temp_a=64'b0,temp_temp_b=64'b0; //存放移位等操作的中间结果

reg [1:0] sign; //用于存放符号，第0位表示操作数1的符号，第1位表示操作数2的符号
reg [63:0] a_b;

always @ (posedge clk) begin
    if(rst) begin
    result_o <= 64'b0;
    ready_o <= 1'b0;
    end else begin
        if(start_i==0) begin //复位
        ready_o <= 1'b0;
        result_o <= 64'd0;
        temp_result <= 64'd0;
        end
        else if(start_i) begin//开始做乘除法
            if(op_num == 6'd0) begin//第一个乘除法周期，需要赋初始值
            //temp_op_num <= op_num + 6'd1;
            //op_num <= temp_op_num;
            op_num <= op_num + 6'd1;
            if(signed_i) begin //1为有符号数
            //求操作数的补码
                if(sel_mul_div==1'b1) begin //乘除法时temp_b的值不一样，需要区分一下
                    temp_b[63:32] <= 32'b0;
                    temp_b[31:0] <= (opdata2_i[31]) ? {~opdata2_i+32'd1} : opdata2_i;
                end else begin
                    temp_b[63:32] <= (opdata2_i[31]) ? {~opdata2_i+32'd1} : opdata2_i;
                    temp_b[31:0] <= 32'b0;
                    //放a-b的结果
                    //a_b <= $signed({32'b0,(opdata1_i[31]) ? {~opdata1_i+1} : opdata1_i} << 1'd1 - {(opdata2_i[31]) ? {~opdata2_i+1} : opdata2_i ,32'b0});
                end
                sign <= {opdata2_i[31],opdata1_i[31]};
                temp_a[63:32] <= 32'b0;
                temp_a[31:0] <= (opdata1_i[31]) ? {~opdata1_i + 32'd1} : opdata1_i;
            end else begin //无符号数
                if(sel_mul_div==1'b1) begin //乘除法时temp_b的值不一样，需要区分一下
                    temp_b[63:32] <= 32'b0;
                    temp_b[31:0] <= opdata2_i;
                end else begin
                    temp_b[63:32] <= opdata2_i;
                    temp_b[31:0] <= 32'b0;
                    //放a-b的结果
                    //a_b <= $signed({32'b0,opdata1_i} << 1'd1 - {opdata2_i,32'b0});
                end
                sign <= {opdata2_i[31],opdata1_i[31]};
                temp_a[63:32] <= 32'b0;
                temp_a[31:0] <= opdata1_i;
                sign <= 2'b0;
            end
            temp_result <= 64'b0;
            end
            else if(op_num!=0 && op_num<6'd33) begin //还没有算完
//                        temp_op_num <= {op_num + 6'd1};
//                        op_num <= temp_op_num;
                        op_num <= op_num + 6'd1;
                        ready_o <= 1'b0;//还没有准备好
                        case (sel_mul_div)
                            1'b1:begin //做乘法
                                    if(temp_b[0] == 1'b1) begin //需要加上x
                                        //temp_temp_result <= {temp_result + temp_a};  //需要这样吗？？？？？？？
                                        //temp_result <= temp_temp_result;
                                        temp_result = {temp_result + temp_a};
                                    end
                                    //移位
                                    temp_a = {temp_a<<1'd1};
                                    temp_b = {temp_b>>1'd1};
                                end
                            1'b0:begin //做除法
                                    temp_a = temp_a<<1;
                                    if(temp_a >= temp_b) 
			                             temp_a = temp_a - temp_b + 1'b1;
                                    else 
			                             temp_a = temp_a;
                                    //temp_a <= (temp_a >= temp_b) ? (temp_a - temp_b + 64'd1) : {temp_a<<1'd1};
                                    
                                end
                        endcase
            end
            else if(op_num==6'd33)begin //算完了
                ready_o <= 1'b1;
                op_num <= 6'd0; //给op_num置0
                if(sel_mul_div==1'b1) begin //乘法赋结果
                    case(sign) //做符号处理
                        2'b00:begin //都是正数
                            result_o <= temp_result;
                        end
                        2'b01:begin
                            result_o <= {~temp_result + 1'd1};
                        end
                        2'b10:begin
                            result_o <= {~temp_result + 1'd1};
                        end
                        2'b11:begin
                            result_o <= temp_result;
                        end
                    endcase
                end
                else begin //除法赋结果
                    case(sign) //做符号处理
                        2'b00:begin //都是正数
                            result_o <= temp_a;
                        end
                        2'b01:begin
                            result_o[31:0] <= {~temp_a[31:0] + 32'd1};
                            result_o[63:32] <= {~temp_a[63:32] + 32'd1};
                        end
                        2'b10:begin
                            result_o[31:0] <= {~temp_a[31:0] + 32'd1};
                            result_o[63:32] <= temp_a[63:32];
                        end
                        2'b11:begin
                             result_o[31:0] <= temp_a[31:0];
                             result_o[63:32] <= {~temp_a[63:32] + 32'd1};
                        end
                    endcase
                end
            end
        end
    end
end

endmodule


