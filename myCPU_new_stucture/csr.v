`define N 12
`define SUB_N 20
`define TLBELEN 4
`define PALEN 32
`include "mycpu.h"
module csr(
    //!需要新增接口: pc, is_exc, is_return?
    // pc:异常发生时，pc写入ERA中
    //is_exc:记录异常是否发生，一旦异常发生，将保存CRMD位域的旧值，调整PLV等级，将IE域置0
    //! 新增接口era, eentry

    //! 新增接口Ecode EsubCode
    input clk,reset,

    input [13:0] raddr,
    input [31:0] rj_value,

    output [31:0] tlbenrty_out,
    output [9:0] asid_out,
    output crmd_da,
    output crmd_pg,
    output [2:0] dmw0_vseg, dmw1_vseg, dmw0_pseg, dmw1_pseg,
    output dmw0_plv0, dmw0_plv3, dmw1_plv0, dmw1_plv3,
    output dmw0_mat,dmw1_mat,
    output [1:0] cur_plv,
    output crmd_dataF,

    output[31:0] rdata,
    output reg[31:0] ERA,
    output reg[31:0] EENTRY,
    output need_interrupt,
    output [`CSR_TO_EXE_BUS_WD-1:0] csr_to_exe_bus,
    output [`CSR_TO_MEM_BUS_WD-1:0] csr_to_mem_bus,

    input [`TLBSRH_TO_CSR_BUS_WD-1:0] tlbsrh_to_csr_bus,
    input [`TLBRD_TO_CSR_BUS_WD-1:0] tlbrd_to_csr_bus,

    input [1:0]  we,
    input [13:0] waddr,
    input [31:0] wdata,
    input [31:0] pc_to_era,
    input [31:0] pc_to_badv,
    input is_exc, is_ret, Addr_exc,TLBR,is_TLB_exc,
    input [5:0] Ecode,
    input [8:0] EsubCode
    
);

reg [31:0] CRMD, PRMD, ESTAT, SAVE1, SAVE2, SAVE3, SAVE0;
reg [31:0] ECFG, BADV, TID, TCFG, TVAL, TICLR;
reg [31:0] TLBIDX, TLBEHI, TLBELO0, TLBELO1, ASID, TLBRENTRY;
reg [31:0] DMW0, DMW1;

reg is_last_exc;

always@(posedge clk)
    if(reset)
        is_last_exc <= 1'b0;
    else
        is_last_exc <= is_exc;

reg  TCFG_En;
reg TCFG_Periodic;
reg [`N - 3 : 0] TCFG_InitVal;

wire [`N - 1: 0] TVAL_TimeVal;
reg  last_is_TVAL_zero;
reg is_clr;
wire is_TVAL_zero;

wire TICLR_CLR;

wire [1:0] ESTAT_IS_1_0;
wire [7:0] ESTAT_IS_9_2;
wire ESTAT_IS_11;
reg IS11;
wire ESTAT_IS_12;

wire [12:0] LIE;
wire [12:0] IS;

wire [12:0] int_vec;

wire [3:0] r_index;
wire [5:0] r_ps;
wire r_ne;
wire [18:0] r_vppn;
wire r_v0,r_d0, r_v1, r_d1, r_g0, r_g1;
wire [1:0] r_plv0, r_mat0, r_plv1, r_mat1;
wire [19:0] r_ppn0, r_ppn1;

wire [9:0] r_asid;

wire tlbcsr_srch_wen, tlbcsr_rd_wen;
wire ne_in;
wire [3:0]index_in;
wire w_e, w_g, w_d0, w_v0, w_d1, w_v1;
wire [5:0] w_ps;
wire [18:0] w_vppn;
wire [9:0] w_asid;
wire [1:0] w_plv0, w_plv1, w_mat0, w_mat1;
wire [19:0] w_ppn0, w_ppn1;

assign {tlbcsr_srch_wen, ne_in, index_in} = tlbsrh_to_csr_bus;
assign {tlbcsr_rd_wen, w_e, w_vppn, w_ps, w_asid, w_g, w_ppn0,w_plv0,
                           w_mat0, w_d0, w_v0, w_ppn1, w_plv1,w_mat1, 
                           w_d1, w_v1} = tlbrd_to_csr_bus;


assign r_index = TLBIDX[3:0];
assign r_ps = TLBIDX[29:24];
assign r_ne = TLBIDX[31] & ~(ESTAT[26:21] == 6'h3f);

assign r_vppn = TLBEHI[31:13];

assign r_v0 = TLBELO0[0];
assign r_d0 = TLBELO0[1];
assign r_plv0 = TLBELO0[3:2];
assign r_mat0 = TLBELO0[5:4];
assign r_g0 = TLBELO0[6];
assign r_ppn0 = TLBELO0[27:8];

assign r_v1 = TLBELO1[0];
assign r_d1 = TLBELO1[1];
assign r_plv1 = TLBELO1[3:2];
assign r_mat1 = TLBELO1[5:4];
assign r_g1 = TLBELO1[6];
assign r_ppn1 = TLBELO1[27:8];

assign r_asid = ASID[9:0];


assign csr_to_exe_bus = {
                        r_vppn,
                        r_asid,
                        //2+12+4+2=20
                        crmd_da,
                        crmd_pg,
                        dmw0_vseg,
                        dmw1_vseg,
                        dmw0_pseg,
                        dmw1_pseg,
                        dmw0_plv0,
                        dmw1_plv0,
                        dmw0_plv3,
                        dmw1_plv3,
                        cur_plv
};

assign csr_to_mem_bus = {
                        r_index,
                        r_ps,
                        r_ne,
                        r_vppn,
                        r_v0,
                        r_d0,
                        r_plv0,
                        r_mat0,
                        r_g0,
                        r_ppn0,
                        r_v1,
                        r_d1,
                        r_plv1,
                        r_mat1,
                        r_g1,
                        r_ppn1,
                        r_asid 
};

//给新增信号赋值
assign tlbenrty_out = TLBRENTRY;
assign asid_out = ASID[9:0];
assign crmd_da = CRMD[3];
assign crmd_pg = CRMD[4];
assign dmw0_vseg = DMW0[31:29];
assign dmw1_vseg = DMW1[31:29];
assign dmw0_pseg = DMW0[27:25];
assign dmw1_pseg = DMW1[27:25];
assign dmw0_plv0 = DMW0[0];
assign dmw1_plv0 = DMW1[0];
assign dmw0_plv3 = DMW0[3];
assign dmw1_plv3 = DMW1[3];
assign dmw0_mat  = DMW0[4];
assign dmw1_mat  = DMW1[4];
assign cur_plv   = CRMD[1:0];
assign crmd_dataF = CRMD[7];

// 0 和 1
always@(posedge clk) begin
    if(reset)begin
        CRMD <= 32'h00000008;//初始化要求！
        PRMD <= 32'h00000000;
    end
    else if(is_exc & ~is_last_exc) begin
        //PPLV = PLV
        PRMD[1:0] <= CRMD[1:0];
        // PIE = IE
        PRMD[2] <= CRMD[2];
        //PLV 置 0
        CRMD[1:0] <= 2'b0;
        // IE置0
        CRMD[2] <= 1'b0;
        if(TLBR)begin
            CRMD[3] <= 1'b1;
            CRMD[4] <= 1'b0;
            // CRMD[6:5] <= 2'b00;
        end
    end
    else if(is_ret) begin
        CRMD[1:0] <= PRMD[1:0];
        CRMD[2] <= PRMD[2];
        if(ESTAT[21:16] == 6'h3f)begin
            CRMD[3] <= 1'b0;
            CRMD[4] <= 1'b1;
            // CRMD[6:5] <= 2'b01;
            // CRMD[8:7] <= 2'b01;
        end
    end
    else if(we[0])begin
        if(waddr == 14'h0)
            CRMD <= wdata;
        else if(waddr == 14'h1)
            PRMD <= wdata;
    end

    else if(we[1])begin
        if(waddr == 14'h0)
            CRMD <= CRMD & ~rj_value | wdata & rj_value;
        else if(waddr == 14'h1)
            PRMD <= PRMD & ~rj_value | wdata & rj_value;  
    end

end
// 4
always@(posedge clk)
    if(reset)
        ECFG <= 32'h00000000;
    else if(we[0] && waddr == 14'h4)
        ECFG <= wdata;
    else if(we[1] && waddr == 14'h4)
        ECFG <= ECFG & ~rj_value | wdata & rj_value;



assign LIE = {ECFG[12:11], 1'b0, ECFG[9:0]};
// 5
always@(posedge clk)
    if(reset)
        ESTAT <= 32'h00000000;
    else if(is_exc) begin
        ESTAT[21:16] <= Ecode;
        ESTAT[30:22] <= EsubCode;
    end
    else if(we[0] && waddr == 14'h5)
        ESTAT <= wdata;
    else if(we[1] && waddr == 14'h5)
        ESTAT <= ESTAT & ~rj_value | wdata & rj_value;
//!还需要改
assign ESTAT_IS_1_0 = ESTAT[1:0];
//记录是否发生硬件中断
// assign ESTAT_IS_9_2 = ESTAT[9:2];
assign ESTAT_IS_9_2 = 8'h0;
assign ESTAT_IS_11 = IS11;
assign ESTAT_IS_12 = 1'b0;

always@(TICLR_CLR, we, waddr, is_ret)
    if(TICLR_CLR)
        is_clr = 1'b1;
    else if((is_ret || ((we[0] || we[1]) && waddr == 14'h41)))
        is_clr = 1'b0;

always@(TICLR_CLR, is_TVAL_zero, last_is_TVAL_zero, is_clr)
    if(TICLR_CLR)
        IS11 = 1'b0;
    else if(is_TVAL_zero)begin
        if(last_is_TVAL_zero && is_clr)
            IS11 = 1'b0;
        else
            IS11 = 1'b1;
    end



assign IS = {ESTAT_IS_12, ESTAT_IS_11, 1'b0, ESTAT_IS_9_2, ESTAT_IS_1_0};

assign int_vec = IS & LIE;

assign need_interrupt = CRMD[2] & (int_vec != 13'b0);

// 6
always@(posedge clk)
    if(reset)
        ERA <= 32'h00000000;
    else if(is_exc)
        ERA <= pc_to_era;
    else if(we[0] && waddr == 14'h6)
        ERA <= wdata;
    else if(we[1] && waddr == 14'h6)
        ERA <= ERA & ~rj_value | wdata & rj_value;

// 7
always@(posedge clk)
    if(reset)
        BADV <= 32'h00000000;
    else if(Addr_exc || is_TLB_exc)
        BADV <= pc_to_badv;
    else if(we[0] && waddr == 14'h7)
        BADV <= wdata;
    else if(we[1] && waddr == 14'h7)
        BADV <= BADV & ~rj_value | wdata & rj_value;

// c
always@(posedge clk)
    if(reset)
        EENTRY <= 32'h00000000;
    else if(we[0] && waddr == 14'hc)
        EENTRY <= wdata;
    else if(we[1] && waddr == 14'hc)
        EENTRY <= EENTRY & ~rj_value | wdata & rj_value;


//10
always@(posedge clk)
    if(reset)
        TLBIDX <= 32'h00000000;
    else if(tlbsrh_to_csr_bus[5])begin
        TLBIDX[31] <= ne_in;
        if(~ne_in)
            TLBIDX[3:0] <= index_in;
    end
    else if(tlbcsr_rd_wen)begin
        TLBIDX[29:24] <= w_ps;
        TLBIDX[31] <= ~w_e;
    end
    else if(we[0] && waddr == 14'h10)
        TLBIDX <= wdata;
    else if(we[1] && waddr == 14'h10)
        TLBIDX <= TLBIDX & ~rj_value | wdata & rj_value;

//11
always@(posedge clk)
    if(reset)
        TLBEHI <= 32'h00000000;
    else if(tlbcsr_rd_wen)begin
        TLBEHI[31:13] <= w_vppn; 
    end
    else if(is_TLB_exc)
        TLBEHI[31:13] <= pc_to_badv[31:13];
    else if(we[0] && waddr == 14'h11)
        TLBEHI <= wdata;
    else if(we[1] && waddr == 14'h11)
        TLBEHI <= TLBEHI & ~rj_value | wdata & rj_value;

//12
always@(posedge clk)
    if(reset)
        TLBELO0 <= 32'h00000000;
    else if(tlbcsr_rd_wen)begin
        TLBELO0[6:0] <= {w_g, w_mat0, w_plv0, w_d0, w_v0};
        TLBELO0[27:8] <= w_ppn0;
    end
    else if(we[0] && waddr == 14'h12)
        TLBELO0 <= wdata;
    else if(we[1] && waddr == 14'h12)
        TLBELO0 <= TLBELO0 & ~rj_value | wdata & rj_value;

//13
always@(posedge clk)
    if(reset)
        TLBELO1 <= 32'h00000000;
    else if(tlbcsr_rd_wen)begin
        TLBELO1[6:0] <= {w_g, w_mat1, w_plv1, w_d1, w_v1};
        TLBELO1[27:8] <= w_ppn1;
    end
    else if(we[0] && waddr == 14'h13)
        TLBELO1 <= wdata;
    else if(we[1] && waddr == 14'h13)
        TLBELO1 <= TLBELO1 & ~rj_value | wdata & rj_value;

//18
always@(posedge clk)
    if(reset)
        ASID <= 32'h000a0000;
    else if(tlbcsr_rd_wen)begin
        ASID[9:0] <= w_asid;
    end
    else if(we[0] && waddr == 14'h18)
        ASID <= wdata;
    else if(we[1] && waddr == 14'h18)
        ASID <= ASID & ~rj_value | wdata & rj_value;

// 30 
always@(posedge clk)
    if(reset)
        SAVE0 <= 32'h00000000;
    else if(we[0] && waddr == 14'h30)
        SAVE0 <= wdata;
    else if(we[1] && waddr == 14'h30)
        SAVE0 <= SAVE0 & ~rj_value | wdata & rj_value;
// 31 
always@(posedge clk)
    if(reset)
        SAVE1 <= 32'h00000000;
    else if(we[0] && waddr == 14'h31)
        SAVE1 <= wdata;
    else if(we[1] && waddr == 14'h31)
        SAVE1 <= SAVE1 & ~rj_value | wdata & rj_value;
// 32
always@(posedge clk)
    if(reset)
        SAVE2 <= 32'h00000000;
    else if(we[0] && waddr == 14'h32)
        SAVE2 <= wdata;
    else if(we[1] && waddr == 14'h32)
        SAVE2 <= SAVE2 & ~rj_value | wdata & rj_value;
// 33
always@(posedge clk)
    if(reset)
        SAVE3 <= 32'h00000000;
    else if(we[0] && waddr == 14'h33)
        SAVE3 <= wdata;
    else if(we[1] && waddr == 14'h33)
        SAVE3 <= SAVE3 & ~rj_value | wdata & rj_value;

// 40
always@(posedge clk)
    if(reset)
        TID <= 32'h00000000;
    else if(we[0] && waddr == 14'h40)
        TID <= wdata;
    else if(we[1] && waddr == 14'h40)
        TID <= TID & ~rj_value | wdata & rj_value;

// 41、42
always@(posedge clk)
    if(reset)begin
        TCFG = 32'h00000000;
        TVAL = 32'h00000000;
    end
    else if(we[0] && waddr == 14'h41)begin
        TCFG = wdata;
        TCFG_En = TCFG[0];
        TCFG_Periodic = TCFG[1];
        TCFG_InitVal = TCFG[`N - 1 : 2];
        TVAL[`N - 1 : 0] = {TCFG_InitVal, 2'b0};
    end
    else if(we[1] && waddr == 14'h41)begin
        TCFG = TCFG & ~rj_value | wdata & rj_value;
        TCFG_En = TCFG[0];
        TCFG_Periodic = TCFG[1];
        TCFG_InitVal = TCFG[`N - 1 : 2];
        TVAL[`N - 1 : 0] = {TCFG_InitVal, 2'b0};
    end

    else if(TCFG_En) begin
        if(TCFG_Periodic)begin
            if(TVAL[`N - 1 : 0] == 0)
                TVAL[`N - 1 : 0] = {TCFG_InitVal, 2'b0};
            else
                TVAL[`N - 1 : 0] = TVAL[`N - 1 : 0] - 1;
        end
        else begin
            if(TVAL[`N - 1 : 0] != 0)
                TVAL[`N - 1 : 0] <= TVAL[`N - 1 : 0] - 1;
            else
                TCFG_En = 0;
         end
    end

 
// assign  TCFG_En = TCFG[0];
// assign TCFG_Periodic = TCFG[1];
// assign TCFG_InitVal = TCFG[`N - 1 : 2];


// // 42 
// always@(posedge clk)
//     if(reset)
//         TVAL <= 32'h00000000;
//     else if(TCFG_En) begin
//         if(TCFG_Periodic)begin
//             if(TVAL[`N - 1 : 0] == 0)
//                 TVAL[`N - 1 : 0] <= {TCFG_InitVal, 2'b0};
//             else
//                 TVAL[`N - 1 : 0] <= TVAL[`N - 1 : 0] - 1;
//         end
//         else begin
//             if(TVAL[`N - 1 : 0] != 0)
//                 TVAL[`N - 1 : 0] <= TVAL[`N - 1 : 0] - 1;
//             else
//                 TVAL[`N - 1 : 0] <= {TCFG_InitVal, 2'b0};
//         end
            
//     end

always@(posedge clk)
    if(reset)
        last_is_TVAL_zero <= 1'b0;
    else if(TCFG_En)
        last_is_TVAL_zero <= is_TVAL_zero;
    

assign TVAL_TimeVal = TVAL[`N - 1 : 0];
//开始计时后的0才有效
assign is_TVAL_zero = TCFG_En & (TVAL_TimeVal == `N'b0);

// 44
always@(posedge clk)
    if(reset)
        TICLR <= 32'h00000000;
    else if(we[0] && waddr == 14'h44)
        TICLR <= wdata;
    else if(we[1] && waddr == 14'h44)
        TICLR <= TICLR & ~rj_value | wdata & rj_value;


//清除定时器中断
assign TICLR_CLR = ((we[0] || we[1]) && waddr == 14'h44) ? 1'b1 : 1'b0;

//88
always@(posedge clk)
    if(reset)
        TLBRENTRY <= 32'h00000000;
    else if(we[0] && waddr == 14'h88)
        TLBRENTRY <= wdata;
    else if(we[1] && waddr == 14'h88)
        TLBRENTRY <= TLBRENTRY & ~rj_value | wdata & rj_value;

//180
always@(posedge clk)
    if(reset)
        DMW0 <= 32'h00000000;
    else if(we[0] && waddr == 14'h180)
        DMW0 <= wdata;
    else if(we[1] && waddr == 14'h180)
        DMW0 <= TLBRENTRY & ~rj_value | wdata & rj_value;

//181
always@(posedge clk)
    if(reset)
        DMW1 <= 32'h00000000;
    else if(we[0] && waddr == 14'h181)
        DMW1 <= wdata;
    else if(we[1] && waddr == 14'h181)
        DMW1 <= TLBRENTRY & ~rj_value | wdata & rj_value;

assign rdata = raddr == 14'h0 ? {23'b0, CRMD[8:0]} :
               raddr == 14'h1 ? {29'b0, PRMD[2:0]} :
               raddr == 14'h4 ? {19'b0, ECFG[12:11], 1'b0, ECFG[9:0]} :
               raddr == 14'h5 ? {1'b0, ESTAT[30:16], 3'b0, IS} :
               raddr == 14'h6 ? ERA :
               raddr == 14'h7 ? BADV :
               raddr == 14'h10 ? {TLBIDX[31], 1'b0, TLBIDX[29:24], 20'b0, TLBIDX[3:0]}:
               raddr == 14'h11 ? {TLBEHI[31:13], 13'b0} :
               raddr == 14'h12 ? {4'b0, TLBELO0[27:0]} :
               raddr == 14'h13 ? {4'b0, TLBELO1[27:0]} :
               raddr == 14'h18 ? {8'b0, 8'h0a, 6'b0, ASID[9:0]} :
               raddr == 14'h30 ? SAVE0 :
               raddr == 14'h31 ? SAVE1 :
               raddr == 14'h32 ? SAVE2 :
               raddr == 14'h33 ? SAVE3 : 
               raddr == 14'h40 ? TID :
               raddr == 14'h41 ? {`SUB_N'b0, TCFG_InitVal, TCFG_Periodic, TCFG_En} : 
               raddr == 14'h42 ? {`SUB_N'b0, TVAL_TimeVal} : 
               raddr == 14'h44 ? 32'h0 : 
               raddr == 14'h88 ? {TLBRENTRY[31:6], 6'b0} : 
               raddr == 14'h180 ? {DMW0[31:29], 1'b0, DMW0[27:25], 19'b0, DMW0[5:3], 2'b0, DMW0[0]} :
               raddr == 14'h181 ? {DMW1[31:29], 1'b0, DMW1[27:25], 19'b0, DMW1[5:3], 2'b0, DMW1[0]} :
               32'h0;


endmodule