`include "mycpu.h"
module mycpu_top(
    input         clk,
    input         resetn,

    output [3: 0]      arid         ,
    output [31:0]      araddr       ,
    output [7: 0]      arlen        ,
    output [2: 0]      arsize       ,
    output [1: 0]      arburst      ,
    output [1: 0]      arlock       ,
    output [3: 0]      arcache      ,
    output [2: 0]      arprot       ,
    output             arvalid      ,
    input              arready      ,

    input [3: 0]       rid          ,
    input [31:0]       rdata        ,
    input [2: 0]       rresp        ,
    input              rlast        ,
    input              rvalid       ,
    output             rready       ,

    output [3: 0]      awid         ,
    output [31:0]      awaddr       ,
    output [7: 0]      awlen        ,
    output [2: 0]      awsize       ,
    output [1: 0]      awburst      ,
    output [1: 0]      awlock       ,
    output [3: 0]      awcache      ,
    output [2: 0]      awprot       ,
    output             awvalid      ,
    input              awready      ,


    output [3: 0]      wid          ,
    output [31:0]      wdata        ,
    output [3: 0]      wstrb        ,
    output             wlast        ,
    output             wvalid       ,
    input              wready       ,

    input  [3: 0]      bid          ,
    input  [1: 0]      bresp        ,
    input              bvalid       ,
    output             bready,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_we,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         reset;
always @(posedge clk) reset <= ~resetn;

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;

wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;

wire  [4:0]       es_to_ds_dest;
wire  [4:0]       ms_to_ds_dest;
wire  [4:0]       ws_to_ds_dest;

wire es_to_ds_is_exc;
wire ms_to_ds_is_exc;
wire ws_to_ds_is_exc;


wire [31:0] cnt_value_l;
wire [31:0] cnt_value_h;


wire         es_to_ds_load_op;
wire [31:0] es_to_ds_result;
wire [31:0] ms_to_ds_result;
wire [31:0] ws_to_ds_result;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`CSR_BUS_WD  -1:0] ds_to_fs_csr_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`MS_TO_DS_EXBUS_WD - 1: 0] ms_to_ds_exbus;

// inst sram interface
wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 1:0] inst_sram_size;
wire [ 3:0] inst_sram_wstrb;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire         inst_sram_addr_ok;
wire         inst_sram_data_ok;
wire  [31:0] inst_sram_rdata;
// data sram interface
wire        data_sram_req;
wire        data_sram_wr;
wire [ 1:0] data_sram_size;
wire [ 3:0] data_sram_wstrb;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire         data_sram_addr_ok;
wire         data_sram_data_ok;
wire  [31:0] data_sram_rdata;

axi_bridge u_axi_bridge (
    .clk(clk),
    .resetn(resetn),

    // 读请求通道
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    // 读响应通道
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready),

    // 写请求通道
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    // 写数据通道
    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    // 写响应通道
    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready),

    // 类SRAM信号 从方
    // inst
    .inst_sram_req(inst_sram_req),
    .inst_sram_wr(inst_sram_wr),
    .inst_sram_size(inst_sram_size),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_addr(inst_sram_addr),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),

    // data
    .data_sram_req(data_sram_req),
    .data_sram_wr(data_sram_wr),
    .data_sram_size(data_sram_size),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_addr(data_sram_addr),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata)
);

Scnt Scnt(
    .clk(clk),
    .reset(reset),

    .cnt_value_l(cnt_value_l),
    .cnt_value_h(cnt_value_h)
);

// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),

    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_wr(inst_sram_wr),
    //csr_bus
    .ds_to_fs_csr_bus(ds_to_fs_csr_bus),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    .inst_sram_req   (inst_sram_req ),
    .inst_sram_size  (inst_sram_size),
    .inst_sram_wstrb   (inst_sram_wstrb ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);
wire ALE_exc;
wire [31:0] es_pc;

// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //dest
    .es_to_ds_dest  (es_to_ds_dest)  ,
    .ms_to_ds_dest  (ms_to_ds_dest)  ,
    .ws_to_ds_dest  (ws_to_ds_dest)  ,
    //load_op
    .es_to_ds_load_op(es_to_ds_load_op),
    //result
    .es_to_ds_result(es_to_ds_result),
    .ms_to_ds_result(ms_to_ds_result),
    .ws_to_ds_result(ws_to_ds_result),
    .data_sram_addr(data_sram_addr),
    //is_exc
    .es_to_ds_is_exc(es_to_ds_is_exc),
    .ms_to_ds_is_exc(ms_to_ds_is_exc),
    .ws_to_ds_is_exc(ws_to_ds_is_exc),
    .ALE_exc(ALE_exc),
    .es_pc(es_pc),
    .ds_to_fs_csr_bus(ds_to_fs_csr_bus),
    .ms_to_ds_exbus(ms_to_ds_exbus),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   )
);

// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    .es_to_ds_dest  (es_to_ds_dest)  ,
    //to ds
    .es_to_ds_is_exc(es_to_ds_is_exc),
    .es_pc(es_pc),
    .ALE_exc(ALE_exc),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .es_to_ds_load_op(es_to_ds_load_op),
    .es_to_ds_result(es_to_ds_result),
    .data_sram_addr_ok(data_sram_addr_ok),
    // data sram interface
    .data_sram_req   (data_sram_req   ),
    .data_sram_wr   (data_sram_wr),
    .data_sram_size (data_sram_size),
    .data_sram_wstrb   (data_sram_wstrb  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_data_ok(data_sram_data_ok)
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    .ms_to_ds_dest  (ms_to_ds_dest)  ,
    .ms_to_ds_result(ms_to_ds_result),
    //to ds
    .ms_to_ds_is_exc(ms_to_ds_is_exc),
    .ms_to_ds_exbus(ms_to_ds_exbus),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_data_ok(data_sram_data_ok),
    .data_sram_rdata(data_sram_rdata),
    //from cnt
    .cnt_value_l(cnt_value_l),
    .cnt_value_h(cnt_value_h)
);

// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    .ws_to_ds_dest  (ws_to_ds_dest)  ,
    .ws_to_ds_result(ws_to_ds_result),
    //to ds
    .ws_to_ds_is_exc(ws_to_ds_is_exc),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule
