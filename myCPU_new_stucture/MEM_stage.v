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
    //TODO 改CPUtop
    output        ms_to_ds_is_exc,
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
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [4:0]  ms_load_op;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire need_cnt_l;
wire need_cnt_h;
wire need_cnt_id;

wire ms_res_from_csr;
wire [31:0] ms_csr_rdata;
wire        ms_is_exc;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ds_dest = ms_dest & {5{ms_valid}};

assign {
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
        need_cnt_id
       } = es_to_ms_bus_r;

assign ms_to_ds_is_exc = ms_is_exc && ms_valid;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc,            //31:0
                       ms_is_exc
                      };

assign ms_to_ds_result = ms_final_result;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
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
