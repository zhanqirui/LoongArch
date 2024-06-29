`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    // to ds
    output [ 4:0] ms_to_ds_dest,
    output [31:0] ms_to_ds_result,
    output        ms_to_ds_is_exc,
    output [`MS_TO_DS_EXBUS_WD - 1 : 0] ms_to_ds_exbus,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // from cnt
    input [31:0]  cnt_value_h,
    input [31:0]  cnt_value_l,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    
    //from data-sram
    input                          data_sram_data_ok,
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
reg         ms_bus_valid;
wire        ms_ready_go;
reg         is_ms_reflush;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [4:0]  ms_load_op;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire ms_st_or_ld;
wire need_cnt_l;
wire need_cnt_h;
wire need_cnt_id;

wire [13:0] ms_csr_num;
wire [1:0]  ms_csr_we;
wire [31:0] rkd_value;
wire ms_res_from_csr;
wire [31:0] ms_csr_rdata;
wire        ms_is_exc;
wire [31:0] ms_rj_value;
wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire  [31:0] ms_pc_to_era;
wire  [31:0] ms_pc_to_badv;
wire  ms_Addr_exc;
wire  [5:0] ms_Ecode;
wire  [8:0] ms_EsubCode;

assign ms_to_ds_dest = ms_dest & {5{ms_valid}};

assign {
        ms_st_or_ld,
        ms_load_op,       //75:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc,            //31:0
        ms_res_from_csr,
        ms_csr_rdata,
        ms_is_exc,
        need_cnt_l,
        need_cnt_h,
        need_cnt_id,
        ms_pc_to_era,
        ms_pc_to_badv,
        ms_Addr_exc,
        ms_Ecode,
        ms_EsubCode
       } = es_to_ms_bus_r;

assign ms_to_ds_exbus = {
                        ms_pc_to_era,
                        ms_pc_to_badv,
                        ms_Addr_exc,
                        ms_Ecode,
                        ms_EsubCode          
};

assign ms_to_ds_is_exc = ms_is_exc && ms_valid;

//71
assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc,            //31:0
                       ms_is_exc
                      };

assign ms_to_ds_result = ms_final_result;

assign ms_ready_go    = ~ms_st_or_ld | data_sram_data_ok | ms_bus_valid | ms_Addr_exc;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go ;
//由于ms_valid只有在addr_ok来临的下一个周期才会变成1，其余时间都是0，但是在我的data_ok为1时，ms_ready_go才会为1，由于addr_ok和data_ok不一定正好只错开一个周期，
//所以会导致数据一直不能传递到ws阶段
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end
end


always@(posedge clk)
begin
    if(reset)
        ms_bus_valid <= 0;
    else if(is_ms_reflush && data_sram_data_ok && (~ms_to_ws_valid || ~ws_allowin))
        ms_bus_valid <= 1;
    else if(ms_to_ws_valid && ws_allowin)
        ms_bus_valid <= 0;

end

always@(posedge clk)begin
    if(reset)begin
        is_ms_reflush <= 0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        //?总线什么时候储存有有效值？ --> 上面这个条件有效，但是（ms_to_ws_valid无效或者ws_allowin无效）并且data_ok有效！
        is_ms_reflush  <= 1;
    end
    else if(ms_to_ws_valid && ws_allowin)
        is_ms_reflush <= 0;
end

always@(posedge clk)begin
    if(reset)begin
        es_to_ms_bus_r <= 0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        //?总线什么时候储存有有效值？ --> 上面这个条件有效，但是（ms_to_ws_valid无效或者ws_allowin无效）并且data_ok有效！
        es_to_ms_bus_r  = es_to_ms_bus;
    end

end
//! fuck you !!!!!
wire [1:0] alu_1_0;
wire [7:0] ld_b_result;
wire [15:0] ld_h_result;
assign alu_1_0 = ms_alu_result[1:0];
assign ld_b_result = alu_1_0 == 2'b00 ? data_sram_rdata[7:0] :
                     alu_1_0 == 2'b01 ? data_sram_rdata[15:8]:
                     alu_1_0 == 2'b10 ? data_sram_rdata[23:16]:
                     data_sram_rdata[31:24];
assign ld_h_result = alu_1_0[1] == 1'b1 ? data_sram_rdata[31:16] : data_sram_rdata[15:0];

assign mem_result   =  ({32{ms_load_op[0]}} & data_sram_rdata) 
                    |  ({32{ms_load_op[1]}} & {{24{ld_b_result[7]}},ld_b_result})
                    |  ({32{ms_load_op[2]}} & {{16{ld_h_result[15]}},ld_h_result})
                    |  ({32{ms_load_op[3]}} & {{24{1'b0}},ld_b_result})
                    |  ({32{ms_load_op[4]}} & {{16{1'b0}},ld_h_result});


assign ms_final_result = ms_res_from_mem ? mem_result   : 
                         ms_res_from_csr ? ms_csr_rdata : 
                         need_cnt_l      ? cnt_value_l  :
                         need_cnt_h      ? cnt_value_h  :
                         ms_alu_result;

endmodule
