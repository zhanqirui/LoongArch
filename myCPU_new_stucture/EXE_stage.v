`include "DEFINE.vh"

module EXE_stage(
    input clk, rst,
    //?NEED?
    input stall,
    //上一级流水线给的信息
    input  ds_to_es_valid,
    input  [`DS_TO_ES_WD - 1 : 0] ds_to_es_bus,
    //下一级流水线给的信息
    input  ms_allow_in,

    output es_allow_in,

    output es_to_ms_valid,
    output [`ES_TO_MS_WD - 1: 0] es_to_ms_bus,

    output [ 3:0] data_sram_we   ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata ,
    output [`ES_TO_CHE_WD-1:0] es_to_che_bus
);

reg [`DS_TO_ES_WD - 1 : 0] r_ds_to_es_bus;
// ds_to_es_bus = {rf_or_mem_EXE, mem_we, rf_we_EXE, dest_EXE, alu_op_EXE,  rkd_value_EXE, alu_src1_EXE, alu_src2_EXE};
wire rf_or_mem_EXE, mem_en_EXE, rf_we_EXE;
wire [4:0] dest_EXE;
wire [11:0] alu_op_EXE;
wire [31:0] rkd_value_EXE, alu_src1_EXE, alu_src2_EXE;

wire [31:0] alu_result_EXE;
wire [31:0] pc_EXE;

always@(posedge clk)
    if(rst || stall)
        r_ds_to_es_bus <= 0;
    else if(ds_to_es_valid && es_allow_in)
        r_ds_to_es_bus <= ds_to_es_bus;

assign {rf_or_mem_EXE, mem_en_EXE, rf_we_EXE, dest_EXE, alu_op_EXE, pc_EXE,  rkd_value_EXE, alu_src1_EXE, alu_src2_EXE} = r_ds_to_es_bus;

reg es_valid;
wire es_ready_go;

assign es_ready_go = 1'b1;
assign es_to_ms_valid = es_ready_go && es_valid;
assign es_allow_in = (!es_valid || es_ready_go && ms_allow_in) & ~stall;

always@(posedge clk)
    if(rst)
        es_valid <= 0;
    else if(es_allow_in)
        es_valid <= ds_to_es_valid;


alu u_alu(
    .alu_op(alu_op_EXE),
    .alu_src1(alu_src1_EXE),
    .alu_src2(alu_src2_EXE),
    .alu_result(alu_result_EXE)
);
// 1 + 1 + 5 + 5 + 5 + 32 + 32 = 71
assign es_to_ms_bus = {rf_or_mem_EXE, rf_we_EXE, dest_EXE, pc_EXE, alu_result_EXE};

assign data_sram_we = {4{mem_en_EXE && es_valid}};
assign data_sram_addr = alu_result_EXE;
assign data_sram_wdata = rkd_value_EXE;

assign es_to_che_bus = {rf_we_EXE, dest_EXE};

endmodule