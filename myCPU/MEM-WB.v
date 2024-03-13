module MEM_WB(
    input clk, rst,
    //WB操作时需要使用
    input wire rf_we_in,
    input wire mem_wb_en,
    input wire [4:0] rf_waddr_in,
    input wire [31:0] rf_wdata_in,
    input wire [31:0] PC_in,

    output reg rf_we,
    output reg [4:0] rf_waddr,
    output reg [31:0] rf_wdata,
    output reg [31:0] PC
);

always@(posedge clk) begin
    if(rst)begin
        rf_we <= 0;
        rf_waddr <= 0;
        rf_wdata <= 0;
        PC <= 0;
    end
    else if(mem_wb_en && PC_in != 32'h1bfffffc) begin
        rf_we <= rf_we_in;
        rf_waddr <= rf_waddr_in;
        rf_wdata <= rf_wdata_in;
        PC <= PC_in;
    end
end



endmodule