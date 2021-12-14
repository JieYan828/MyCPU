module mul_div(
	input wire rst,							//��λ�ź�
	input wire clk,							//ʱ���ź�
	input wire sel_mul_div,                //ѡ���ǳ˷����ǳ���,����
	input wire signed_div_i,				//�Ƿ����з��Ų�����
	input wire[31:0] opdata1_i,				//������1
	input wire[31:0] opdata2_i,				//������2
	input wire start_i,						//��ʼ�ź�
	input wire annul_i,						//ȡ���ź�
	output reg[63:0] result_o,				//���
	output reg ready_o						//�Ƿ�׼���ý��
    );

reg [5:0] op_num=6'd0;//��¼������λ�Ĵ���
reg [5:0] temp_op_num=6'd0;

reg [63:0] temp_a,temp_b,temp_result; //�ֱ����ڴ�������м������洢Դ�������������м�������
reg [31:0] store_a,store_b;
reg [31:0] abs_a,abs_b;//���ڴ��a��b�ľ���ֵ
reg [63:0] temp_temp_result=64'b0,temp_temp_a=64'b0,temp_temp_b=64'b0; //�����λ�Ȳ������м���

reg [1:0] sign; //���ڴ�ŷ��ţ���0λ��ʾ������1�ķ��ţ���1λ��ʾ������2�ķ���
reg [63:0] a_b;

always @ (posedge clk) begin
    if(rst) begin
    result_o <= 64'b0;
    ready_o <= 1'b0;
    end else begin
        if(start_i==0) begin //��λ
        ready_o <= 1'b0;
        result_o <= 64'd0;
        temp_result <= 64'd0;
        end
        else if(start_i) begin//��ʼ���˳���
            if(op_num == 6'd0) begin//��һ���˳������ڣ���Ҫ����ʼֵ
            //temp_op_num <= op_num + 6'd1;
            //op_num <= temp_op_num;
            op_num <= op_num + 6'd1;
            if(signed_div_i) begin //1Ϊ�з�����
            //��������ľ���ֵ
//                abs_a <= (opdata1_i[31]) ? {~opdata1_i+1} : opdata1_i;
//                abs_b <= (opdata2_i[31]) ? {~opdata2_i+1} : opdata2_i;
                if(sel_mul_div==1'b1) begin //�˳���ʱtemp_b��ֵ��һ������Ҫ����һ��
                    temp_b[63:32] <= 32'b0;
                    temp_b[31:0] <= (opdata2_i[31]) ? {~opdata2_i+32'd1} : opdata2_i;
                end else begin
                    temp_b[63:32] <= (opdata2_i[31]) ? {~opdata2_i+32'd1} : opdata2_i;
                    temp_b[31:0] <= 32'b0;
                    //��a-b�Ľ��
                    //a_b <= $signed({32'b0,(opdata1_i[31]) ? {~opdata1_i+1} : opdata1_i} << 1'd1 - {(opdata2_i[31]) ? {~opdata2_i+1} : opdata2_i ,32'b0});
                end
                sign <= {opdata2_i[31],opdata1_i[31]};
                temp_a[63:32] <= 32'b0;
                temp_a[31:0] <= (opdata1_i[31]) ? {~opdata1_i + 32'd1} : opdata1_i;
            end else begin //�޷�����
                if(sel_mul_div==1'b1) begin //�˳���ʱtemp_b��ֵ��һ������Ҫ����һ��
                    temp_b[63:32] <= 32'b0;
                    temp_b[31:0] <= opdata2_i;
                end else begin
                    temp_b[63:32] <= opdata2_i;
                    temp_b[31:0] <= 32'b0;
                    //��a-b�Ľ��
                    //a_b <= $signed({32'b0,opdata1_i} << 1'd1 - {opdata2_i,32'b0});
                end
                sign <= {opdata2_i[31],opdata1_i[31]};
                temp_a[63:32] <= 32'b0;
                temp_a[31:0] <= opdata1_i;
                sign <= 2'b0;
            end
            store_a <= opdata1_i;
            store_b <= opdata2_i;
            temp_result <= 64'b0;
            end
            else if(op_num!=0 && op_num<6'd33) begin //��û������
//                        temp_op_num <= {op_num + 6'd1};
//                        op_num <= temp_op_num;
                        op_num <= op_num + 6'd1;
                        ready_o <= 1'b0;//��û��׼����
                        case (sel_mul_div)
                            1'b1:begin //���˷�
                                    if(temp_b[0] == 1'b1) begin //��Ҫ����x
                                        //temp_temp_result <= {temp_result + temp_a};  //��Ҫ�����𣿣�����������
                                        //temp_result <= temp_temp_result;
                                        temp_result = {temp_result + temp_a};
                                    end
                                    //��λ
//                                    temp_temp_a <= {temp_a<<1'd1}; //a����
//                                    temp_a <= temp_temp_a;
//                                    temp_temp_b <= {temp_b>>1'd1}; //b����λ
//                                    temp_b <= temp_temp_b;
                                    temp_a = {temp_a<<1'd1};
                                    temp_b = {temp_b>>1'd1};
                                end
                            1'b0:begin //������
                                    temp_a = temp_a<<1;
                                    if(temp_a >= temp_b) 
			                             temp_a = temp_a - temp_b + 1'b1;
                                    else 
			                             temp_a = temp_a;
                                    //temp_a <= (temp_a >= temp_b) ? (temp_a - temp_b + 64'd1) : {temp_a<<1'd1};
                                    
                                end
                        endcase
            end
            else if(op_num==6'd33)begin //������
                ready_o <= 1'b1;
                op_num <= 6'd0; //��op_num��0
                if(sel_mul_div==1'b1) begin //�˷������
                    case(sign) //�����Ŵ���
                        2'b00:begin //��������
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
                else begin //���������
                    case(sign) //�����Ŵ���
                        2'b00:begin //��������
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


