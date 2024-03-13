module EXE_MEM(
    input clk,
    input rst,
    input exe_mem_en,

    //MEM操作时需要使用
    input wire mem_en_in,
    input wire  [3:0] data_sram_we_in,
    input wire [31:0]  rkd_value_in,
    input wire [31:0] alu_result_in,

    //WB操作时需要使用
    input wire rf_we_in,
    input wire [4:0] rf_waddr_in,
    input wire rf_or_mem_in,

    //计算NPC时需要使用
    input wire      br_taken_in,
    input wire [31:0] br_target_in,
    input wire [31:0] PC_in,

    output reg mem_en,
    output reg  [3:0] data_sram_we,
    output reg [31:0]  rkd_value,
    output reg [31:0] alu_result,

    output reg rf_we,
    output reg [4:0] rf_waddr,
    output reg rf_or_mem,

    output reg [31:0] br_target,
    output reg br_taken,
    output reg [31:0] PC

);

always@(posedge clk) begin
    if(rst) begin
        rf_we <= 1'b0;
        rf_waddr <= 0;
        rf_or_mem <= 0;

        br_taken <= 0;
        br_target <= 0;
        PC <= 0;

        mem_en <= 0;
        rkd_value <= 0;
        data_sram_we <= 0;
        alu_result <= 0;
    end

    else if(exe_mem_en && PC_in != 32'h1bfffffc)
        rf_we <= rf_we_in;
        rf_waddr <= rf_waddr_in;
        rf_or_mem <= rf_or_mem_in;

        br_taken <= br_taken_in;
        br_target <= br_target_in;
        PC <= PC_in;

        mem_en <= mem_en_in;
        rkd_value <= rkd_value_in;
        data_sram_we <= data_sram_we_in;
        alu_result <= alu_result_in;
end


endmodule