`include "DEFINE.vh"

module MEM_stage(
    input clk, rst,

    //来自上一级流水线
    input es_to_ms_valid,
    input [`ES_TO_MS_WD-1:0] es_to_ms_bus,

    //来自下一级流水线
    input ws_allow_in,

    input [31:0] data_sram_rdata,
    //给上一级流水线
    output ms_allow_in,

    //给下一级流水线
    output ms_to_ws_valid,
    output [`MS_TO_WS_WD-1:0] ms_to_ws_bus,

    output [`MS_TO_CHE_WD-1:0] ms_to_che_bus
);

reg [`ES_TO_MS_WD-1:0] r_es_to_ms_bus;
wire ms_ready_go;
reg ms_valid;
wire rf_or_mem_MEM, rf_we_MEM;
wire [4:0] dest_MEM;
wire [31:0] pc_MEM, alu_result_MEM, final_result_MEM;

assign ms_ready_go = 1'b1;
assign ms_allow_in = !ms_valid || ms_ready_go && ws_allow_in;
assign ms_to_ws_valid = ms_ready_go && ms_valid;

always@(posedge clk)
    if(rst)
        ms_valid <= 0;
    else if(ms_allow_in)  
        ms_valid <= es_to_ms_valid;

always@(posedge clk)
    if(rst)
        r_es_to_ms_bus <= 0;
    else if(ms_allow_in && es_to_ms_valid)
        r_es_to_ms_bus <= es_to_ms_bus;

// assign es_to_ms_bus = {rf_or_mem_MEM, rf_we_MEM, dest_MEM, pc_MEM, alu_result_MEM};
assign {rf_or_mem_MEM, rf_we_MEM, dest_MEM, pc_MEM, alu_result_MEM} = r_es_to_ms_bus;
assign final_result_MEM = rf_or_mem_MEM ? data_sram_rdata : alu_result_MEM;
// 1 + 5 + 32 + 32 = 70
assign ms_to_ws_bus = {rf_we_MEM, dest_MEM, pc_MEM, final_result_MEM};
assign ms_to_che_bus = {rf_we_MEM, dest_MEM};


endmodule
