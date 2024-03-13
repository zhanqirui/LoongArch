module ID_EXE(
    input wire clk,
    input wire rst,
    input wire      id_to_exe_en,
    //计算NPC时需要使用
    input wire      br_taken_in,
    input wire [31:0] br_target_in,
    input wire [31:0] PC_in,
    //MEM操作时需要使用
    input wire  [3:0] data_sram_we_in,
    input wire [31:0]  rkd_value_in,
    input wire mem_en_in,
    //EXE操作时需要使用
    input wire [11:0] alu_op_in,
    input wire [31:0] alu_src1_in,
    input wire [31:0] alu_src2_in,
    //WB操作时需要使用
    input wire rf_we_in,
    input wire [4:0] rf_waddr_in,
    input wire rf_or_mem_in,

    output reg [3:0] data_sram_we,
    output reg [31:0] PC,
    output reg [31:0] rkd_value,
    output reg mem_en,
    output reg [11:0] alu_op,
    output reg [31:0] br_target,
    output reg br_taken,

    output reg [31:0] alu_src1,
    output reg [31:0] alu_src2,

    output reg rf_we,
    output reg [4:0] rf_waddr,
    output reg rf_or_mem


);

always@(posedge clk)
    if(rst) begin
        rkd_value <= 32'b0;
        data_sram_we <= 1'b0;
        mem_en<= 1'b0;

        br_taken <= 1'b0;
        br_target <= 32'b0;
        PC <= 32'b0;

        alu_op <= 12'b0;
        alu_src1 <= 32'b0;
        alu_src2 <= 32'b0;

        rf_we <= 1'b0;
        rf_waddr <= 5'b0;
        rf_or_mem <= 1'b0;
    end

    else if(id_to_exe_en && PC_in != 32'h1bfffffc) begin
        
        rkd_value <= rkd_value_in;
        data_sram_we <= data_sram_we_in;
        mem_en<= mem_en_in;

        br_taken <= br_taken_in;
        br_target <= br_target_in;
        PC <= PC_in;

        alu_op <= alu_op_in;
        alu_src1 <= alu_src1_in;
        alu_src2 <= alu_src2_in;

        rf_we <= rf_we_in;
        rf_waddr <= rf_waddr_in;
        rf_or_mem <= rf_or_mem_in;
    end

endmodule