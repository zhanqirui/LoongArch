`include "mycpu.h"



// mycpu_top cpu(




//     .inst_sram_req    (cpu_inst_req    ), o  
//     .inst_sram_wr     (cpu_inst_wr     ), o
//     .inst_sram_size   (cpu_inst_size   ), o
//     .inst_sram_wstrb  (cpu_inst_wstrb  ), o
//     .inst_sram_addr   (cpu_inst_addr   ), o
//     .inst_sram_wdata  (cpu_inst_wdata  ), o
//     .inst_sram_addr_ok(cpu_inst_addr_ok), i
//     .inst_sram_data_ok(cpu_inst_data_ok), i
//     .inst_sram_rdata  (cpu_inst_rdata  ), i
    
//     .data_sram_req    (cpu_data_req    ), o
//     .data_sram_wr     (cpu_data_wr     ), o
//     .data_sram_size   (cpu_data_size   ), o
//     .data_sram_wstrb  (cpu_data_wstrb  ), o
//     .data_sram_addr   (cpu_data_addr   ), o
//     .data_sram_wdata  (cpu_data_wdata  ), o
//     .data_sram_addr_ok(cpu_data_addr_ok), i
//     .data_sram_data_ok(cpu_data_data_ok), i
//     .data_sram_rdata  (cpu_data_rdata  ), i

// );

module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
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
