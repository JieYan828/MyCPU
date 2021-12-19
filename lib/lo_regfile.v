module lo_regfile(
    input wire clk,
    input wire hi_r,
    input wire lo_r,
    output wire [31:0] rdata,
    
    input wire hi_we,
    input wire lo_we,
    input wire [31:0] wdata_lo,
    input wire [31:0] wdata_hi
    );
    reg [31:0] lo_reg;
    reg [31:0] hi_reg;
    always @ (posedge clk) begin
        if (hi_we ==1'b1) begin
            hi_reg <= wdata_hi;
        end
        if (lo_we ==1'b1)begin
        lo_reg <= wdata_lo;
        end
    end
    assign rdata =lo_r?(/*lo_we ?wdata_lo:*/lo_reg):
                   hi_r?(/*hi_we ?wdata_hi:*/hi_reg):32'b0;
    
endmodule
