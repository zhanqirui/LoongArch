`define N 12
`define SUB_N 20
module csr(
    //!需要新增接口: pc, is_exc, is_return?
    // pc:异常发生时，pc写入ERA中
    //is_exc:记录异常是否发生，一旦异常发生，将保存CRMD位域的旧值，调整PLV等级，将IE域置0
    //! 新增接口era, eentry

    //! 新增接口Ecode EsubCode
    input clk,reset,

    input [13:0] raddr,
    input [31:0] rj_value,
    output[31:0] rdata,
    output reg[31:0] ERA,
    output reg[31:0] EENTRY,
    output need_interrupt,

    input [1:0]  we,
    input [13:0] waddr,
    input [31:0] wdata,
    input [31:0] pc_to_era,
    input [31:0] pc_to_badv,
    input is_exc, is_ret, Addr_exc,
    input [5:0] Ecode,
    input [8:0] EsubCode
    
);

reg [31:0] CRMD, PRMD, ESTAT, SAVE1, SAVE2, SAVE3, SAVE0;
reg [31:0] ECFG, BADV, TID, TCFG, TVAL, TICLR;

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

// 0 和 1
always@(posedge clk) begin
    if(reset)begin
        CRMD <= 32'h00000008;//初始化要求！
        PRMD <= 32'h00000000;
    end
    else if(is_exc) begin
        //PPLV = PLV
        PRMD[1:0] <= CRMD[1:0];
        // PIE = IE
        PRMD[2] <= CRMD[2];
        //PLV 置 0
        CRMD[1:0] <= 2'b0;
        // IE置0
        CRMD[2] <= 1'b0;
    end
    else if(is_ret) begin
        CRMD[1:0] <= PRMD[1:0];
        CRMD[2] <= PRMD[2];
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
    else if(Addr_exc)
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

assign rdata = raddr == 14'h0 ? {23'b0, CRMD[8:0]} :
               raddr == 14'h1 ? {29'b0, PRMD[2:0]} :
               raddr == 14'h4 ? {19'b0, ECFG[12:11], 1'b0, ECFG[9:0]} :
               raddr == 14'h5 ? {1'b0, ESTAT[30:16], 3'b0, IS} :
               raddr == 14'h6 ? ERA :
               raddr == 14'h7 ? BADV :
               raddr == 14'h30 ? SAVE0 :
               raddr == 14'h31 ? SAVE1 :
               raddr == 14'h32 ? SAVE2 :
               raddr == 14'h33 ? SAVE3 : 
               raddr == 14'h40 ? TID :
               raddr == 14'h41 ? {`SUB_N'b0, TCFG_InitVal, TCFG_Periodic, TCFG_En} : 
               raddr == 14'h42 ? {`SUB_N'b0, TVAL_TimeVal} : 
               raddr == 14'h44 ? 32'h0 : 32'h0;


endmodule