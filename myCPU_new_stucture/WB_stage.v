`include "mycpu.h"

module wb_stage(
    input  wire                         clk           ,
    input  wire                         reset         ,
    //allowin
    output wire                         ws_allowin    ,
    // to ds
    output wire [ 4:0] ws_to_ds_dest,
    output wire [31:0] ws_to_ds_result,
    //TODO 改CPUtop
    output wire ws_to_ds_is_exc,
    //from ms
    input  wire                         ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output wire [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output wire [31:0] debug_wb_pc     ,
    output wire [ 3:0] debug_wb_rf_we  ,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;
wire        ws_is_exc;
reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire [13:0] ws_csr_num;
wire [1:0]  ws_csr_we;
wire [31:0] ws_rkd_value;
wire [31:0] ws_rj_value;

assign {ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ws_final_result,  //63:32
        ws_pc,             //31:0
        ws_is_exc
       } = ms_to_ws_bus_r;

assign ws_to_ds_dest = ws_dest & {5{ws_valid}};
assign ws_to_ds_is_exc = ws_is_exc & ws_valid;
wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_to_ds_result = ws_final_result;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
end
always@(posedge clk)
    if(reset)
        ms_to_ws_bus_r <= 0;
    else  if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end

assign rf_we    = ws_gr_we && ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{rf_we & ws_valid}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
