`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //csr_bus
    input [`CSR_BUS_WD       -1:0] ds_to_fs_csr_bus,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_we  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
//!CSR
wire is_exc;
wire is_ret;
wire [31:0] csr_era;
wire [31:0] csr_eentry;

assign {br_taken, br_target} = br_bus;
assign {is_exc, is_ret, csr_era, csr_eentry} = ds_to_fs_csr_bus;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
wire inst_ertn;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };

// pre-IF stage
// because after sending fs_pc to ds, the seq_pc = fs_pc + 4 immediately
// Actually, the seq_pc is just a delay slot instruction
// if we use inst pc, here need to -4, it's more troublesome
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = (is_exc && csr_eentry[1:0] == 2'b00) ? csr_eentry :
                      (br_taken && br_target[1:0] == 2'b00) ? br_target : 
                      (is_ret && csr_era[1:0] == 2'b00) ? csr_era :
                    //    inst_ertn ? fs_pc :
                      seq_pc; 
assign inst_ertn = fs_inst == 32'h06483800;
// IF stage
assign fs_ready_go    = ~br_taken && ~is_ret;   // if taken is valid, if stage block

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && (fs_allowin || br_taken || is_ret)) begin
        // if taken is valid, to skip the delay slot instruction, next_pc should be the instruction after the jump inst
        fs_pc <= nextpc;
    end
end

assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin);     // 可接收数据（不阻塞
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    // 数据有效
    end
end

wire   br_stall;
wire   pre_if_ready_go;
assign {br_stall, br_taken, br_target} = br_bus;
// pre-IF stage
assign to_fs_valid  = ~reset && pre_if_ready_go;
assign pre_if_ready_go = ~br_stall;
// if taken is valid and if stage is block, get the instruction after the jump inst
	
assign inst_sram_we   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst_sram_en    = to_fs_valid && (fs_allowin || br_taken || is_ret) && pre_if_ready_go;

assign fs_inst         = inst_sram_rdata;

endmodule
