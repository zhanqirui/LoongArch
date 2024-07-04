`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,

    input                          inst_sram_addr_ok,
    input                          inst_sram_data_ok,
    output                         inst_sram_wr,

    //csr_bus
    input [`CSR_BUS_WD       -1:0] ds_to_fs_csr_bus,
    //from tlb
    input [`TLB_TO_IF_BUS_WD-1:0] tlb_to_if_bus,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    //to tlb
    output [`IF_TO_TLB_BUS_WD-1:0] if_to_tlb_bus,
    // inst sram interface
    output        inst_sram_req   , //对应en
    output [1:0]  inst_sram_size,
    output [ 3:0] inst_sram_wstrb  ,
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
reg mid_handshake;
wire   br_stall;
wire         br_taken;
wire [ 31:0] br_target;
reg  [31:0] inst_reg;
reg  inst_reg_valid;
reg  ab_inst_valid;
// reg [31:0] fs_inst;
//!CSR
wire is_exc;
wire ms_is_exc;
// !在is_exc和ms_is_exc之间时不发送req
reg  is_during_exc;
wire is_ret;
wire [31:0] csr_era;
wire [31:0] csr_eentry;

wire addr_valid;
wire csr_addr_valid, br_addr_valid, ret_addr_valid, TLBR_addr_valid;

assign {br_stall, br_taken, br_target} = br_bus;


//拆解CSR传递过来的数据
wire [31:0] tlbenrty_out;
wire [9:0] asid_out;
wire crmd_da;
wire crmd_pg;
wire [2:0] dmw0_vseg, dmw1_vseg, dmw0_pseg, dmw1_pseg;
wire dmw0_plv0, dmw0_plv3, dmw1_plv0, dmw1_plv3;
wire dmw0_mat,dmw1_mat;
wire [1:0] cur_plv;
wire is_TLBR;
wire crmd_dataF;
assign {is_exc, ms_is_exc, is_ret, csr_era, csr_eentry, tlbenrty_out, asid_out, crmd_da, crmd_pg,
     dmw0_vseg, dmw1_vseg, dmw0_pseg, dmw1_pseg, dmw0_plv0, dmw1_plv0, dmw0_plv3, dmw1_plv3, 
     cur_plv, dmw0_mat, dmw1_mat, crmd_dataF, is_TLBR} = ds_to_fs_csr_bus;

//拆解TLB传过来的数据
wire s0_found;
wire [3:0] s0_index;
wire [19:0] s0_ppn;
wire [5:0] s0_ps;
wire [1:0] s0_mat, s0_plv;
wire s0_d, s0_v;
assign {s0_found, s0_index, s0_ppn, s0_ps, s0_plv, s0_mat, s0_d, s0_v} = tlb_to_if_bus;


//TLB转换
wire [18:0] s0_vppn = nextpc[31:13];
wire s0_va_12bit = nextpc[12];
assign if_to_tlb_bus = {s0_vppn, asid_out, s0_va_12bit};

//直接映射地址模式
wire [31:0] dmw_pc;
wire [ 1:0] dmw_select;  //2'b01表示命中DMW0 2'b10表示命中DMW1 

assign dmw_select[0] = dmw0_vseg == nextpc[31:29] & (dmw0_plv3 == 1'b1 & cur_plv == 2'b11 | dmw0_plv0 == 1'b1 & cur_plv == 2'b0);//只有对应等级的plv才能使用对应的窗口,虚地址的高3位要和窗口的虚地址对应
assign dmw_select[1] = dmw1_vseg == nextpc[31:29] & (dmw1_plv3 == 1'b1 & cur_plv == 2'b11 | dmw1_plv0 == 1'b1 & cur_plv == 2'b0);

// assign dmw_pc = {32{dmw_select[0]}} & {dmw0_pseg, nextpc[28:0]} | {32{dmw_select[1]}} & {dmw1_pseg,nextpc[28:0]};
assign dmw_pc = dmw_select[0] ? {dmw0_pseg, nextpc[28:0]} :
                dmw_select[1] ? {dmw1_pseg, nextpc[28:0]} : 32'b0;

//TLB映射地址模式
wire [31:0] tlb_pc;
assign tlb_pc = s0_ps == 6'h21 ? {s0_ppn[19:9], nextpc[20:0]} : {s0_ppn[19:0], nextpc[11:0]};

//TLB相关例外
wire TLBR, PIF, PPI;
reg fs_TLBR, fs_PIF, fs_PPI;

assign TLBR = crmd_da == 1'b0 & crmd_pg == 1'b1 & dmw_select == 2'b0 & ~s0_found;
assign PIF = crmd_da == 1'b0 & crmd_pg == 1'b1 & dmw_select == 2'b0 & s0_found & ~s0_v;
assign PPI = crmd_da == 1'b0 & crmd_pg == 1'b1 & dmw_select == 2'b0 & s0_found & s0_v & (cur_plv > s0_plv);


wire [31:0] fs_inst;
reg  [31:0] fs_pc;
//! reg  rsc_but_stall;
assign fs_inst = inst_reg;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc,
                       fs_TLBR,
                       fs_PIF,
                       fs_PPI   };
//? assign fs_ready_go = ~br_taken && ~is_ret && inst_sram_data_ok;
//? assign fs_inst = cpu_inst_rdata;


always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        // if taken is valid, to skip the delay slot instruction, next_pc should be the instruction after the jump inst
        fs_pc <= nextpc;
    end
end


wire   pre_if_ready_go;
reg    nextpc_wait;



always@(posedge clk)begin
    if(reset)
        nextpc_wait = 0;
    else if(addr_valid && (inst_sram_addr_ok == 1'b0 || inst_sram_req == 1'b0))
        nextpc_wait = 1'b1;
    else if(nextpc_wait == 1'b1 && inst_sram_addr_ok && inst_sram_req)
        nextpc_wait = 1'b0;
end

//! always@(posedge clk)
//     if(reset)
//         rsc_but_stall = 1'b0;
//     else if(pre_if_ready_go & ~ fs_allowin)
//         rsc_but_stall = 1'b1;
//     else if (rsc_but_stall & fs_allowin)
//!         rsc_but_stall = 1'b0;

assign addr_valid = TLBR_addr_valid | csr_addr_valid | br_addr_valid | ret_addr_valid ;

assign csr_addr_valid = ms_is_exc && csr_eentry[1:0] == 2'b00;
assign TLBR_addr_valid = is_TLBR && tlbenrty_out[1:0] == 2'b00;
assign br_addr_valid = br_taken && br_target[1:0] == 2'b00;
assign ret_addr_valid = is_ret && csr_era[1:0] == 2'b00;
// pre-IF stage
// because after sending fs_pc to ds, the seq_pc = fs_pc + 4 immediately
// Actually, the seq_pc is just a delay slot instruction
// if we use inst pc, here need to -4, it's more troublesome
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       =  is_TLBR ? tlbenrty_out:
                       (ms_is_exc && csr_eentry[1:0] == 2'b00) ? csr_eentry :
                       (is_ret && csr_era[1:0] == 2'b00) ? csr_era :
                       nextpc_wait ? nextpc :
                       (br_taken && br_target[1:0] == 2'b00) ? br_target : 
                       seq_pc; 

assign to_fs_valid  = ~reset & pre_if_ready_go;
assign pre_if_ready_go = (inst_sram_req & inst_sram_addr_ok | TLBR |  PIF |  PPI ) & ~is_exc;
// if taken is valid and if stage is block, get the instruction after the jump inst



// IF stage
// assign fs_ready_go    = (~br_taken && ~is_ret && inst_sram_data_ok && ~ab_inst_valid) || inst_reg_valid;   // if taken is valid, if stage block
assign fs_ready_go = (inst_sram_data_ok & ~br_taken) | inst_reg_valid | fs_TLBR | fs_PIF | fs_PPI;
assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin) || is_exc;    // 可接收数据（不阻塞
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
        fs_TLBR <= 1'b0;
        fs_PIF <= 1'b0;
        fs_PPI <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    // 数据有效
        if(to_fs_valid)begin
            fs_TLBR <= TLBR;
            fs_PIF <= PIF;
            fs_PPI <= PPI;
        end

    end
    // else if(ms_is_exc)
    //     fs_valid <= 1'b0;
    

end
	
assign inst_sram_wstrb   = 4'h0;
assign inst_sram_wr = 1'b0; //表示读取inst_sram的值
assign inst_sram_size = 2'h2;//表示读取4位
assign inst_sram_addr = crmd_da == 1'b1 & crmd_pg == 1'b0 ? nextpc :
                        dmw_select != 2'b0 ? dmw_pc :
                        tlb_pc;
assign inst_sram_wdata = 32'b0;
// assign inst_sram_req    = ~rsc_but_stall & (~br_stall | br_taken); //发出请求((is_ret | br_taken))
assign inst_sram_req    = fs_allowin & ~br_stall & ~mid_handshake & ~is_during_exc & ~TLBR & ~PIF & ~PPI; //发出请求((is_ret | br_taken))
//assign inst_sram_req = to_fs_valid && (fs_allowin || br_taken || is_ret) && pre_if_ready_go

//inst_reg
always@(inst_sram_data_ok, inst_sram_rdata)
    if(inst_sram_data_ok)
        inst_reg <= inst_sram_rdata;

always@(posedge clk)
    if(reset)
        inst_reg_valid <= 0;
    else if(ms_is_exc)
        inst_reg_valid <= 0;
    // else if(rsc_but_stall & inst_sram_data_ok & ~fs_allowin)
    //     inst_reg_valid <= 1;
    // else if(fs_allowin)
    //     inst_reg_valid <= 0;
    else if(fs_valid && inst_sram_data_ok && ~ds_allowin)
        inst_reg_valid <= 1;
    else if(ds_allowin)
        inst_reg_valid <= 0;

// assign is_during_exc = reset ? 1'b0 :
//                        is_exc ? 1'b1 :
//                        ms_is_exc ? 1'b0 :
//                        is_during_exc;
always @(posedge clk or posedge reset) begin
    if (reset)
        is_during_exc <= 1'b0;
    else if (is_exc)
        is_during_exc <= 1'b1;
    else if (ms_is_exc)
        is_during_exc <= 1'b0;
end


// ab_inst_reg
always@(posedge clk)
    if(reset)
        ab_inst_valid <= 1'b0;
    else if(is_exc && (to_fs_valid || (fs_allowin == 1'b0 && fs_ready_go == 1'b0)))
        ab_inst_valid <= 1'b1;
    else if(inst_sram_data_ok)
        ab_inst_valid <= 1'b0;


//响应——握手信号
//开始于第一次握手（地址）
//结束于第二次握手（数据）
always @(posedge clk) begin
    if (reset)
        mid_handshake <= 1'b0;
    else if (inst_sram_data_ok)
        mid_handshake <= 1'b0;
    else if (inst_sram_req && inst_sram_addr_ok)
        mid_handshake <= 1'b1;
end



endmodule
