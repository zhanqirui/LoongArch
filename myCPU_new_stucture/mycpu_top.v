`include "DEFINE.vh"
module mycpu_top(
    input  wire        clk,
    input  wire        resetn,      //low valid
    // inst sram interface
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,

    output wire inst_sram_en,
    output wire data_sram_en
);


wire IF_fresh;
wire stall;
//reset和valid信号生成
reg         reset;
always @(posedge clk) 
    reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

wire [31:0] inst;
wire ds_allow_in;
wire [`FS_TO_DS_WD - 1 : 0] fs_to_ds_bus;
wire [`BR_TO_FS_WD - 1 : 0] br_bus;
wire fs_to_ds_valid;

IF_stage U_IF_stage(
    .clk(clk),
    .reset(reset),
    .br_bus(br_bus),
    .ds_allow_in(ds_allow_in),
    .inst_sram_rdata(inst_sram_rdata),
    .IF_fresh(IF_fresh),

    .inst_sram_en(inst_sram_en),
    .inst_sram_we(inst_sram_we),

    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),

    .fs_to_ds_bus(fs_to_ds_bus),
    .fs_to_ds_valid(fs_to_ds_valid)
);        


// output ds_to_es_valid,
// output [`DS_TO_ES_WD - 1: 0] ds_to_es_bus,

// output [`BR_TO_FS_WD - 1: 0] br_bus                                   
wire es_allow_in;
wire [`WS_TO_RF_WD-1:0] ws_to_rf_bus;
wire ds_to_es_valid;
wire [`DS_TO_ES_WD - 1: 0] ds_to_es_bus;
wire [`DS_TO_CHE_WD-1:0] ds_to_che_bus;
ID_stage u_ID_stage(
    .clk(clk),
    .valid(valid),
    .rst(reset),
    .fs_to_ds_bus(fs_to_ds_bus),
    .fs_to_ds_valid(fs_to_ds_valid),
    .ds_allow_in(ds_allow_in),
    .es_allow_in(es_allow_in),
    .ws_to_rf_bus(ws_to_rf_bus),
    .IF_fresh(IF_fresh),
    .ds_to_es_valid(ds_to_es_valid),
    .ds_to_es_bus(ds_to_es_bus),
    .br_bus(br_bus),
    .ds_to_che_bus(ds_to_che_bus)
   
);


//EXEstage
wire ms_allow_in, es_to_ms_valid;
wire [`ES_TO_MS_WD - 1: 0] es_to_ms_bus;
wire [`ES_TO_CHE_WD-1:0] es_to_che_bus;
EXE_stage U_EXE_srage(
    .clk(clk),
    .rst(reset),
    .stall(stall),
    .ds_to_es_valid(ds_to_es_valid),
    .ds_to_es_bus(ds_to_es_bus),
    .ms_allow_in(ms_allow_in),
    .es_allow_in(es_allow_in),
    .es_to_ms_valid(es_to_ms_valid),
    .es_to_ms_bus(es_to_ms_bus),
    .data_sram_we(data_sram_we),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .es_to_che_bus(es_to_che_bus)
);

wire ws_allow_in;
wire ms_to_ws_valid;
wire [`MS_TO_WS_WD-1:0] ms_to_ws_bus;
wire [`MS_TO_CHE_WD-1:0] ms_to_che_bus;
MEM_stage U_MEM_stage(
    .clk(clk),
    .rst(reset),
    .es_to_ms_valid(es_to_ms_valid),
    .es_to_ms_bus(es_to_ms_bus),
    .ws_allow_in(ws_allow_in),
    .data_sram_rdata(data_sram_rdata),
    .ms_allow_in(ms_allow_in),
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_to_ws_bus(ms_to_ws_bus),
    .ms_to_che_bus(ms_to_che_bus)
);



chector u_chector(
    .ds_to_che_bus(ds_to_che_bus),
    .es_to_che_bus(es_to_che_bus),
    .ms_to_che_bus(ms_to_che_bus),

    .is_stall(stall)
    
);

WB_stage U_WB_stage(
    .clk(clk),
    .rst(reset),
    .ms_to_ws_valid(ms_to_ws_valid),
    .ms_to_ws_bus(ms_to_ws_bus),
    .ws_allow_in(ws_allow_in),
    .ws_to_rf_bus(ws_to_rf_bus),
    .pc_WB(debug_wb_pc),
    .rf_we_out(debug_wb_rf_we),
    .dest_WB(debug_wb_rf_wnum),
    .final_result_WB(debug_wb_rf_wdata)
);

// debug info generate

assign data_sram_en = 1'b1;

endmodule
