`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    output        es_to_ds_load_op,
    //to ds
    output [ 4:0] es_to_ds_dest,
    output [31:0] es_to_ds_result,
    //TODO 改CPUtop
    output es_to_ds_is_exc,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface(write)
    output        data_sram_en   ,
    output [ 3:0] data_sram_we   ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata
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
wire        es_is_exc;

wire        dst_is_r1;
wire        gr_we;
wire        es_mem_we;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] es_pc;


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
        es_is_exc
       } = ds_to_es_bus_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;
wire [31:0] st_data;
wire [1:0] alu_1_0;

assign es_to_ds_load_op=es_load_op[0] | es_load_op[1] | es_load_op[2] | es_load_op[3] | es_load_op[4];

assign es_to_ds_dest = dest & {5{es_valid}}; 

assign es_to_ds_result = res_from_csr == 1'b0 ? alu_result : csr_rdata;

assign es_to_ds_is_exc = es_is_exc & es_valid;

assign es_to_ms_bus = {
                       es_load_op,    //75:71 5
                       res_from_mem,  //70:70 1
                       gr_we       ,  //69:69 1
                       dest        ,  //68:64 5
                       alu_result  ,  //63:32 32
                       es_pc,         //31:0  32
                       res_from_csr,
                       csr_rdata,
                       es_is_exc
                      };

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

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
assign data_sram_en    = 1'b1;
// TODO优化这段逻辑
assign data_sram_we    = es_mem_we && es_valid ?
                        (es_st_op[2] ? 
                        (   alu_1_0 == 2'b00 ? 4'b0001 :
                            alu_1_0 == 2'b01 ? 4'b0010 :
                            alu_1_0 == 2'b10 ? 4'b0100 : 4'b1000): 
                        es_st_op[1] ?
                        (   alu_1_0[1] ? 4'b1100 : 4'b0011) : 4'b1111) : 4'b0000;


assign data_sram_addr  = alu_result;
assign data_sram_wdata = st_data;


endmodule
