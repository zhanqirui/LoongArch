`include "DEFINE.vh"

module WB_stage(
    input clk, rst,

    //上一级流水线
    input wire ms_to_ws_valid,
    input wire [`MS_TO_WS_WD - 1: 0] ms_to_ws_bus,

    //给上一级流水线
    output wire ws_allow_in,
    //给ID阶段
    output wire [`WS_TO_RF_WD-1:0] ws_to_rf_bus,
    output wire [31:0] pc_WB,
    output wire [3:0] rf_we_out,
    output wire [4 : 0] dest_WB,
    output wire [31:0] final_result_WB
);

reg [`MS_TO_WS_WD - 1: 0] r_ms_to_ws_bus;
wire ws_ready_go, ws_to_rf_valid, rf_we_WB;
reg ws_valid;
always@(posedge clk)
    if(rst)
        ws_valid <= 0;
    else if(ws_allow_in)
        ws_valid <= ms_to_ws_valid;

always@(posedge clk)
    if(rst)
        r_ms_to_ws_bus <= 0;
    else if(ms_to_ws_valid && ws_allow_in)
        r_ms_to_ws_bus <= ms_to_ws_bus;

// assign ms_to_ws_bus = {rf_we, dest_WB, pc_WB, final_result_WB};
assign {rf_we_WB, dest_WB, pc_WB, final_result_WB} = r_ms_to_ws_bus;

assign ws_ready_go = 1'b1;
assign ws_to_rf_valid = ws_ready_go && ws_valid;
assign ws_allow_in = !ws_valid || ws_ready_go;

assign ws_to_rf_bus = {rf_we_WB, dest_WB, final_result_WB};
assign rf_we_out = {4{rf_we_WB}};



endmodule