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

wire invtlb_valid;
wire [4:0] invtlb_op;
wire invtlb_op_exc;
// search port 0
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [9 :0] s0_asid;
wire        s0_found;
wire [3:0]s0_index;
wire [19:0] s0_ppn;
wire [5 :0] s0_ps;
wire [1 :0] s0_plv;
wire [1 :0] s0_mat;
wire        s0_d;
wire        s0_v;
// search port 1
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [9 :0] s1_asid;
wire        s1_found;
wire [3:0] s1_index;
wire [19:0] s1_ppn;
wire [5 :0] s1_ps;
wire [1 :0] s1_plv;
wire [1 :0] s1_mat;
wire        s1_d;
wire        s1_v;
// write port
wire        we;
wire [3:0] w_index;
wire        w_ne;
wire [18:0] w_vppn;
wire [5 :0] w_ps  ;
wire [9 :0] w_asid;
wire        w_g1;
wire        w_g0;
wire [19:0] w_ppn0;
wire [1 :0] w_plv0;
wire [1 :0] w_mat0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_ppn1;
wire [1 :0] w_plv1;
wire [1 :0] w_mat1;
wire        w_d1;
wire        w_v1;
// read port
wire [3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [5 :0] r_ps;
wire [9 :0] r_asid;
wire        r_g;
wire [19:0] r_ppn0;
wire [1 :0] r_plv0;
wire [1 :0] r_mat0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_ppn1;
wire [1 :0] r_plv1;
wire [1 :0] r_mat1;
wire        r_d1;
wire        r_v1;


wire tlbcsr_srch_wen;
wire tlbcsr_rd_wen;

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
wire [`CSR_TO_EXE_BUS_WD-1:0] csr_to_exe_bus;
wire [`CSR_TO_MEM_BUS_WD-1:0] csr_to_mem_bus;
wire [`EXE_TO_TLB_BUS_WD-1:0] exe_to_tlb_bus;
wire [`TLBSRH_TO_CSR_BUS_WD-1:0] tlbsrh_to_csr_bus;
wire [`MEM_TO_TLB_BUS_WD-1:0] mem_to_tlb_bus;
wire [`TLBRD_TO_CSR_BUS_WD-1:0] tlbrd_to_csr_bus;
wire [`TLB_TO_IF_BUS_WD - 1: 0] tlb_to_if_bus;
wire [`TLB_TO_IF_BUS_WD-1:0]  tlb_to_exe_bus;
wire [`IF_TO_TLB_BUS_WD-1:0]    if_to_tlb_bus;

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

wire es_TLBR, es_PIL, es_PIS, es_PME, es_PPI;


assign {    
    tlbcsr_srch_wen,
    s1_vppn,
    s1_asid,
    s1_va_bit12,
    invtlb_valid,
    invtlb_op } = exe_to_tlb_bus;

assign {
    tlbcsr_rd_wen,
    r_index,
    we,
    w_index,
    w_ps,
    w_ne,
    w_vppn,
    w_v0,
    w_d0,
    w_plv0,
    w_mat0,
    w_g0,
    w_ppn0,
    w_v1,
    w_d1,
    w_plv1,
    w_mat1,
    w_g1,
    w_ppn1,
    w_asid 
} = mem_to_tlb_bus;

assign {s0_vppn, s0_asid, s0_va_bit12} = if_to_tlb_bus;

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
    //to tlb
    .if_to_tlb_bus(if_to_tlb_bus),
    //from tlb
    .tlb_to_if_bus(tlb_to_if_bus),
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
    .invtlb_op_exc(invtlb_op_exc),
    .TLBR(es_TLBR),
    .PPI(es_PPI),
    .PIS(es_PIS),
    .PIL(es_PIL),
    .PME(es_PME),
    .es_pc(es_pc),
    .ds_to_fs_csr_bus(ds_to_fs_csr_bus),
    .ms_to_ds_exbus(ms_to_ds_exbus),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .csr_to_exe_bus (csr_to_exe_bus),
    .csr_to_mem_bus (csr_to_mem_bus),
    .tlbsrh_to_csr_bus (tlbsrh_to_csr_bus),
    .tlbrd_to_csr_bus (tlbrd_to_csr_bus)
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
    .invtlb_op_exc(invtlb_op_exc),
    .TLBR(es_TLBR),
    .PPI(es_PPI),
    .PIS(es_PIS),
    .PIL(es_PIL),
    .PME(es_PME),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    .es_to_ds_load_op(es_to_ds_load_op),
    .es_to_ds_result(es_to_ds_result),
    .data_sram_addr_ok(data_sram_addr_ok),

    // from csr
    .csr_to_exe_bus (csr_to_exe_bus),
    // to tlb
    .exe_to_tlb_bus (exe_to_tlb_bus),
    //from tlb
    .tlb_to_exe_bus (tlb_to_exe_bus),

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
    .cnt_value_h(cnt_value_h),
    .csr_to_mem_bus (csr_to_mem_bus),
    .mem_to_tlb_bus (mem_to_tlb_bus)
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

wire ne_to_csr;
wire [3:0] index_to_csr;
assign ne_to_csr = ~(s1_found);
assign index_to_csr = s1_index;


tlb #(.TLBNUM(16)) u_tlb (
    .clk         (clk     ),

    .s0_vppn     (s0_vppn    ),//i
    .s0_va_bit12 (s0_va_bit12),//i
    .s0_asid     (s0_asid    ),//i
    .s0_found    (s0_found   ),
    .s0_index    (s0_index   ),
    .s0_ppn      (s0_ppn     ),
    .s0_ps       (s0_ps      ),
    .s0_plv      (s0_plv     ),
    .s0_mat      (s0_mat     ),
    .s0_d        (s0_d       ),
    .s0_v        (s0_v       ),

    .s1_vppn     (s1_vppn    ),//i
    .s1_va_bit12 (s1_va_bit12),//i
    .s1_asid     (s1_asid    ),//i
    .s1_found    (s1_found   ),
    .s1_index    (s1_index   ),
    .s1_ppn      (s1_ppn     ),
    .s1_ps       (s1_ps      ),
    .s1_plv      (s1_plv     ),
    .s1_mat      (s1_mat     ),
    .s1_d        (s1_d       ),
    .s1_v        (s1_v       ),

    .invtlb_valid(invtlb_valid),
    .invtlb_op   (invtlb_op),

    .we          (we         ),//i
    .w_index     (w_index    ),//i
    .w_e         (~w_ne        ),//i
    .w_vppn      (w_vppn     ),//i
    .w_ps        (w_ps       ),//i
    .w_asid      (w_asid     ),//i
    .w_g         (w_g0 & w_g1 ),//i
    .w_ppn0      (w_ppn0     ),//i
    .w_plv0      (w_plv0     ),//i
    .w_mat0      (w_mat0     ),//i
    .w_d0        (w_d0       ),//i
    .w_v0        (w_v0       ),//i
    .w_ppn1      (w_ppn1     ),//i
    .w_plv1      (w_plv1     ),//i
    .w_mat1      (w_mat1     ),//i
    .w_d1        (w_d1       ),//i
    .w_v1        (w_v1       ),//i

    .r_index     (r_index    ),//i
    .r_e         (r_e        ),
    .r_vppn      (r_vppn     ),
    .r_ps        (r_ps       ),
    .r_asid      (r_asid     ),
    .r_g         (r_g        ),
    .r_ppn0      (r_ppn0     ),
    .r_plv0      (r_plv0     ),
    .r_mat0      (r_mat0     ),
    .r_d0        (r_d0       ),
    .r_v0        (r_v0       ),
    .r_ppn1      (r_ppn1     ),
    .r_plv1      (r_plv1     ),
    .r_mat1      (r_mat1     ),
    .r_d1        (r_d1       ),
    .r_v1        (r_v1       )
);
assign tlbsrh_to_csr_bus = { tlbcsr_srch_wen, ne_to_csr, index_to_csr};
assign tlbrd_to_csr_bus = {tlbcsr_rd_wen, r_e, r_vppn, r_ps, r_asid, r_g, r_ppn0,r_plv0,
                           r_mat0, r_d0, r_v0, r_ppn1, r_plv1,r_mat1, 
                           r_d1, r_v1};
assign tlb_to_if_bus = {s0_found, s0_index, s0_ppn, s0_ps, s0_plv, s0_mat, s0_d, s0_v};
assign tlb_to_exe_bus = {s1_found, s1_index, s1_ppn, s1_ps, s1_plv, s1_mat, s1_d, s1_v};

endmodule
