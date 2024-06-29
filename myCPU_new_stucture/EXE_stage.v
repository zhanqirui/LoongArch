`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output   wire                  es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    output wire   es_to_ds_load_op,
    //to ds
    output wire[ 4:0] es_to_ds_dest,
    output wire[31:0] es_to_ds_result,
    output wire[31:0] es_pc,
    output wire   ALE_exc,

    output es_to_ds_is_exc,
    //to ms
    output wire                    es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,

    input              data_sram_addr_ok,
    input              data_sram_data_ok,
    // data sram interface(write)
    output wire        data_sram_req   ,
    output wire        data_sram_wr    ,
    output wire [ 1:0] data_sram_size  ,
    output wire [ 3:0] data_sram_wstrb   ,
    output wire [31:0] data_sram_addr ,
    output wire [31:0] data_sram_wdata
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [27:0] alu_op      ;
wire [4:0]  es_load_op;
wire [2:0]  es_st_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem;

wire        res_from_csr;
wire [31:0] csr_rdata;
wire        is_exc;
wire        es_is_exc;

wire        need_cnt_l;
wire        need_cnt_h;
wire       need_cnt_id;

wire        dst_is_r1;
wire        gr_we;
wire        es_mem_we;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire ld_w_ale, ld_h_ale, ld_hu_ale, st_h_ale, st_w_ale;
wire ld_ale, st_ale;
wire es_gr_we;
wire [13:0] es_csr_num;
wire [1:0]  es_csr_we;

wire  [31:0] es_pc_to_era;
wire  [31:0] pc_to_era;
wire  [31:0] es_pc_to_badv;
wire  [31:0] pc_to_badv;
wire  Addr_exc;
wire  es_Addr_exc;
wire  [5:0] es_Ecode;
wire  [5:0] Ecode;
wire  [8:0] es_EsubCode;
wire  [8:0] EsubCode;

assign {alu_op,
        es_load_op,
        es_st_op,
        src1_is_pc,
        src2_is_imm,
        src2_is_4,
        gr_we,
        es_mem_we,
        dest,
        imm,
        rj_value,
        rkd_value,
        es_pc,
        res_from_mem,
        res_from_csr,
        csr_rdata,
        is_exc,
        need_cnt_l,
        need_cnt_h,
        need_cnt_id,
        pc_to_era,
        pc_to_badv,
        Addr_exc,
        Ecode,
        EsubCode
       } = ds_to_es_bus_r;
       



wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] st_data;
wire [1:0] alu_1_0;

wire st_inst;
wire st_or_ld;

assign es_pc_to_era = ALE_exc ? es_pc : pc_to_era;
assign es_pc_to_badv = ALE_exc ? alu_result : pc_to_badv;
assign es_Ecode = ALE_exc ? 6'h9 : Ecode;
assign es_EsubCode = 9'h0;
assign es_is_exc = (is_exc | ALE_exc) & es_valid;
assign es_Addr_exc = ALE_exc ? es_valid : Addr_exc;

assign st_or_ld = st_inst | es_to_ds_load_op;
assign st_inst = es_st_op[0] | es_st_op[1] | es_st_op[2];

assign es_to_ds_load_op = es_load_op[0] | es_load_op[1] | es_load_op[2] | es_load_op[3] | es_load_op[4];


assign es_to_ds_dest = dest & {5{es_valid}}; 

assign es_to_ds_result = (res_from_csr == 1'b0) ? alu_result : csr_rdata;

assign es_to_ds_is_exc = es_is_exc & es_valid;

assign es_gr_we = gr_we & ~ALE_exc & es_valid;
//1+5   6+1+1+5   13+64+1           78+36=  114       32+4
assign es_to_ms_bus = {
                       st_or_ld,      // 1
                       es_load_op,    //75:71 5
                       res_from_mem,  //70:70 1
                       es_gr_we       ,  //69:69 1
                       dest        ,  //68:64 5
                       alu_result  ,  //63:32 32
                       es_pc,         //31:0  32
                       res_from_csr,
                       csr_rdata,
                       es_is_exc,
                       need_cnt_l,
                       need_cnt_h,
                       need_cnt_id,
                       es_pc_to_era,
                       es_pc_to_badv,
                       es_Addr_exc,
                       es_Ecode,
                       es_EsubCode
                      };

assign alu_src1 = src1_is_pc  ? es_pc  : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );


assign st_data = es_st_op[2] ? {4{rkd_value[7:0]}} :
                 es_st_op[1] ? {2{rkd_value[15:0]}}:
                 rkd_value;
assign alu_1_0 = alu_result[1:0];

assign ld_w_ale = es_valid & es_load_op[0] & (alu_1_0 != 2'b00);
assign ld_h_ale = es_valid & es_load_op[2] & (alu_1_0[0] != 1'b0);
assign ld_hu_ale = es_valid & es_load_op[4] & (alu_1_0[0] != 1'b0);

assign st_w_ale = es_valid & es_st_op[0] & (alu_1_0 != 2'b00);
assign st_h_ale = es_valid & es_st_op[1] & (alu_1_0[0] != 1'b0);

assign ld_ale = ld_w_ale | ld_h_ale | ld_hu_ale;
assign st_ale = st_w_ale | st_h_ale;
assign ALE_exc = (ld_ale | st_ale) & es_valid;

assign es_ready_go    = ~st_or_ld | (data_sram_req & data_sram_addr_ok | ALE_exc);
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
end

always@(posedge clk)
    if(reset)   
        ds_to_es_bus_r <= 0;
    else if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end

reg exe_mid_handshake;
// assign data_sram_en    = ~ld_ale & es_to_ds_load_op ? 1'b1 : 1'b0;
assign data_sram_req = st_or_ld & ~exe_mid_handshake;   
// assign data_sram_req = st_or_ld;
assign data_sram_wr = es_mem_we;
// TODO优化这段逻辑
assign data_sram_wstrb  = ~st_ale && es_mem_we && es_valid ?
                        (es_st_op[2] ? 
                        (   alu_1_0 == 2'b00 ? 4'b0001 :
                            alu_1_0 == 2'b01 ? 4'b0010 :
                            alu_1_0 == 2'b10 ? 4'b0100 : 4'b1000): 
                        es_st_op[1] ?
                        (   alu_1_0[1] ? 4'b1100 : 4'b0011) : 4'b1111) : 4'b0000;
assign data_sram_size = es_load_op[0] || es_st_op[0] ? 2'b10 :
                        es_load_op[2] || es_load_op[1] || es_st_op[1] ? 2'b01 :
                        2'b0;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = st_data;



always @(posedge clk) begin
    if (reset)
        exe_mid_handshake <= 1'b0;
    else if (data_sram_data_ok & ~(data_sram_addr_ok & data_sram_req))
        exe_mid_handshake <= 1'b0;
    else if (data_sram_req && data_sram_addr_ok)
        exe_mid_handshake <= 1'b1;
end

// assign load_op[0] = inst_ld_w;
// assign load_op[1] = inst_ld_b;
// assign load_op[2] = inst_ld_h;
// assign load_op[3] = inst_ld_bu;
// assign load_op[4] = inst_ld_hu;
// assign st_op[0] = inst_st_w;
// assign st_op[1] = inst_st_h;
// assign st_op[2] = inst_st_b;



endmodule
