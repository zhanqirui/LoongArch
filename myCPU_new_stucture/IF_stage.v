`include "DEFINE.vh"

module IF_stage(
    input clk, reset,
    
    input ds_allow_in,

    input [`BR_TO_FS_WD - 1 : 0] br_bus,

    input [31:0] inst_sram_rdata,

    input IF_fresh,

    output  inst_sram_en,
    output [3:0] inst_sram_we,

    output [31:0] inst_sram_addr, inst_sram_wdata,
    //传递给ds的数据总线,以及握手信号
    output [`FS_TO_DS_WD - 1 : 0] fs_to_ds_bus,
    output wire fs_to_ds_valid
);

wire [31:0] seq_pc;
//解决控制冒险所需要的信号
wire [31:0] br_target;
wire br_taken;

reg pc_IF;

//为了更好的完成流水线的阻塞任务，此处新增握手信号

//ds_allow_in表示下一级流水线是否允许当前级流水线传递数据

//为了简化格式，新增总线！使用宏定义标注总线的大小！

wire fs_ready_go, pre_to_fs_valid, fs_allow_in;
reg fs_valid;

assign {br_taken, br_target} = br_bus;

//pre-IF阶段
//由于inst_sram是时序逻辑，所以想要fs_to_ds_bus中的pc与inst对应，就应该传递nextpc给inst_sram
assign pre_to_fs_valid = ~reset;
assign seq_pc       = pc_IF + 32'h4;
assign nextpc       = br_taken ? br_target : seq_pc;



//fs_ready_go表示数据是否准备好了
assign fs_ready_go = 1'b1;
//fs_allow_in 表示fs是否接收数据：fs数据无效或者数据有效并且准备好并且下一级流水线可以接收数据,//!这是要告诉上一级流水线的信息
assign fs_allow_in = !fs_valid || fs_ready_go && ds_allow_in;
//fs_to_ds_valid表示，传递给下一级流水线的数据是否有效//!这是要告诉下一级流水线的信号
assign fs_to_ds_valid = fs_valid && fs_ready_go;

//按理来说只要rst信号无效，就要一直读地址，所以valid信号一直有效
always@(posedge clk)
    if(!reset)
        fs_valid <= 1'b0;
    else if(fs_allow_in)
        fs_valid <= pre_to_fs_valid;

always @(posedge clk) begin
    if (!reset) begin
        pc_IF <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else
        if(pre_to_fs_valid && fs_allow_in)  pc_IF <= nextpc;
end

assign fs_to_ds_bus = IF_fresh ? {pc_IF, inst_sram_rdata} : {pc_IF, 32'b0};

assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign inst_sram_en = 1'b1;



endmodule